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
    private let notificationCenter: RestNotificationCenter
    private var notificationTask: Task<Void, Never>?
    private var pendingNotificationID: String?

    init(notificationCenter: RestNotificationCenter = UNUserNotificationCenter.current()) {
        self.notificationCenter = notificationCenter
        sweepTask = Task { await self.sweepStaleNotifications() }
    }

    /// The UUID-suffixed request IDs live only in memory, so a rest notification
    /// scheduled by a previous process (killed mid-rest) would otherwise be
    /// uncancellable. Sweep anything with our prefix that we didn't schedule.
    private var sweepTask: Task<Void, Never>?

    private func sweepStaleNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter {
            $0.hasPrefix(Self.notificationID) && $0 != pendingNotificationID
        }
        guard !stale.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: stale)
    }

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
        notificationTask?.cancel()
        if let pendingNotificationID {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [pendingNotificationID])
        }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Start your next set."
        content.sound = .default
        let seconds = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let requestID = "\(Self.notificationID).\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        pendingNotificationID = requestID
        let center = notificationCenter
        notificationTask = Task {
            guard !Task.isCancelled else { return }
            try? await center.add(request)
            if Task.isCancelled {
                center.removePendingNotificationRequests(withIdentifiers: [requestID])
            }
        }
    }

    private func cancelHaptic() {
        notificationTask?.cancel()
        if let pendingNotificationID {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [pendingNotificationID])
            self.pendingNotificationID = nil
        }
    }

    /// Test seam for draining the current scheduling operation.
    func waitForNotificationOperations() async {
        await sweepTask?.value
        await notificationTask?.value
    }
}

protocol RestNotificationCenter: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: RestNotificationCenter {}
