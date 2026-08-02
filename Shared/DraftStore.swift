import Foundation

/// Durable home for the in-progress workout. A 45-minute session used to die
/// with the process; it now survives a crash, a reboot, and a background
/// cold-launch triggered by a Live Activity button.
///
/// `UserDefaults.standard` is deliberate: `LiveActivityIntent.perform()` runs in
/// the app's own process, so no app group (and no provisioning change) is needed.
enum DraftStore {
    static let key = "workoutDraft"
    private static let lock = NSLock()

    /// Posted after an App Intent mutates the stored draft so a live app
    /// instance can pick the change up instead of overwriting it.
    static let changedNotification = Notification.Name("DraftStore.changed")

    static func load(from defaults: UserDefaults = .standard) -> DraftSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnlocked(from: defaults)
    }

    @discardableResult
    static func save(_ snapshot: DraftSnapshot,
                     to defaults: UserDefaults = .standard) -> DraftSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return saveUnlocked(snapshot, to: defaults)
    }

    /// Atomically read, mutate, and write the draft. The app and Live Activity
    /// intent both use this path, so one mutation cannot overwrite another
    /// mutation that was in flight at the same time.
    @discardableResult
    static func mutate(to defaults: UserDefaults = .standard,
                       _ body: (inout DraftSnapshot) -> Void) -> DraftSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard var snapshot = loadUnlocked(from: defaults) else { return nil }
        body(&snapshot)
        return saveUnlocked(snapshot, to: defaults)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }

    private static func loadUnlocked(from defaults: UserDefaults) -> DraftSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DraftSnapshot.self, from: data)
    }

    private static func saveUnlocked(_ snapshot: DraftSnapshot,
                                     to defaults: UserDefaults) -> DraftSnapshot? {
        var copy = snapshot
        copy.savedAt = .now
        guard let data = try? JSONEncoder().encode(copy) else { return nil }
        defaults.set(data, forKey: key)
        return copy
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
