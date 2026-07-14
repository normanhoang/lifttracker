import Foundation
import Combine
import ActivityKit
import UserNotifications

/// Counts UP from the moment a set is tapped, and mirrors the elapsed time to a
/// Live Activity (Lock Screen + Dynamic Island). Restarted on each new set tap.
@MainActor
final class RestTimerModel: ObservableObject {
    @Published private(set) var startDate: Date?
    @Published private(set) var running = false

    private var activity: Activity<RestTimerAttributes>?

    private static let notificationID = "restTimerElapsed"

    /// Restart the count-up (called on the first tap of a set).
    /// The in-app label renders `Text(startDate, style: .timer)`, which
    /// self-updates — no per-second ticking needed.
    func start(workoutTitle: String) {
        let now = Date()
        startDate = now
        running = true
        let restDuration = Self.currentRestDurationSeconds()
        startOrRestartActivity(now: now, title: workoutTitle)
        scheduleHapticNotification(after: restDuration)
    }

    func stop() {
        running = false
        startDate = nil
        endActivity()
        cancelHapticNotification()
    }

    private static func currentRestDurationSeconds() -> TimeInterval {
        RestDurationSetting.resolve(UserDefaults.standard.object(forKey: RestDurationSetting.key) as? Double)
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

    // MARK: - Haptic notification

    /// Schedules a local notification at the rest threshold. Works whether the
    /// app is foreground, backgrounded, or the phone is locked — unlike an
    /// in-app haptic call, which only fires while the app process is alive.
    private func scheduleHapticNotification(after seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Start your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        Task { try? await center.add(request) }
    }

    private func cancelHapticNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }
}
