import Foundation
import Combine
import ActivityKit

/// Counts UP from the moment a set is tapped, and mirrors the elapsed time to a
/// Live Activity (Lock Screen + Dynamic Island). Restarted on each new set tap.
@MainActor
final class RestTimerModel: ObservableObject {
    @Published private(set) var startDate: Date?
    @Published private(set) var running = false

    private var activity: Activity<RestTimerAttributes>?

    /// Restart the count-up (called on the first tap of a set).
    /// The in-app label renders `Text(startDate, style: .timer)`, which
    /// self-updates — no per-second ticking needed.
    func start(workoutTitle: String) {
        let now = Date()
        startDate = now
        running = true
        startOrRestartActivity(now: now, title: workoutTitle)
    }

    func stop() {
        running = false
        startDate = nil
        endActivity()
    }

    // MARK: - Live Activity

    private func startOrRestartActivity(now: Date, title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RestTimerAttributes.ContentState(startDate: now)
        // Mark the activity stale after 30 min so an abandoned workout doesn't
        // leave a live-looking timer on the Lock Screen.
        let stale = now.addingTimeInterval(30 * 60)

        if let activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: stale)) }
            return
        }
        do {
            activity = try Activity.request(
                attributes: RestTimerAttributes(workoutTitle: title),
                content: ActivityContent(state: state, staleDate: stale)
            )
        } catch {
            activity = nil
        }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
