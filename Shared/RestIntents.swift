import AppIntents
import Foundation

/// Mutations the Lock Screen buttons make. `LiveActivityIntent` runs in the
/// app's process — which iOS may cold-launch in the background — so the durable
/// `DraftStore` is the only state these can rely on. The change is written
/// there first, then broadcast so a foreground app picks it up rather than
/// overwriting it.
enum RestIntentRunner {
    static func apply(_ mutate: (inout DraftSnapshot) -> Void) async {
        guard var snapshot = DraftStore.load() else { return }
        mutate(&snapshot)
        DraftStore.save(snapshot)
        await RestActivity.sync(snapshot)
        await MainActor.run {
            NotificationCenter.default.post(name: DraftStore.changedNotification, object: nil)
        }
    }
}

/// "+30s" — extends both the remaining time and the target, so the ring stays
/// proportional instead of jumping backwards.
struct AddRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add 30 seconds of rest"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await RestIntentRunner.apply { $0.addRest(30) }
        return .result()
    }
}

/// "Log set n" — the same action as tapping the ringed tile in the app.
struct LogRingedSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log the next set"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await RestIntentRunner.apply { $0.logRingedSet() }
        return .result()
    }
}
