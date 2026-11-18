#!/usr/bin/env python3
"""Fills Dawnwell's App Store Connect record from the files in ios/AppStore.

Run by .github/workflows/appstore.yml with an App Store Connect API key (Admin role) in
ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY. Every step looks at what is already there
first, so running it again only fills what is missing or changed.

  python3 appstore.py --check                      validate the files, no network
  python3 appstore.py --parts read                 sign in and print what exists (changes nothing)
  python3 appstore.py --parts texts,products,screenshots --shots DIR

Parts:
  texts        name, subtitle, description, keywords, promo text, URLs, categories, age rating,
               review notes, price (free) and availability
  products     the subscription group, both subscriptions with prices and the free week,
               and the Lifetime purchase with its price
  screenshots  6.9" iPhone screenshots per language from DIR/<app language>/*.png, and the paywall
               screenshot for each purchase's review from DIR/en/paywall.png
"""
import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "AppStore"
BUNDLE_ID = "com.dawnwell.app"
API = "https://api.appstoreconnect.apple.com"
SUPPORT_URL = "https://baturinigor.github.io/Dawnwell/"
PRIVACY_URL = "https://baturinigor.github.io/Dawnwell/privacy"
# Mainland China needs a government licence for health apps, so Dawnwell is not offered there.
EXCLUDED_TERRITORIES = {"CHN"}
SCREENSHOT_TYPE = "APP_IPHONE_67"  # Apple's 6.7"/6.9" iPhone slot (1290x2796 and 1320x2868)

# App Store locale -> the app language its screenshots are taken in.
SHOT_LANG = {
    "en-US": "en", "en-GB": "en", "en-AU": "en", "en-CA": "en",
    "de-DE": "de", "fr-FR": "fr", "fr-CA": "fr", "es-ES": "es", "es-MX": "es", "it": "it",
    "pt-BR": "pt-BR", "pt-PT": "pt-PT", "nl-NL": "nl", "sv": "sv", "da": "da", "no": "nb",
    "fi": "fi", "pl": "pl", "tr": "tr", "ja": "ja", "ko": "ko", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant",
}
LIMITS = {"name": 30, "subtitle": 30, "promotionalText": 170, "keywords": 100, "description": 4000}


# ---------- files ----------

def load_listing():
    out = {}
    for f in sorted((ROOT / "listing").glob("*.json")):
        out[f.stem] = json.loads(f.read_text())
    return out


def load_products():
    return json.loads((ROOT / "products.json").read_text())


def check():
    """Offline checks of the listing and product files. Returns a list of problems."""
    problems = []
    listing = load_listing()
    if "en-US" not in listing:
        problems.append("listing/en-US.json is missing")
    for loc, d in listing.items():
        if loc not in SHOT_LANG:
            problems.append(f"{loc}: no screenshot language mapped")
        for key, limit in LIMITS.items():
            value = d.get(key, "")
            if not value:
                problems.append(f"{loc}: {key} is empty")
            elif len(value) > limit:
                problems.append(f"{loc}: {key} is {len(value)} characters, the limit is {limit}")
        if "Dawnwell" not in d.get("name", ""):
            problems.append(f"{loc}: the name must contain Dawnwell")
        if ", " in d.get("keywords", ""):
            problems.append(f"{loc}: keywords are separated by commas without spaces")
        desc = d.get("description", "")
        if PRIVACY_URL not in desc or "stdeula" not in desc:
            problems.append(f"{loc}: the description needs the Terms of Use and Privacy Policy links")
        if "$" in desc:
            problems.append(f"{loc}: no prices in the description, they differ by country")
    p = load_products()
    items = p["subscriptions"] + [p["lifetime"]]
    for item in items:
        locs = item["localizations"]
        if set(locs) != set(listing):
            problems.append(f"{item['productId']}: localizations differ from the listing languages")
        for loc, t in locs.items():
            if not 0 < len(t["name"]) <= 30:
                problems.append(f"{item['productId']} {loc}: display name over 30 characters")
            if not 0 < len(t["description"]) <= 45:
                problems.append(f"{item['productId']} {loc}: description over 45 characters")
    return problems


# ---------- API ----------

