import Foundation

/// StrongLifts 5×5 auto-progression rules.
enum Progression {
    static func round5(_ x: Double) -> Double { (x / 5).rounded() * 5 }

    /// Apply progression for a just-finished session, mutating each exercise's `ExerciseProgress`.
    /// - success   → weight += increment, streak reset
    /// - failure   → streak += 1; on the 3rd straight failure, deload −10% (rounded to 5) and reset
    /// - skipped   → no change
    static func apply(session: WorkoutSession, progressFor: (String) -> ExerciseProgress) {
        for logged in session.exercises {
            guard let ex = logged.exercise, !logged.isSkipped else { continue }
            let prog = progressFor(logged.exerciseID)
            if logged.isSuccess {
                prog.currentWeight += ex.increment
                prog.failStreak = 0
            } else {
                prog.failStreak += 1
                if prog.failStreak >= 3 {
                    prog.currentWeight = max(5, round5(prog.currentWeight * 0.9))
                    prog.failStreak = 0
                }
            }
        }
    }
}
