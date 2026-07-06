# App Store Connect — LiftTracker

Reference sheet for App Store Connect submission. Fill blanks marked `TODO`.

## App Identity

| Field | Value |
|---|---|
| App Name | LiftTracker - Track your lifts |
| Bundle ID | `com.norman.LiftTracker` |
| SKU | `TODO` (e.g. `lifttracker-001`) |
| Apple Team ID | `DZRPJF9JB6` |
| Primary Language | English (U.S.) |
| Marketing Version | 1.0 |
| Build Number | 1 |
| Min iOS | 17.0 |
| Devices | iPhone only, portrait |
| Extensions | RestTimerWidget (Live Activity) — `com.norman.LiftTracker.RestTimerWidget` |

## Category

- Primary: **Health & Fitness**
- Secondary (optional): Sports

## Pricing & Availability

- Price: Free (`TODO` confirm)
- Availability: All countries (`TODO` confirm)

## Age Rating

- 4+ (no objectionable content). Answer all questionnaire items "None".

## App Privacy

App stores all data on-device (AppStorage / local). No account, no network calls.

- Data collected: **None** → "Data Not Collected"
- Tracking: No
- Privacy Policy URL: `TODO` (required even with no data — host a simple page)

## Description

```
LiftTracker is a dead-simple StrongLifts 5×5 tracker. Log your sets with a tap,
and the app handles the math: add weight when you succeed, deload after three
straight fails.

FEATURES
• StrongLifts 5×5 auto-progression — weight goes up on success, deloads 10% after 3 failed sessions
• Tap-to-log rep circles, no fiddly keyboards
• Live Activity rest timer on your Lock Screen and Dynamic Island
• History calendar of every workout
• Progress charts per exercise
• Pounds or kilograms

No accounts. No ads. No cloud. Your data stays on your phone.
```

## Keywords

```
stronglifts,5x5,barbell,gym,workout,lifting,strength,squat,bench,deadlift,progression,tracker
```
(100-char limit, comma-separated, no spaces after commas)

## Promotional Text (170 chars, editable anytime)

```
Log 5×5 lifts with a tap. Auto-progression and a Lock Screen rest timer built in.
```

## Support / Marketing URLs

- Support URL: `TODO` (required)
- Marketing URL: `TODO` (optional)

## What's New (release notes)

```
Initial release.
```

## Screenshots

Located in `screenshots/`. Size: **1242 × 2688** (6.5" iPhone).

| File | Shows |
|---|---|
| `01_workout.png` | Workout logging |
| `02_history.png` | History calendar |
| `03_progress.png` | Progress charts |
| `04_settings.png` | Settings |

Notes:
- 6.5" set covers most devices. `TODO`: App Store Connect may also require **6.9"** (1290 × 2796) for newest iPhones — regenerate if rejected.
- iPad screenshots not needed (iPhone-only app).

## App Review

- Sign-in required: No
- Demo account: N/A
- Notes for reviewer: "All data is on-device. Rest timer uses Live Activities — start a workout, select sets, and the timer appears."

## Build & Upload

Archive already at `build/LiftTracker.xcarchive`. Export options at `build/ExportOptions.plist`.

```bash
# regenerate project if needed
xcodegen generate

# archive
xcodebuild -project LiftTracker.xcodeproj -scheme LiftTracker \
  -configuration Release -archivePath build/LiftTracker.xcarchive archive

# export ipa
xcodebuild -exportArchive -archivePath build/LiftTracker.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/ipa

# upload
xcrun altool --upload-app -f build/ipa/LiftTracker.ipa \
  -t ios -u <apple-id> -p <app-specific-password>
# or use Transporter.app
```

## Pre-submit Checklist

- [ ] Bundle ID registered on App Store Connect
- [ ] App record created (name, SKU, primary language)
- [ ] Category set
- [ ] Privacy Policy URL live
- [ ] Support URL live
- [ ] Screenshots uploaded (6.5", maybe 6.9")
- [ ] Description / keywords / promo text entered
- [ ] Age rating questionnaire done
- [ ] Build uploaded and processed
- [ ] Export compliance answered (no encryption → likely exempt)
- [ ] Submit for review
