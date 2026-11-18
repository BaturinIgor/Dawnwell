# Dawnwell

A daily companion for people taking a GLP-1 medicine as a tablet (oral semaglutide, orforglipron).
It answers the questions that come up every morning: *did I take it, when can I eat, how much protein have I had*, and turns a month of logging into a summary you can bring to your clinician.

Dawnwell only reminds and records. It never suggests or changes a dose: everything about the medicine is copied from the user's prescription label.

## What's in this version

| Screen | What it does |
| --- | --- |
| Onboarding | Medication, dose from the label, usual time, empty-stomach wait, weight goal, protein target, reminders |
| Today | Tablet card (pending, overdue, waiting with live countdown, done), protein ring with quick add, water, fiber, strength, food noise, symptoms, refill heads-up |
| Add food | Searchable list sorted by protein, meal picker, custom item |
| Symptom details | Severity 1–5, likely triggers, note for the visit; severe entries show a "contact your clinician" note |
| Medication | Update from label (keeps a dose history), usual time, wait, tablets left and refill, reminder switches |
| Progress | Weight log and chart against goal, protein this week, 28-day tablet calendar, food noise trend |
| Report | 30-day visit summary, questions for the clinician, share as text |
| Learn | Stage tip by days on treatment and short articles |

Local notifications: daily tablet reminder, 3 PM protein check, and a one-off "wait is over" alert after the tablet is logged.

All data stays on the device (AsyncStorage). There is no account or backend yet.

## Run it

```bash
npm install
npx expo start
```

Then open it in Expo Go or a development build on iOS or Android. Notifications need a physical device.

```bash
npx tsc --noEmit   # type check
npx expo lint      # lint
```

## Stack

Expo SDK 58, Expo Router (`src/app`), native tabs, React Compiler, `expo-notifications`, `react-native-svg`, `@react-native-async-storage/async-storage`.

## Layout

```
src/app/           screens (file-based routes)
src/app/(tabs)/    Today, Progress, Report, Learn
src/components/    shared UI (ui.tsx, stepper.tsx)
src/lib/           store, types, notifications, date helpers, food and symptom catalog
src/constants/     theme tokens
```

## Not yet done

- App icon and splash screen (still the Expo defaults)
- Subscription paywall (planned: reports, insights and backup are paid; tablet, timer and protein stay free)
- Cloud backup, Apple Health / Health Connect, home screen widget
