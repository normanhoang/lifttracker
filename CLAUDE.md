# CLAUDE.md

Guidance for working in this repo. See global `~/.claude/CLAUDE.md` for general rules.

## What this is

LiftTracker — a lifting 5×5 iPhone tracker. SwiftUI + SwiftData, iOS 17+, iPhone-only, portrait. Includes a Live Activity rest timer widget.

## Project is generated

`LiftTracker.xcodeproj` is **generated from `project.yml` by XcodeGen** — do not hand-edit the `.pbxproj`. After changing targets, build settings, or Info.plist keys, run:

```bash
xcodegen generate
```

## Build / test / archive

```bash
# regenerate project
xcodegen generate

# build
xcodebuild -project LiftTracker.xcodeproj -scheme LiftTracker \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

# test (unit + UI)
xcodebuild -project LiftTracker.xcodeproj -scheme LiftTracker \
  -destination 'platform=iOS Simulator,name=iPhone 15' test

# archive + export ipa for App Store
xcodebuild -project LiftTracker.xcodeproj -scheme LiftTracker \
  -configuration Release -archivePath build/LiftTracker.xcarchive archive
xcodebuild -exportArchive -archivePath build/LiftTracker.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/ipa
```

## Layout

- `LiftTracker/Models/` — SwiftData `@Model` types (`WorkoutSession`, `LoggedExercise`, `ExerciseProgress`) and the `Exercise` / `WorkoutType` program enums.
- `LiftTracker/Logic/` — pure functions: `Progression` (5×5 rules), `WeightFormat` (lb/kg). Unit-tested; keep them free of SwiftUI/SwiftData.
- `LiftTracker/Views/` — feature folders: Workout, History, Progress, Settings, plus `RootTabView`.
- `Shared/RestTimerAttributes.swift` — ActivityKit attributes, shared between app and widget.
- `RestTimerWidget/` — Live Activity extension. **Has its own `Info.plist`** (`INFOPLIST_FILE` set), so app-level `INFOPLIST_KEY_*` build settings do NOT apply to it — edit the plist directly for widget keys.

## Conventions

- Program definition (day → lifts, increments, starting weights) lives entirely in `Exercise` / `WorkoutType`. Change the workout there, not in views.
- Progression logic: success = every set hit target reps; +increment on success, deload to 90% (round to 5) after 3 straight fails. Encoded in `Progression.apply`.
- New pure logic → add a test in `LiftTrackerTests/`.
- On first launch, `LiftTrackerApp.seedIfNeeded` creates an `ExerciseProgress` row per lift.
- **App icon must have no alpha channel.** If `icon-1024.png` is RGBA (even fully opaque), the watchOS Smart Stack renders the Live Activity icon as a white box; iPhone looks fine, so it slips through testing. Has regressed twice. After regenerating the icon, verify with `sips -g hasAlpha` (must be `no`).

## Release notes

- Bump `CURRENT_PROJECT_VERSION` (build) and/or `MARKETING_VERSION` in `project.yml`, then `xcodegen generate`.
- App Store metadata reference: `AppStoreConnect.md`. Privacy/support pages: `docs/`.
