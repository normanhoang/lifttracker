import Foundation
import SwiftData

/// Persisted working weight + fail streak for a single lift. One row per exercise.
@Model
final class ExerciseProgress {
    @Attribute(.unique) var exerciseID: String
    var currentWeight: Double
    var failStreak: Int

    init(exerciseID: String, currentWeight: Double, failStreak: Int = 0) {
        self.exerciseID = exerciseID
        self.currentWeight = currentWeight
        self.failStreak = failStreak
    }

    var exercise: Exercise? { Exercise(rawValue: exerciseID) }
}

/// A completed (finished) workout.
@Model
final class WorkoutSession {
    var date: Date
    var typeRaw: String
    var bodyWeight: Double?
    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.session)
    var exercises: [LoggedExercise]

    init(date: Date, type: WorkoutType, bodyWeight: Double?) {
        self.date = date
        self.typeRaw = type.rawValue
        self.bodyWeight = bodyWeight
        self.exercises = []
    }

    var type: WorkoutType { WorkoutType(rawValue: typeRaw) ?? .a }

    /// Exercises in the day's canonical order.
    var orderedExercises: [LoggedExercise] {
        let order = type.slots.map(\.exercise.rawValue)
        return exercises.sorted { a, b in
            (order.firstIndex(of: a.exerciseID) ?? 0) < (order.firstIndex(of: b.exerciseID) ?? 0)
        }
    }
}

/// One exercise's result inside a session. `reps` empty ⇒ skipped; otherwise one entry per set.
@Model
final class LoggedExercise {
    var exerciseID: String
    var weight: Double
    var reps: [Int]
    var targetSets: Int
    var targetReps: Int
    var session: WorkoutSession?

    init(exerciseID: String, weight: Double, reps: [Int], targetSets: Int, targetReps: Int) {
        self.exerciseID = exerciseID
        self.weight = weight
        self.reps = reps
        self.targetSets = targetSets
        self.targetReps = targetReps
    }

    var exercise: Exercise? { Exercise(rawValue: exerciseID) }

    var isSkipped: Bool { reps.isEmpty }

    /// Every set reached the target rep count.
    var isSuccess: Bool {
        !reps.isEmpty && reps.count == targetSets && reps.allSatisfy { $0 == targetReps }
    }
}
