import Foundation
import Combine
import UserNotifications

/// Side effects of the rest countdown: the Lock Screen activity and the
/// end-of-rest haptic. The countdown itself is state on `DraftSnapshot` and is
/// rendered directly from it, so there is nothing to tick here.
@MainActor
final class RestTimerModel: ObservableObject {
    private static let notificationID = "restTimerElapsed"
    private var lastSyncedEnd: Date?

    /// Mirror the draft's rest state out to the system. Cheap to call on every
    /// mutation: it no-ops unless the end time actually moved.
    func sync(_ snapshot: DraftSnapshot) {
        guard snapshot.restEndDate != lastSyncedEnd else { return }
        lastSyncedEnd = snapshot.restEndDate

        if let end = snapshot.restEndDate, end > .now {
            scheduleHaptic(at: end)
        } else {
            cancelHaptic()
        }
        Task { await RestActivity.sync(snapshot) }
    }

    /// End rest entirely — finishing or discarding the workout.
    func stop() {
        lastSyncedEnd = nil
        cancelHaptic()
        Task { await RestActivity.end() }
    }

    // MARK: - Haptic notification

    /// A local notification rather than an in-app haptic: it fires with the app
    /// backgrounded or the phone locked, which is where the phone actually is
    /// between sets.
    private func scheduleHaptic(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Start your next set."
        content.sound = .default
        let seconds = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        Task { try? await center.add(request) }
    }

    private func cancelHaptic() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }
}
