import Foundation
import ActivityKit

/// Live Activity payload for the rest countdown. The widget renders
/// `Text(timerInterval:countsDown:)` against `endDate`, so it ticks without
/// per-second pushes; a push is only needed when the target itself changes
/// (+30s, a new set, skip).
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the countdown reaches zero.
        var endDate: Date
        /// Full rest length for this set, so the bar/ring stays proportional
        /// after `+30s` extends both ends.
        var targetSeconds: Int
        var liftName: String
        /// 1-based number of the set the user comes back to.
        var setNumber: Int
        var totalSets: Int
        /// Preformatted so the widget never needs the app's unit setting.
        var weightText: String
        /// Which lift/set the `Log set n` button acts on.
        var liftID: String
        var setIndex: Int

        var startDate: Date { endDate.addingTimeInterval(-TimeInterval(targetSeconds)) }
    }

    var workoutTitle: String
}

/// Legacy global rest duration. Superseded by per-lift `ExerciseProgress.restSeconds`;
/// kept only so the one-time migration can read what the user had chosen — in
/// particular an "Off" that must not silently flip back on.
enum RestDurationSetting {
    static let key = "restDurationSeconds"
    static let defaultValue: TimeInterval = 60
    static let offValue: TimeInterval = -1

    static func resolve(_ stored: Double?) -> TimeInterval? {
        guard let stored else { return defaultValue }
        if stored == offValue { return nil }
        return stored > 0 ? stored : defaultValue
    }
}
