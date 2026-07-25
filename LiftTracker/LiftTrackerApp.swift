import SwiftUI
import SwiftData
import UserNotifications

@main
struct LiftTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: WorkoutSession.self, LoggedExercise.self, ExerciseProgress.self,
                BodyWeightEntry.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        Self.seedIfNeeded(container.mainContext)
        #if DEBUG
        // App Store screenshots: ten weeks of training instead of a fresh install.
        if ProcessInfo.processInfo.arguments.contains("-seedDemoData") {
            DemoData.reset(container.mainContext)
        }
        #endif
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
            let row = ExerciseProgress(exerciseID: ex.rawValue, currentWeight: ex.startingWeight)
            row.restSeconds = ex.defaultRestSeconds
            context.insert(row)
            inserted = true
        }
        if inserted {
            do { try context.save() } catch {
                print("seedIfNeeded: failed to save: \(error)")
            }
        }
        backfillBestWeights(context)
        migrateRestDuration(context)
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

    /// Rest moved from one global setting to a per-lift value. Carry the user's
    /// choice across — in particular an "Off", which must not silently flip back on.
    @MainActor
    private static func migrateRestDuration(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "didMigrateRestDuration") else { return }
        defaults.set(true, forKey: "didMigrateRestDuration")

        let rows = (try? context.fetch(FetchDescriptor<ExerciseProgress>())) ?? []
        let stored = defaults.object(forKey: RestDurationSetting.key) as? Double

        if stored == nil {
            // Never chose one: take the per-lift defaults rather than a flat 90.
            for row in rows {
                row.restSeconds = row.exercise?.defaultRestSeconds ?? 90
            }
        } else if let resolved = RestDurationSetting.resolve(stored) {
            for row in rows { row.restSeconds = Int(resolved) }
        } else {
            for row in rows { row.restSeconds = 0 }   // was Off
        }
        do { try context.save() } catch {
            print("migrateRestDuration: failed to save: \(error)")
        }
    }
}
