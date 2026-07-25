import Foundation

/// Lifting 5×5 auto-progression rules.
///
/// The rules themselves are unchanged; what's new is that `apply` reports what
/// it did. The complete screen, the workout card and Settings all state the
/// progression to the user, and none of them can do that from the resulting
/// weight alone.
enum Progression {
    static func round5(_ x: Double) -> Double { (x / 5).rounded() * 5 }

    /// What happened to one lift.
    enum Outcome: Equatable {
        case increased(from: Double, to: Double, streak: Int)
        /// Missed, but not the third in a row. `misses` is the streak so far.
        case held(weight: Double, misses: Int)
        case deloaded(from: Double, to: Double)
        case skipped
    }

    struct Change: Identifiable, Equatable {
        let exerciseID: String
        let outcome: Outcome
        var id: String { exerciseID }

        var exercise: Exercise? { Exercise(rawValue: exerciseID) }
    }

    /// Apply progression for a just-finished session, mutating each exercise's
    /// `ExerciseProgress` and reporting the outcome per lift.
    /// - success   → weight += increment, streaks updated
    /// - failure   → streak += 1; on the 3rd straight failure, deload −10% (rounded to 5) and reset
    /// - skipped   → no change
    @discardableResult
    static func apply(session: WorkoutSession,
                      progressFor: (String) -> ExerciseProgress) -> [Change] {
        session.orderedExercises.compactMap { logged -> Change? in
            guard let ex = logged.exercise else { return nil }
            guard !logged.isSkipped else {
                return Change(exerciseID: logged.exerciseID, outcome: .skipped)
            }
            let prog = progressFor(logged.exerciseID)
            let before = prog.currentWeight

            if logged.isSuccess {
                prog.currentWeight += prog.increment(for: ex)
                prog.failStreak = 0
                prog.successStreak += 1
                return Change(exerciseID: logged.exerciseID,
                              outcome: .increased(from: before, to: prog.currentWeight,
                                                  streak: prog.successStreak))
            }

            prog.successStreak = 0
            prog.failStreak += 1
            if prog.failStreak >= 3 {
                prog.currentWeight = deload(before)
                prog.failStreak = 0
                return Change(exerciseID: logged.exerciseID,
                              outcome: .deloaded(from: before, to: prog.currentWeight))
            }
            return Change(exerciseID: logged.exerciseID,
                          outcome: .held(weight: before, misses: prog.failStreak))
        }
    }

    /// −10%, rounded to 5, never under 5.
    static func deload(_ weight: Double) -> Double {
        max(5, round5(weight * 0.9))
    }

    // MARK: - Preview
    //
    // Settings and the workout card state what the *next* session will do, so
    // the rule has to be readable without running it.

    /// Weight this lift moves to after a clean session.
    static func nextWeight(_ prog: ExerciseProgress, _ ex: Exercise) -> Double {
        prog.currentWeight + prog.increment(for: ex)
    }

    /// Weight this lift drops to if the streak reaches three.
    static func deloadWeight(_ prog: ExerciseProgress) -> Double {
        deload(prog.currentWeight)
    }
}
