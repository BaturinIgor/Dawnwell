# Dawnwell

A daily companion for people taking a GLP-1 medicine as a tablet (oral semaglutide, orforglipron).
It answers the questions that come up every morning: *did I take it, when can I eat, how much protein have I had*, and turns a month of logging into a summary you can bring to your clinician.

Dawnwell only reminds and records. It never suggests or changes a dose: everything about the medicine is copied from the user's prescription label.

iPhone only, iOS 17 and later, written in SwiftUI.

## What's in 1.0

| Screen | What it does |
| --- | --- |
| Onboarding | Medication, dose from the label, usual time, empty-stomach wait, weight goal, protein target, reminders |
| Today | Tablet card (pending, overdue, waiting with live countdown, done), protein ring with quick add, water, fiber, strength, food noise, symptoms, refill heads-up |
| Add food | Searchable list sorted by protein, meal picker, custom item |
| Symptom details | Severity 1–5, likely triggers, note for the visit; severe entries show a "contact your clinician" note |
| Medication | Update from label (keeps a dose history), usual time, wait, tablets left and refill, reminder switches |
| Your data | iCloud status, backup file export and restore, daily copies on the phone |
| Progress | Weight log and chart against goal (optionally read from Apple Health), protein this week, 28-day tablet calendar, food noise trend |
| Report | 30-day visit summary, questions for the clinician, share as text; PDF with Dawnwell Plus |
| Learn | Stage tip by days on treatment and short articles |
| Dawnwell Plus | $4.99 a month or $29.99 a year, first week free (StoreKit 2) |

Also: reminders for the tablet, the end of the wait, a 3 PM protein check and a refill; a lock-screen Live Activity counting down the wait; light and dark themes.

## How data is kept safe

There is no Dawnwell server. Data lives in SwiftData on the phone and syncs to the user's own private iCloud database.

- If iCloud can't be opened, the app keeps working on the same local file. Nothing is deleted.
- One copy a day is kept on the phone for a week, plus a copy before every restore.
- A backup file can be exported and restored at any time. A restore that fails is rolled back.

## Build and test

The Xcode project is generated from `ios/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd ios
xcodegen generate
open Dawnwell.xcodeproj
```

CI (`.github/workflows/ios.yml`) builds and runs the tests on a simulator on every pull request. `ios/StoreKit/Dawnwell.storekit` lets you test the subscription in the simulator without App Store Connect.

## Layout

```
ios/Dawnwell/App/            app entry
ios/Dawnwell/Features/       one folder per screen
ios/Dawnwell/Model/          pure logic: reminders, stats, report, Health import, Plus
ios/Dawnwell/Data/           SwiftData schema, repository, backups, iCloud status
ios/Dawnwell/Notifications/  reminders and the Live Activity controller
ios/Dawnwell/Store/          StoreKit 2
ios/Dawnwell/UI/             theme (light and dark) and shared components
ios/DawnwellWidgets/         Live Activity extension
ios/Shared/                  code shared by the app and the extension
ios/DawnwellTests/           unit tests
design/                      app icon sources (SVG)
```

## Before release: Apple setup

- Identifiers: iCloud container `iCloud.com.dawnwell.app`; App ID `com.dawnwell.app` with iCloud (CloudKit), Push Notifications and HealthKit; App ID `com.dawnwell.app.widgets`.
- App Store Connect: subscription group with `com.dawnwell.app.plus.monthly` and `com.dawnwell.app.plus.yearly`.

## First iCloud setup (once, no Mac needed)

iCloud syncs only record types that exist in the container's Production schema.

1. Actions → TestFlight → Run workflow with **iCloud environment: Development**. This build creates the record types on first launch (`CloudSchema`), in a throwaway store.
2. Install it from TestFlight, signed in to iCloud, open it once on Wi-Fi.
3. In [CloudKit Console](https://icloud.developer.apple.com/) → `iCloud.com.dawnwell.app` → Schema, check the `CD_` record types are there, then **Deploy Schema Changes** to Production.
4. From then on, run the workflow with **Production** (the default). Never submit a Development build for review.
