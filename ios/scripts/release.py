#!/usr/bin/env python3
"""Releases and submits Dawnwell versions through the App Store Connect API.

Run by .github/workflows/release.yml with the same API key secrets as the other workflows.

  python3 release.py status     versions, builds and purchases with their states (changes nothing)
  python3 release.py release    puts a version that is Pending Developer Release on the App Store
  python3 release.py prepare    makes the version from AppStore/whats-new.json, fills What's New in every
                                language and picks its newest processed build
  python3 release.py submit     prepare, then sends that version to App Review

App Privacy answers have no API: set them in App Store Connect before `submit`.
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from appstore import ASC, ApiError, SHOT_LANG, find_app, ref  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent / "AppStore"
EDITABLE = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY")


def state(v):
    a = v["attributes"]
    return a.get("appVersionState") or a.get("appStoreState")


def versions(asc, app_id):
    return asc.all(f"/v1/apps/{app_id}/appStoreVersions", **{"filter[platform]": "IOS"})


def status(asc, app_id):
    for v in versions(asc, app_id):
        a = v["attributes"]
        print(f"• Version {a['versionString']}: {state(v)} (release: {a.get('releaseType')})")
    builds = asc.get("/v1/builds", **{"filter[app]": app_id, "sort": "-uploadedDate", "limit": 5,
                                      "include": "preReleaseVersion"})
    pre = {i["id"]: i["attributes"]["version"] for i in builds.get("included", []) if i["type"] == "preReleaseVersions"}
    for b in builds["data"]:
        pv = pre.get(b["relationships"]["preReleaseVersion"]["data"]["id"], "?")
        print(f"• Build {pv} ({b['attributes']['version']}): {b['attributes']['processingState']}")
    for i in asc.all(f"/v1/apps/{app_id}/inAppPurchasesV2"):
        print(f"• {i['attributes']['productId']}: {i['attributes']['state']}")
    for g in asc.all(f"/v1/apps/{app_id}/subscriptionGroups"):
        for s in asc.all(f"/v1/subscriptionGroups/{g['id']}/subscriptions"):
            print(f"• {s['attributes']['productId']}: {s['attributes']['state']}")


def release(asc, app_id):
    pending = [v for v in versions(asc, app_id) if state(v) == "PENDING_DEVELOPER_RELEASE"]
    if not pending:
        print("No version is Pending Developer Release. Nothing to do.")
        return
    v = pending[0]
    asc.create("appStoreVersionReleaseRequests", relationships={"appStoreVersion": ref("appStoreVersions", v["id"])})
    print(f"✓ Version {v['attributes']['versionString']} is being released to the App Store.")


def prepare(asc, app_id):
    notes = json.loads((ROOT / "whats-new.json").read_text())
    wanted = notes["version"]
    v = next((x for x in versions(asc, app_id) if x["attributes"]["versionString"] == wanted), None)
    if v and state(v) not in EDITABLE:
        sys.exit(f"Version {wanted} is {state(v)}: it can't be changed now.")
    if not v:
        # A bug-fix release goes out by itself once approved.
        v = asc.create("appStoreVersions", {"platform": "IOS", "versionString": wanted, "releaseType": "AFTER_APPROVAL"},
                       {"app": ref("apps", app_id)})
        print(f"✓ Created version {wanted}")
    else:
        print(f"• Version {wanted} exists: {state(v)}")
    vid = v["id"]

    missing = []
    for loc in asc.all(f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations"):
        text = notes["text"].get(SHOT_LANG.get(loc["attributes"]["locale"], ""))
        if not text:
            missing.append(loc["attributes"]["locale"])
        elif loc["attributes"].get("whatsNew") != text:
            asc.update("appStoreVersionLocalizations", loc["id"], {"whatsNew": text})
    if missing:
        sys.exit(f"No What's New for: {', '.join(missing)}")
    print("✓ What's New in every language")

    builds = asc.get("/v1/builds", **{"filter[app]": app_id, "filter[preReleaseVersion.version]": wanted,
                                      "filter[processingState]": "VALID", "sort": "-uploadedDate", "limit": 1})["data"]
    if not builds:
        sys.exit(f"No processed build of {wanted} yet. Run the TestFlight workflow and wait for processing.")
    b = builds[0]
    asc.update("appStoreVersions", vid, relationships={"build": ref("builds", b["id"])})
    print(f"✓ Build {b['attributes']['version']} attached")
    return vid


def submit(asc, app_id):
    vid = prepare(asc, app_id)
    drafts = [s for s in asc.all("/v1/reviewSubmissions", **{"filter[app]": app_id, "filter[platform]": "IOS"})
              if s["attributes"]["state"] == "READY_FOR_REVIEW"]
    sub = drafts[0] if drafts else asc.create("reviewSubmissions", {"platform": "IOS"}, {"app": ref("apps", app_id)})
    try:
        asc.create("reviewSubmissionItems", relationships={"reviewSubmission": ref("reviewSubmissions", sub["id"]),
                                                           "appStoreVersion": ref("appStoreVersions", vid)})
    except ApiError as e:
        if e.status != 409:
            raise
        print(f"  (already in the submission: {e})")
    asc.update("reviewSubmissions", sub["id"], {"submitted": True})
    print("✓ Sent to App Review")


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    key_id, issuer, key = (os.environ.get(k, "") for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"))
    if not (key_id and issuer and key):
        sys.exit("Add the ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY repository secrets first.")
    asc = ASC(key_id, issuer, key)
    app_id = find_app(asc)["id"]
    {"status": status, "release": release, "prepare": prepare, "submit": submit}[action](asc, app_id)
    if action != "status":
        print("\nNow:")
        status(asc, app_id)


if __name__ == "__main__":
    main()
