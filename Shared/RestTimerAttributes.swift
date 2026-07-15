import Foundation
import ActivityKit

/// Live Activity payload for the rest-timer count-up. The widget renders a
/// self-updating `Text(startDate, style: .timer)`, so no per-second pushes are needed.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
    }

    var workoutTitle: String
}

/// Shared so the app, the widget extension, and unit tests all resolve the
/// same rest-duration default. `UserDefaults.double(forKey:)` returns 0 for a
/// missing key, which is not a valid duration, so callers must route through
/// `resolve` rather than reading the default inline. "Off" is stored as the
/// `offValue` sentinel (0 can't be used — it collides with the missing key)
/// and resolves to nil, meaning no rest-complete notification.
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
