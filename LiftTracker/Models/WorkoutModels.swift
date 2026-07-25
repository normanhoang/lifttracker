import Foundation
import SwiftData

/// Persisted per-lift state: the working weight, the fail streak, and the two
/// knobs the lift editor exposes (rest and increment).
@Model
final class ExerciseProgress {
    @Attribute(.unique) var exerciseID: String
    var currentWeight: Double
    var failStreak: Int
    /// All-time heaviest non-skipped logged weight for this lift. 0 = never logged.
    var bestWeight: Double = 0
    /// Rest between sets, in seconds. 0 = rest off for this lift.
    var restSeconds: Int = 90
    /// Overrides the lift's default increment when set.
    var incrementOverride: Double? = nil
    /// Consecutive clean sessions. Only used for copy ("3rd session climbing").
    var successStreak: Int = 0

    init(exerciseID: String, currentWeight: Double, failStreak: Int = 0) {
        self.exerciseID = exerciseID
        self.currentWeight = currentWeight
        self.failStreak = failStreak
    }

    var exercise: Exercise? { Exercise(rawValue: exerciseID) }

    /// Weight added after a clean session: the user's override, else the lift's default.
    func increment(for ex: Exercise) -> Double { incrementOverride ?? ex.increment }
}

/// A completed (finished) workout.
@Model
final class WorkoutSession {
    var date: Date
    var typeRaw: String
    /// Wall-clock length of the session. Computed at finish and kept, so History
    /// can show it instead of recomputing something it no longer has the data for.
    var durationSeconds: Double = 0
    /// Total weight moved (reps × weight), in pounds.
    var volumeLb: Double = 0
    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.session)
    var exercises: [LoggedExercise]

    init(date: Date, type: WorkoutType) {
        self.date = date
        self.typeRaw = type.rawValue
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

    /// A session with at least one lift short of target — drives the amber
    /// calendar cell.
    var hasMiss: Bool {
        exercises.contains { !$0.isSkipped && !$0.isSuccess } || exercises.contains(where: \.isSkipped)
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
    /// Set at write time when this beat the lift's previous best — History and
    /// the complete screen both badge it.
    var isPR: Bool = false
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

    var totalReps: Int { reps.reduce(0, +) }

    var targetTotalReps: Int { targetSets * targetReps }

    var volumeLb: Double { Double(totalReps) * weight }
}

/// A weigh-in. Its own record so body weight can be logged on a rest day
/// instead of only alongside a workout.
@Model
final class BodyWeightEntry {
    var date: Date
    var weightLb: Double

    init(date: Date, weightLb: Double) {
        self.date = date
        self.weightLb = weightLb
    }
}
