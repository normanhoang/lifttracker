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
