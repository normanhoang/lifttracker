# LiftTracker

A dead-simple lifting workout tracker for iPhone. Log sets with a tap; the app handles progression, deloads, and a Lock Screen rest timer.

## Features

- **Lifting 5×5 auto-progression** — weight goes up after a successful session, deloads 10% after three straight failures
- **Tap-to-log rep circles** — no keyboards mid-set
- **Live Activity rest timer** — Lock Screen and Dynamic Island
- **History calendar** of every workout
- **Progress charts** per lift, plus a squat + bench + deadlift total
- **Pounds or kilograms**
- 100% on-device. No accounts, no network, no ads.

## The program

Two alternating days:

| Day | Lifts |
|---|---|
| **A** | Squat 5×5 · Bench Press 5×5 · Barbell Row 5×5 |
| **B** | Squat 5×5 · Overhead Press 5×5 · Deadlift 1×5 |

Progression per lift: +5 lb on success (+10 lb deadlift); after 3 failed sessions, deload to 90% (rounded to 5).

## Requirements

- iOS 17.0+, iPhone (portrait)
- Xcode 15+
- [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml`

## Build

```bash
xcodegen generate          # regenerate LiftTracker.xcodeproj from project.yml
open LiftTracker.xcodeproj  # then build/run in Xcode
```

Or from the command line:

```bash
xcodebuild -project LiftTracker.xcodeproj -scheme LiftTracker \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Test

```bash
xcodebuild -project LiftTracker.xcodeproj -scheme LiftTracker \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

## Project layout

```
LiftTracker/
  Models/      SwiftData @Model types + Exercise/WorkoutType enums
  Logic/       Progression rules, weight formatting (pure, unit-tested)
  Views/       Workout, History, Progress, Settings + RootTabView
Shared/        RestTimerAttributes (shared with widget)
RestTimerWidget/  Live Activity extension
LiftTrackerTests/     Unit tests
LiftTrackerUITests/   UI + screenshot tests
docs/          Privacy + support pages (GitHub Pages)
```

## Architecture

- **SwiftUI + SwiftData**. `ModelContainer` holds `WorkoutSession`, `LoggedExercise`, `ExerciseProgress`; seeded on first launch with starting weights.
- **ActivityKit** drives the rest timer Live Activity.
- Program config (`Exercise`, `WorkoutType`) and progression math are plain value types, kept out of the views and covered by unit tests.

## License

See [LICENSE](LICENSE).
