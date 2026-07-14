import SwiftUI
import SwiftData
import UserNotifications

@main
struct LiftTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: WorkoutSession.self, LoggedExercise.self, ExerciseProgress.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        Self.seedIfNeeded(container.mainContext)
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }

    /// Create an ExerciseProgress row for any lift that doesn't have one yet.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ExerciseProgress>())) ?? []
        let have = Set(existing.map(\.exerciseID))
        var inserted = false
        for ex in Exercise.allCases where !have.contains(ex.rawValue) {
            context.insert(ExerciseProgress(exerciseID: ex.rawValue, currentWeight: ex.startingWeight))
            inserted = true
        }
        if inserted {
            do { try context.save() } catch {
                print("seedIfNeeded: failed to save: \(error)")
            }
        }
        backfillBestWeights(context)
    }

    /// One-time backfill of `ExerciseProgress.bestWeight` from history, for installs that
    /// predate the field. Guarded so it scans the log table once, not on every launch.
    @MainActor
    private static func backfillBestWeights(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: "didBackfillBestWeight") else { return }
        let logged = (try? context.fetch(FetchDescriptor<LoggedExercise>())) ?? []
        var best: [String: Double] = [:]
        for ex in logged where !ex.isSkipped {
            best[ex.exerciseID] = max(best[ex.exerciseID] ?? 0, ex.weight)
        }
        let rows = (try? context.fetch(FetchDescriptor<ExerciseProgress>())) ?? []
        for p in rows {
            if let m = best[p.exerciseID] { p.bestWeight = max(p.bestWeight, m) }
        }
        do { try context.save() } catch {
            print("backfillBestWeights: failed to save: \(error)")
        }
        UserDefaults.standard.set(true, forKey: "didBackfillBestWeight")
    }
}
