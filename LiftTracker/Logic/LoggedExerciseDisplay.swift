import Foundation

extension LoggedExercise {
    /// Right-hand result text on History, the complete screen and the day sheet.
    /// - Skipped      → "Skipped"
    /// - all sets full → "5×5 · 245lb"  (or "1×5 · 265lb" for a single-set lift)
    /// - partial       → "22/25 · 95lb" — total reps out of target, which is
    ///                    shorter than "5/5/5/4/3" and says the same thing. The
    ///                    per-set breakdown lives in the day sheet.
    func resultText(_ unit: WeightUnit) -> String {
        if isSkipped { return "Skipped" }
        let w = WeightFormat.string(weight, unit)
        if isSuccess { return "\(targetSets)×\(targetReps) · \(w)" }
        return "\(totalReps)/\(targetTotalReps) · \(w)"
    }
}