class ASC:
    def __init__(self, key_id, issuer, private_key, dry_run=False):
        import jwt  # PyJWT, installed by the workflow
        import requests
        self._jwt, self._requests = jwt, requests
        self.key_id, self.issuer, self.private_key = key_id, issuer, private_key
        self.dry_run = dry_run
        self._token, self._token_at = None, 0
        self.session = requests.Session()

    def token(self):
        if not self._token or time.time() - self._token_at > 15 * 60:
            now = int(time.time())
            self._token = self._jwt.encode(
                {"iss": self.issuer, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"},
                self.private_key, algorithm="ES256", headers={"kid": self.key_id, "typ": "JWT"})
            self._token_at = now
        return self._token

    def call(self, method, path, body=None, params=None, ok=(200, 201, 204)):
        url = path if path.startswith("http") else API + path
        if self.dry_run and method != "GET":
            print(f"    (dry run) {method} {path}")
            return {"data": {"id": "dry-run", "attributes": {}}}
        for attempt in range(5):
            r = self.session.request(method, url, json=body, params=params,
                                     headers={"Authorization": f"Bearer {self.token()}"}, timeout=60)
            if r.status_code == 429 or r.status_code >= 500:
                time.sleep(2 ** attempt * 3)
                continue
            break
        if r.status_code not in ok:
            raise ApiError(method, path, r.status_code, r.text)
        return r.json() if r.content else {}

    def get(self, path, **params):
        return self.call("GET", path, params=params or None)

    def all(self, path, **params):
        params.setdefault("limit", 200)
        out, url = [], path
        while url:
            page = self.call("GET", url, params=params)
            out += page.get("data", [])
            url, params = page.get("links", {}).get("next"), None
        return out

    def create(self, type_, attributes=None, relationships=None, included=None, path=None):
        data = {"type": type_}
        if attributes:
            data["attributes"] = attributes
        if relationships:
            data["relationships"] = {k: {"data": v} for k, v in relationships.items()}
        body = {"data": data}
        if included:
            body["included"] = included
        return self.call("POST", path or f"/v1/{type_}", body)["data"]

    def update(self, type_, id_, attributes=None, relationships=None, path=None):
        data = {"type": type_, "id": id_}
        if attributes:
            data["attributes"] = attributes
        if relationships:
            data["relationships"] = {k: {"data": v} for k, v in relationships.items()}
        return self.call("PATCH", path or f"/v1/{type_}/{id_}", {"data": data})


class ApiError(Exception):
    def __init__(self, method, path, status, text):
        try:
            errs = json.loads(text).get("errors", [])
            text = "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in errs) or text
        except ValueError:
            pass
        super().__init__(f"{method} {path} -> {status}: {text[:1500]}")
        self.status = status


def ref(type_, id_):
    return {"type": type_, "id": id_}


class Run:
    """Collects failures so one bad step does not stop the rest."""

    def __init__(self):
        self.failures = []

    def step(self, title, fn, *args):
        print(f"• {title}")
        try:
            return fn(*args)
        except ApiError as e:
            print(f"  ✗ {e}")
            self.failures.append(f"{title}: {e}")
        except Exception as e:  # noqa: BLE001 - report and carry on
            print(f"  ✗ {type(e).__name__}: {e}")
            self.failures.append(f"{title}: {type(e).__name__}: {e}")


# ---------- texts ----------

def find_app(asc):
    apps = asc.get("/v1/apps", **{"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        sys.exit(f"No app with bundle ID {BUNDLE_ID} in App Store Connect. Create it first (My Apps -> + -> New App).")
    app = apps[0]
    print(f"App: {app['attributes']['name']} ({app['id']}), primary locale {app['attributes'].get('primaryLocale')}")
    return app


def editable_app_info(asc, app_id):
    infos = asc.all(f"/v1/apps/{app_id}/appInfos")
    for info in infos:
        state = info["attributes"].get("appStoreState") or info["attributes"].get("state")
        if state not in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_INFO"):
            return info
    return infos[0]


def editable_version(asc, app_id):
    versions = asc.all(f"/v1/apps/{app_id}/appStoreVersions", **{"filter[platform]": "IOS"})
    for v in versions:
        state = v["attributes"].get("appStoreState") or v["attributes"].get("appVersionState")
        if state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
                     "INVALID_BINARY", "READY_FOR_REVIEW"):
            return v
    raise RuntimeError("No iOS version in Prepare for Submission. Add one in App Store Connect.")


def sync_app_info_texts(asc, info_id, listing):
    existing = {l["attributes"]["locale"]: l for l in asc.all(f"/v1/appInfos/{info_id}/appInfoLocalizations")}
    for loc, d in listing.items():
        attrs = {"name": d["name"], "subtitle": d["subtitle"], "privacyPolicyUrl": PRIVACY_URL}
        if loc in existing:
            cur = existing[loc]["attributes"]
            if all(cur.get(k) == v for k, v in attrs.items()):
                continue
            asc.update("appInfoLocalizations", existing[loc]["id"], attrs)
            print(f"  {loc}: updated name and subtitle")
        else:
            asc.create("appInfoLocalizations", {"locale": loc, **attrs}, {"appInfo": ref("appInfos", info_id)})
            print(f"  {loc}: added")


def sync_version_texts(asc, version_id, listing):
    existing = {l["attributes"]["locale"]: l for l in asc.all(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")}
    for loc, d in listing.items():
        attrs = {"description": d["description"], "keywords": d["keywords"],
                 "promotionalText": d["promotionalText"], "supportUrl": SUPPORT_URL}
        if loc in existing:
            cur = existing[loc]["attributes"]
            if all(cur.get(k) == v for k, v in attrs.items()):
                continue
            asc.update("appStoreVersionLocalizations", existing[loc]["id"], attrs)
            print(f"  {loc}: updated description, keywords, promo text")
        else:
            asc.create("appStoreVersionLocalizations", {"locale": loc, **attrs},
                       {"appStoreVersion": ref("appStoreVersions", version_id)})
            print(f"  {loc}: added")


def sync_categories(asc, info_id):
    asc.update("appInfos", info_id, relationships={
        "primaryCategory": ref("appCategories", "HEALTH_AND_FITNESS"),
        "secondaryCategory": ref("appCategories", "MEDICAL"),
    })
    print("  Health & Fitness, then Medical")


# Yes/no questions in Apple's age rating; every other question is a level where NONE means "none".
AGE_RATING_YES_NO = {"advertising", "ageAssurance", "gambling", "healthOrWellnessTopics", "lootBox",
                     "messagingAndChat", "parentalControls", "unrestrictedWebAccess", "userGeneratedContent",
                     "seventeenPlus"}


def sync_age_rating(asc, info_id):
    """Medical/treatment information: infrequent/mild, health topics: yes, everything else: none/no.
    Apple wants every question answered in one request and adds questions over time, so the answers
    are built from what the declaration lists, plus any question an error names as missing."""
    import re
    decl = asc.get(f"/v1/appInfos/{info_id}/ageRatingDeclaration")["data"]
    skip = ("override", "Override", "kidsAgeBand", "url", "Url")

    def answer(key):
        if key == "medicalOrTreatmentInformation":
            return "INFREQUENT_OR_MILD"
        if key == "healthOrWellnessTopics":
            return True
        return False if key in AGE_RATING_YES_NO else "NONE"

    answers = {k: answer(k) for k in decl.get("attributes", {}) if not any(s in k for s in skip)}
    for _ in range(4):
        try:
            asc.update("ageRatingDeclarations", decl["id"], answers)
            print(f"  {len(answers)} questions answered")
            return
        except ApiError as e:
            missing = set(re.findall(r"attribute '(\w+)'", str(e))) - set(answers)
            if not missing:
                raise
            answers.update({k: answer(k) for k in missing})
    raise RuntimeError("age rating still incomplete")


def sync_review_details(asc, version_id, notes):
    try:
        detail = asc.get(f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail").get("data")
    except ApiError as e:
        if e.status != 404:
            raise
        detail = None
    attrs = {"notes": notes, "demoAccountRequired": False}
    if detail:
        asc.update("appStoreReviewDetails", detail["id"], attrs)
    else:
        asc.create("appStoreReviewDetails", attrs, {"appStoreVersion": ref("appStoreVersions", version_id)})
    print("  notes for App Review saved")


def sync_app_flags(asc, app_id):
    asc.update("apps", app_id, {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"})
    print("  no third-party content")


def all_territories(asc):
    return [t["id"] for t in asc.all("/v1/territories")]


def territories(asc):
    return [t for t in all_territories(asc) if t not in EXCLUDED_TERRITORIES]


def sync_app_price(asc, app_id):
    try:
        asc.get(f"/v1/apps/{app_id}/appPriceSchedule")
        manual = asc.all(f"/v1/appPriceSchedules/{app_id}/manualPrices")
        if manual:
            print("  price already set")
            return
    except ApiError as e:
        if e.status != 404:
            raise
    points = asc.all(f"/v1/apps/{app_id}/appPricePoints", **{"filter[territory]": "USA"})
    free = next(p for p in points if float(p["attributes"]["customerPrice"]) == 0)
    asc.call("POST", "/v1/appPriceSchedules", {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": ref("apps", app_id)},
            "baseTerritory": {"data": ref("territories", "USA")},
            "manualPrices": {"data": [ref("appPrices", "${free}")]},
        }},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": ref("appPricePoints", free["id"])}}}],
    })
    print("  free")


def sync_app_availability(asc, app_id):
    try:
        existing = asc.get(f"/v1/apps/{app_id}/appAvailabilityV2").get("data")
    except ApiError as e:
        if e.status != 404:
            raise
        existing = None
    if existing:
        print("  availability already set")
        return
    ids = all_territories(asc)
    asc.call("POST", "/v2/appAvailabilities", {
        "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True},
                 "relationships": {
                     "app": {"data": ref("apps", app_id)},
                     "territoryAvailabilities": {"data": [ref("territoryAvailabilities", f"${{{t}}}") for t in ids]},
                 }},
        "included": [{"type": "territoryAvailabilities", "id": f"${{{t}}}",
                      "attributes": {"available": t not in EXCLUDED_TERRITORIES, "releaseDate": None,
                                     "preOrderEnabled": False},
                      "relationships": {"territory": {"data": ref("territories", t)}}} for t in ids],
    })
    print(f"  {len(ids) - len(EXCLUDED_TERRITORIES)} countries and regions")


# ---------- products ----------

def sync_group(asc, app_id, group):
    groups = asc.all(f"/v1/apps/{app_id}/subscriptionGroups")
    g = next((x for x in groups if x["attributes"]["referenceName"] == group["referenceName"]), None)
    if not g:
        g = asc.create("subscriptionGroups", {"referenceName": group["referenceName"]}, {"app": ref("apps", app_id)})
        print(f"  created group {group['referenceName']}")
    return g


def sync_group_localizations(asc, group_id, display_name, locales):
    existing = {l["attributes"]["locale"] for l in asc.all(f"/v1/subscriptionGroups/{group_id}/subscriptionGroupLocalizations")}
    for loc in locales:
        if loc not in existing:
            asc.create("subscriptionGroupLocalizations", {"name": display_name, "locale": loc},
                       {"subscriptionGroup": ref("subscriptionGroups", group_id)})
    print(f"  group name in {len(locales)} languages")


def sync_subscription(asc, group_id, sub, note):
    subs = asc.all(f"/v1/subscriptionGroups/{group_id}/subscriptions")
    s = next((x for x in subs if x["attributes"]["productId"] == sub["productId"]), None)
    if not s:
        s = asc.create("subscriptions", {
            "name": sub["referenceName"], "productId": sub["productId"],
            "subscriptionPeriod": sub["period"], "groupLevel": sub["groupLevel"],
            "familySharable": False, "reviewNote": note,
        }, {"group": ref("subscriptionGroups", group_id)})
        print(f"  created {sub['productId']}")
    return s


def sync_localizations(asc, list_path, type_, parent_key, parent, locs):
    existing = {l["attributes"]["locale"]: l for l in asc.all(list_path)}
    for loc, t in locs.items():
        attrs = {"name": t["name"], "description": t["description"]}
        if loc in existing:
            cur = existing[loc]["attributes"]
            if cur.get("name") != t["name"] or cur.get("description") != t["description"]:
                asc.update(type_, existing[loc]["id"], attrs)
        else:
            asc.create(type_, {"locale": loc, **attrs}, {parent_key: parent})
    print(f"  names in {len(locs)} languages")


def sync_subscription_availability(asc, sub_id, ids):
    try:
        if asc.get(f"/v1/subscriptions/{sub_id}/subscriptionAvailability").get("data"):
            return
    except ApiError as e:
        if e.status != 404:
            raise
    asc.create("subscriptionAvailabilities", {"availableInNewTerritories": True}, {
        "subscription": ref("subscriptions", sub_id),
        "availableTerritories": [ref("territories", t) for t in ids],
    })
    print(f"  available in {len(ids)} countries and regions")


def sync_subscription_prices(asc, sub_id, usd, ids):
    have = {p["relationships"]["territory"]["data"]["id"]
            for p in asc.all(f"/v1/subscriptions/{sub_id}/prices", include="territory")
            if p.get("relationships", {}).get("territory", {}).get("data")}
    if "USA" in have and len(have) >= len(ids):
        print("  prices already set")
        return
    points = asc.all(f"/v1/subscriptions/{sub_id}/pricePoints", **{"filter[territory]": "USA"})
    base = next(p for p in points if p["attributes"]["customerPrice"] in (usd, usd.rstrip("0")))
    targets = {"USA": base["id"]}
    for eq in asc.all(f"/v1/subscriptionPricePoints/{base['id']}/equalizations", include="territory"):
        t = eq.get("relationships", {}).get("territory", {}).get("data", {}).get("id")
        if t and t in ids:
            targets[t] = eq["id"]
    added = 0
    for territory, point in targets.items():
        if territory in have:
            continue
        asc.create("subscriptionPrices", {"startDate": None, "preserveCurrentPrice": False}, {
            "subscription": ref("subscriptions", sub_id),
            "subscriptionPricePoint": ref("subscriptionPricePoints", point),
            "territory": ref("territories", territory),
        })
        added += 1
    print(f"  ${usd} in the U.S., Apple's matching price in {len(targets) - 1} more ({added} added)")


def sync_free_week(asc, sub_id, duration, ids):
    have = {o["relationships"]["territory"]["data"]["id"]
            for o in asc.all(f"/v1/subscriptions/{sub_id}/introductoryOffers", include="territory")
            if o.get("relationships", {}).get("territory", {}).get("data")}
    added = 0
    for t in ids:
        if t in have:
            continue
        asc.create("subscriptionIntroductoryOffers", {
            "duration": duration, "offerMode": "FREE_TRIAL", "numberOfPeriods": 1, "startDate": None, "endDate": None,
        }, {"subscription": ref("subscriptions", sub_id), "territory": ref("territories", t)})
        added += 1
    print(f"  free week in {len(ids)} countries and regions ({added} added)")


def sync_lifetime(asc, app_id, item, note):
    found = asc.all(f"/v1/apps/{app_id}/inAppPurchasesV2", **{"filter[productId]": item["productId"]})
    if found:
        return found[0]
    iap = asc.create("inAppPurchases", {
        "name": item["referenceName"], "productId": item["productId"],
        "inAppPurchaseType": "NON_CONSUMABLE", "familySharable": False, "reviewNote": note,
    }, {"app": ref("apps", app_id)}, path="/v2/inAppPurchases")
    print(f"  created {item['productId']}")
    return iap


def sync_lifetime_availability(asc, iap_id, ids):
    try:
        if asc.get(f"/v2/inAppPurchases/{iap_id}/inAppPurchaseAvailability").get("data"):
            return
    except ApiError as e:
        if e.status != 404:
            raise
    asc.create("inAppPurchaseAvailabilities", {"availableInNewTerritories": True}, {
        "inAppPurchase": ref("inAppPurchases", iap_id),
        "availableTerritories": [ref("territories", t) for t in ids],
    })
    print(f"  available in {len(ids)} countries and regions")


def sync_lifetime_price(asc, iap_id, usd):
    try:
        manual = asc.all(f"/v1/inAppPurchasePriceSchedules/{iap_id}/manualPrices")
        if manual:
            print("  price already set")
            return
    except ApiError as e:
        if e.status != 404:
            raise
    points = asc.all(f"/v2/inAppPurchases/{iap_id}/pricePoints", **{"filter[territory]": "USA"})
    base = next(p for p in points if p["attributes"]["customerPrice"] in (usd, usd.rstrip("0")))
    asc.call("POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
            "inAppPurchase": {"data": ref("inAppPurchases", iap_id)},
            "baseTerritory": {"data": ref("territories", "USA")},
            "manualPrices": {"data": [ref("inAppPurchasePrices", "${base}")]},
        }},
        "included": [{"type": "inAppPurchasePrices", "id": "${base}", "attributes": {"startDate": None},
                      "relationships": {"inAppPurchasePricePoint": {"data": ref("inAppPurchasePricePoints", base["id"])}}}],
    })
    print(f"  ${usd} in the U.S., Apple converts the rest")


# ---------- screenshots ----------

def upload_asset(asc, type_, parent_key, parent, path):
    data = path.read_bytes()
    asset = asc.create(type_, {"fileName": path.name, "fileSize": len(data)}, {parent_key: parent})
    for op in asset["attributes"].get("uploadOperations") or []:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        r = asc.session.request(op["method"], op["url"], data=chunk, headers=headers, timeout=120)
        r.raise_for_status()
    asc.update(type_, asset["id"], {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()})
    return asset


def sync_screenshots(asc, version_id, shots_dir):
    locs = {l["attributes"]["locale"]: l["id"] for l in asc.all(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")}
    for loc, loc_id in sorted(locs.items()):
        lang = SHOT_LANG.get(loc)
        files = sorted(p for p in (shots_dir / lang).glob("[0-9]-*.png")) if lang else []
        if not files:
            print(f"  {loc}: no screenshots for {lang}, App Store shows the English ones")
            continue
        sets = asc.all(f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
        s = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == SCREENSHOT_TYPE), None)
        if s:
            for old in asc.all(f"/v1/appScreenshotSets/{s['id']}/appScreenshots"):
                asc.call("DELETE", f"/v1/appScreenshots/{old['id']}")
        else:
            s = asc.create("appScreenshotSets", {"screenshotDisplayType": SCREENSHOT_TYPE},
                           {"appStoreVersionLocalization": ref("appStoreVersionLocalizations", loc_id)})
        for f in files:
            upload_asset(asc, "appScreenshots", "appScreenshotSet", ref("appScreenshotSets", s["id"]), f)
        print(f"  {loc}: {len(files)} screenshots")


def sync_review_screenshot(asc, kind, parent_id, shot):
    if kind == "subscription":
        list_path = f"/v1/subscriptions/{parent_id}/appStoreReviewScreenshot"
        type_, key, parent = "subscriptionAppStoreReviewScreenshots", "subscription", ref("subscriptions", parent_id)
    else:
        list_path = f"/v2/inAppPurchases/{parent_id}/appStoreReviewScreenshot"
        type_, key, parent = "inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2", ref("inAppPurchases", parent_id)
    try:
        current = asc.get(list_path).get("data")
    except ApiError as e:
        if e.status != 404:
            raise
        current = None
    if current:
        asc.call("DELETE", f"/v1/{type_}/{current['id']}")
    upload_asset(asc, type_, key, parent, shot)
    print("  review screenshot uploaded")


# ---------- main ----------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--parts", default="read")
    ap.add_argument("--shots", type=Path)
    args = ap.parse_args()

    problems = check()
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    if args.check:
        print(f"{len(load_listing())} App Store languages OK")
        return

    parts = {p.strip() for p in args.parts.split(",") if p.strip()}
    if "everything" in parts:
        parts = {"texts", "products", "screenshots"}
    key_id, issuer, key = (os.environ.get(k, "") for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"))
    if not (key_id and issuer and key):
        sys.exit("Add the ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY repository secrets first.")
    asc = ASC(key_id, issuer, key, dry_run=parts == {"read"})
    listing, products = load_listing(), load_products()
    run = Run()

    app = find_app(asc)
    app_id = app["id"]
    info = editable_app_info(asc, app_id)
    version = run.step("Version in Prepare for Submission", editable_version, asc, app_id)
    if version:
        print(f"  version {version['attributes']['versionString']}")

    if parts == {"read"}:
        locs = asc.all(f"/v1/appInfos/{info['id']}/appInfoLocalizations")
        print(f"• App languages now: {', '.join(sorted(l['attributes']['locale'] for l in locs))}")
        groups = asc.all(f"/v1/apps/{app_id}/subscriptionGroups")
        print(f"• Subscription groups: {[g['attributes']['referenceName'] for g in groups]}")
        iaps = asc.all(f"/v1/apps/{app_id}/inAppPurchasesV2")
        print(f"• In-app purchases: {[i['attributes']['productId'] for i in iaps]}")
        print(f"• Countries and regions: {len(territories(asc))}")
        print("Sign-in works. Nothing was changed.")
        return

    ids = territories(asc)
    if "texts" in parts:
        run.step("Name, subtitle and privacy link", sync_app_info_texts, asc, info["id"], listing)
        if version:
            run.step("Description, keywords, promo text, support link", sync_version_texts, asc, version["id"], listing)
            run.step("Notes for App Review", sync_review_details, asc, version["id"],
                     (ROOT / "review-notes.txt").read_text().strip())
        run.step("Categories", sync_categories, asc, info["id"])
        run.step("Age rating", sync_age_rating, asc, info["id"])
        run.step("Content rights", sync_app_flags, asc, app_id)
        run.step("App price", sync_app_price, asc, app_id)
        run.step("Countries and regions", sync_app_availability, asc, app_id)

    sub_ids, iap_id = {}, None
    if "products" in parts or "screenshots" in parts:
        group = run.step("Subscription group", sync_group, asc, app_id, products["group"])
        if group:
            if "products" in parts:
                run.step("Group name", sync_group_localizations, asc, group["id"],
                         products["group"]["displayName"], list(listing))
            for sub in products["subscriptions"]:
                s = run.step(sub["referenceName"], sync_subscription, asc, group["id"], sub, products["reviewNote"])
                if not s:
                    continue
                sub_ids[sub["productId"]] = s["id"]
                if "products" in parts:
                    run.step(f"{sub['referenceName']}: names", sync_localizations, asc,
                             f"/v1/subscriptions/{s['id']}/subscriptionLocalizations", "subscriptionLocalizations",
                             "subscription", ref("subscriptions", s["id"]), sub["localizations"])
                    run.step(f"{sub['referenceName']}: availability", sync_subscription_availability, asc, s["id"], ids)
                    run.step(f"{sub['referenceName']}: prices", sync_subscription_prices, asc, s["id"], sub["usd"], ids)
                    run.step(f"{sub['referenceName']}: free week", sync_free_week, asc, s["id"], sub["freeTrial"], ids)
        life = products["lifetime"]
        iap = run.step(life["referenceName"], sync_lifetime, asc, app_id, life, products["reviewNote"])
        if iap:
            iap_id = iap["id"]
            if "products" in parts:
                run.step(f"{life['referenceName']}: names", sync_localizations, asc,
                         f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations", "inAppPurchaseLocalizations",
                         "inAppPurchaseV2", ref("inAppPurchases", iap_id), life["localizations"])
                run.step(f"{life['referenceName']}: availability", sync_lifetime_availability, asc, iap_id, ids)
                run.step(f"{life['referenceName']}: price", sync_lifetime_price, asc, iap_id, life["usd"])

    if "screenshots" in parts:
        if not args.shots or not args.shots.is_dir():
            run.failures.append("screenshots: no screenshot folder")
        else:
            if version:
                run.step("App screenshots", sync_screenshots, asc, version["id"], args.shots)
            paywall = args.shots / "en" / "paywall.png"
            if paywall.exists():
                for pid, sid in sub_ids.items():
                    run.step(f"{pid}: review screenshot", sync_review_screenshot, asc, "subscription", sid, paywall)
                if iap_id:
                    run.step(f"{products['lifetime']['productId']}: review screenshot",
                             sync_review_screenshot, asc, "iap", iap_id, paywall)
            else:
                run.failures.append("review screenshots: en/paywall.png was not taken")

    if run.failures:
        print("\nSome steps failed:")
        for f in run.failures:
            print(f"  - {f}")
        sys.exit(1)
    print("\nDone.")


if __name__ == "__main__":
    main()
