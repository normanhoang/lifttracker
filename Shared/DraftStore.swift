import Foundation

/// Durable home for the in-progress workout. A 45-minute session used to die
/// with the process; it now survives a crash, a reboot, and a background
/// cold-launch triggered by a Live Activity button.
///
/// `UserDefaults.standard` is deliberate: `LiveActivityIntent.perform()` runs in
/// the app's own process, so no app group (and no provisioning change) is needed.
enum DraftStore {
    static let key = "workoutDraft"

    /// Posted after an App Intent mutates the stored draft so a live app
    /// instance can pick the change up instead of overwriting it.
    static let changedNotification = Notification.Name("DraftStore.changed")

    static func load(from defaults: UserDefaults = .standard) -> DraftSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DraftSnapshot.self, from: data)
    }

    static func save(_ snapshot: DraftSnapshot, to defaults: UserDefaults = .standard) {
        var copy = snapshot
        copy.savedAt = .now
        guard let data = try? JSONEncoder().encode(copy) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    /// A 5×5 session is one sitting. Resuming a Monday draft on Thursday would
    /// stamp Thursday's date on Monday's lifts and progress the program off it,
    /// so anything older than today is dropped rather than offered.
    static func isResumable(_ snapshot: DraftSnapshot,
                            now: Date = .now,
                            calendar: Calendar = .current) -> Bool {
        guard snapshot.hasProgress else { return false }
        return calendar.isDate(snapshot.savedAt, inSameDayAs: now)
    }
}
