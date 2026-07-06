import Foundation

extension LoggedExercise {
    /// Right-hand result text on the History screen.
    /// - Skipped           → "Skipped"
    /// - all sets full      → "5×5 245lb"  (or "5×265lb" for a single-set lift)
    /// - partial            → "5/5/5/4/5 185lb"
    func resultText(_ unit: WeightUnit) -> String {
        if isSkipped { return "Skipped" }
        let w = WeightFormat.string(weight, unit)
        if isSuccess {
            return targetSets == 1
                ? "\(targetReps)×\(w)"
                : "\(targetSets)×\(targetReps) \(w)"
        }
        let detail = reps.map(String.init).joined(separator: "/")
        return "\(detail) \(w)"
    }
}
