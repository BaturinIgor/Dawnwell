# App Store listing (1.0)

The texts App Store Connect gets live in `ios/AppStore/` (one file per language in `listing/`, products and their prices in `products.json`, review notes in `review-notes.txt`). The **App Store listing** workflow (Actions → App Store listing → Run workflow) fills App Store Connect from them, with screenshots taken in every language. Start with `check`, then `everything`.

What the workflow cannot do, done by hand once: App Privacy (see below), the App Review contact name and phone, and Submit for Review.

The English text below is kept for reading; `ios/AppStore/listing/en-US.json` wins if they differ.

## Name and subtitle

- **Name** (30): `Dawnwell: GLP-1 Pill Tracker`
- **Subtitle** (30): `Dose time, wait timer, protein`

## Promotional text (170)

Take your GLP-1 tablet on time, know exactly when you can eat, and hit your protein goal. Bring a clear 30-day summary to your next visit.

## Description

Dawnwell is a daily companion for people taking a GLP-1 medicine as a tablet.

Oral GLP-1 tablets come with rules that are easy to get wrong in a sleepy morning: take it on an empty stomach, with a little water, then wait before you eat or drink anything else. Dawnwell keeps track for you.

TABLET AND WAIT TIMER
• A reminder at your usual time
• One tap to log the tablet, then a countdown on your lock screen until you can eat
• A heads-up when you are running low on tablets

PROTEIN AND HABITS
• A protein ring with quick add from a list sorted by protein
• Water, fiber, strength training and food noise in a few taps
• A 3 PM check if you are behind on protein

SYMPTOMS AND PROGRESS
• Log nausea and other side effects with severity, triggers and a note
• Weight chart against your goal, optionally from Apple Health
• A 28-day tablet calendar

READY FOR YOUR VISIT
• A 30-day summary with questions for your clinician
• Share it as text, or as a PDF with Dawnwell Plus

YOUR DATA STAYS YOURS
• No account. No ads. No tracking.
• Data stays on your iPhone and syncs to your own private iCloud
• Daily copies on the phone and a backup file you control

Dawnwell only reminds and records. It never suggests or changes a dose. Medication details come from your prescription label. Always follow your prescriber's instructions.

DAWNWELL PLUS
$4.99 a month or $29.99 a year, with a free first week, or $59.99 once for lifetime access. Plus adds the PDF report. Payment is charged to your Apple ID. The subscription renews automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel it in Settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://baturinigor.github.io/Dawnwell/privacy

## Keywords (100)

`glp-1,oral,semaglutide,rybelsus,orforglipron,pill,reminder,protein,weight,fasting,timer,side effects`

## Category

Primary: Health & Fitness. Secondary: Medical.

## Age rating

Medical/Treatment Information: Infrequent/Mild. Everything else: None.

## URLs

- Privacy Policy URL: https://baturinigor.github.io/Dawnwell/privacy
- Support URL: https://baturinigor.github.io/Dawnwell/

## App Privacy ("nutrition label")

From 1.0.1 the app sends anonymous usage events through TelemetryDeck (see `ios/Dawnwell/App/Analytics.swift`). Answer: **Data is collected** → **Usage Data → Product Interaction**, used for **Analytics**, **not linked** to the user, **not used for tracking**. Everything the user logs still stays on the device and in their private iCloud, which Apple does not count as collection.

## Export compliance

Uses only Apple's built-in encryption. `ITSAppUsesNonExemptEncryption` is set to NO, so no question is asked on upload.

## Notes for App Review

Dawnwell is a tracker and reminder app for people already prescribed an oral GLP-1 medicine. It does not give medical or dosing advice: the user copies the medication name, dose and timing from their own prescription label, and the app never suggests or changes a dose. Severe symptom entries show a note to contact a clinician.

No account or sign-in is needed. To try the subscription, use the sandbox account; Plus unlocks the PDF report on the Report tab.

Apple Health is read-only and used only to show weight on the Progress chart.
