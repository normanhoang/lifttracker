import SwiftUI
import SwiftData

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
    }
}
