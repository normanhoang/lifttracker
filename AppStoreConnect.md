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
| Marketing Version | 1.1 |
| Build Number | 9 |
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
- Privacy Policy URL: `normanhoang.github.io/lifttracker/privacy.html` (required even with no data — host a simple page)

## Description

```
LiftTracker is a dead-simple 5×5 barbell tracker. Log a set with one tap, and
the app handles the math: add weight when you hit all five sets, take 10% off
after three straight misses. It tells you what it's doing and why, every time.

FEATURES
• 5×5 auto-progression — and the app states it in plain words: what goes up,
  what holds, what deloads, and how many misses are left before it does
• One lift at a time. The set you're on is ringed; the rest stay out of the way
• Tap to log five, hold to pick a different number, undo a mis-tap
• Plate math — what to hang on each side, from the plates you actually own
• Rest timer per lift, counting down, on your Lock Screen with buttons that
  work without unlocking
• Every session in one screen: five weeks at a glance, then set-by-set detail
• Progress charts that show the plateaus instead of smoothing them away
• Pounds or kilograms, with the right bar and plates for each

No accounts. No ads. No cloud. Your data stays on your phone.
```

## Keywords

```
5x5,barbell,gym,workout,strength,squat,bench,deadlift,progression,tracker,plates,rest timer
```
(100-char limit, comma-separated, no spaces after commas. The old list repeated
"lifting" twice and spent characters on a word already in the app name.)

## Promotional Text (170 chars, editable anytime)

```
Rebuilt: one lift at a time, plate math, per-lift rest, and a Lock Screen timer
you can log from. The app now tells you what it's doing to your weights.
```

## Support / Marketing URLs

- Support URL: `normanhoang.github.io/lifttracker/support.html` (required)
- Marketing URL: `TODO` (optional)

## What's New (release notes)

```
Every screen rebuilt around one question: what is the app doing to my weights,
and why?

THE WORKOUT SCREEN
• One lift is open at a time, with the next set ringed. Finished lifts collapse
  above it, upcoming ones wait below
• Tap a set to log five. Hold it to pick a different number — no more tapping
  five times to get to four
• Undo takes back a mis-tap instead of making you cycle past it
• Plate math shows what to hang on each side, using the plates you own
• Skip a lift on purpose, or discard a session you never should have started —
  and the app says plainly that discarding changes no weights

PROGRESSION, OUT LOUD
• The workout card, the summary screen and Settings all state what happens next:
  what goes up, what holds, what deloads, and how many misses are left
• The end-of-session screen reports what changed and why, per lift

REST
• Counts down instead of up, and each lift gets its own rest length (or none)
• Lock Screen timer gains +30s and Log Set buttons — the phone stays in your
  pocket

HISTORY AND PROGRESS
• Five weeks at a glance, then session cards, then set-by-set detail
• Charts step between weights instead of drawing curves through weights you
  never lifted
• Body weight can be logged any day, not only alongside a workout
• Deleting a session can be undone

ALSO
• A first-run screen that explains the program in four sentences
• Fixed: editing a weight by hand no longer carries old misses toward a deload
```

## Screenshots

Located in `screenshots/`. Size: **1242 × 2688** (6.5" iPhone).

| File | Shows | Upload |
|---|---|---|
| `01_workout.png` | Workout logging | Yes |
| `02_history.png` | History (empty state) | Yes |
| `03_progress.png` | Progress | Yes |
| `04_settings.png` | Settings — working weights, the bar | Yes |
| `00_first_run.png` | First-run explainer | Optional |

Regenerate with the UI test, on an **erased** simulator — a leftover
`ExerciseProgress` row from a previous test run will otherwise show a phantom
miss on squat:

```bash
xcrun simctl erase "iPhone 11 Pro Max"
xcodebuild -project LiftTracker.xcodeproj -scheme LiftTracker \
  -destination 'platform=iOS Simulator,name=iPhone 11 Pro Max' \
  -resultBundlePath build/screens.xcresult \
  test -only-testing:LiftTrackerUITests/ScreenshotUITests
xcrun xcresulttool export attachments \
  --path build/screens.xcresult --output-path <dir>   # names are in manifest.json
```

Notes:
- These are captured on a **fresh install**, so History and Progress show empty
  states. Seeding a demo dataset would sell the app better — the redesigned
  History and Progress screens are the ones that need data to look like anything.
- 6.5" set covers most devices. `TODO`: App Store Connect may also require **6.9"** (1290 × 2796) for newest iPhones — regenerate if rejected.
- iPad screenshots not needed (iPhone-only app).

## App Review

- Sign-in required: No
- Demo account: N/A
- Notes for reviewer: "All data is on-device; no account, no network. Tap a set tile on the Workout tab to log it — a rest countdown appears above the Finish button and as a Live Activity on the Lock Screen, with buttons to add 30 seconds or log the next set. Press and hold a tile to enter a different rep count."

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

### 1.1 specifically

- [ ] **Open a store created by the shipping build before submitting.** 1.1 adds
      four SwiftData properties and removes `WorkoutSession.bodyWeight`. It is a
      lightweight migration, but a store that fails to open shows as an empty
      program rather than a crash, so a fresh-install test will not catch it.
- [ ] Body weights previously logged against a session are **not** carried over —
      this was a deliberate call, not a bug to fix later.
- [ ] Rest is now per lift. An existing global "Off" migrates to Off on every
      lift; any other value migrates to that value on every lift.
- [ ] There is no export, so users have no backup path. Worth knowing before you
      ship a migration.
