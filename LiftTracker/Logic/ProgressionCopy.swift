import Foundation

/// Every sentence the app uses to state the progression rule. Kept pure and in
/// one place because the same rule has to be said four different ways — on the
/// workout card, on the complete screen, in Progress and in Settings — and the
/// app currently says it nowhere.
enum ProgressionCopy {
    enum Tone { case up, warn, neutral }

    struct Note: Equatable {
        let text: String
        let tone: Tone
    }

    // MARK: - Workout card

    /// "+5lb from Monday · 3rd session climbing" / "−10% after 3 misses" / "Holding at 95lb".
    static func liftNote(increment: Double,
                         successStreak: Int,
                         failStreak: Int,
                         currentWeight: Double,
                         deloadedLastSession: Bool,
                         lastDate: Date?,
                         unit: WeightUnit,
                         now: Date = .now,
                         calendar: Calendar = .current) -> Note {
        if deloadedLastSession {
            return Note(text: "−10% after 3 misses", tone: .warn)
        }
        if failStreak > 0 {
            let noun = failStreak == 1 ? "miss" : "misses"
            return Note(text: "\(failStreak) \(noun) · deloads after 3", tone: .warn)
        }
        if successStreak > 0 {
            let when = relativeDay(lastDate, now: now, calendar: calendar)
            let climbing = "\(ordinal(successStreak + 1)) session climbing"
            let gain = "+\(WeightFormat.string(increment, unit))"
            return Note(text: when.isEmpty ? "\(gain) · \(climbing)" : "\(gain) from \(when) · \(climbing)",
                        tone: .up)
        }
        return Note(text: "Holding at \(WeightFormat.string(currentWeight, unit))", tone: .neutral)
    }

    // MARK: - Settings row

    /// "190 next session", "2 misses · deloads to 140 on the next", "holding at 95".
    static func settingsState(currentWeight: Double,
                              nextWeight: Double,
                              deloadWeight: Double,
                              failStreak: Int,
                              hasLogged: Bool,
                              incrementOverride: Double?,
                              unit: WeightUnit) -> Note {
        if failStreak > 0 {
            let noun = failStreak == 1 ? "miss" : "misses"
            return Note(text: "\(failStreak) \(noun) · deloads to \(plain(deloadWeight, unit)) on the next",
                        tone: .warn)
        }
        guard hasLogged else {
            return Note(text: "not logged yet", tone: .neutral)
        }
        var text = "\(plain(nextWeight, unit)) next session"
        if let step = incrementOverride {
            text += " · +\(WeightFormat.string(step, unit)) steps"
        }
        return Note(text: text, tone: .up)
    }

    // MARK: - Complete screen

    /// Title of a NEXT SESSION row: "Squat 185 → 190" / "Overhead Press stays at 95".
    static func changeTitle(_ change: Progression.Change, name: String, unit: WeightUnit) -> String {
        switch change.outcome {
        case .increased(let from, let to, _):
            return "\(name) \(plain(from, unit)) → \(plain(to, unit))"
        case .deloaded(let from, let to):
            return "\(name) \(plain(from, unit)) → \(plain(to, unit))"
        case .held(let weight, _):
            return "\(name) stays at \(plain(weight, unit))"
        case .skipped:
            return "\(name) skipped"
        }
    }

    /// Reason line under it.
    static func changeReason(_ change: Progression.Change,
                             logged: LoggedExercise?,
                             deloadWeight: Double,
                             increment: Double,
                             unit: WeightUnit) -> String {
        switch change.outcome {
        case .increased(_, _, let streak):
            let clean = logged.map { "Clean \($0.targetSets)×\($0.targetReps)." } ?? "Clean session."
            if streak <= 1 { return "\(clean) +\(WeightFormat.string(increment, unit)) next time." }
            return "\(clean) \(ordinal(streak)) straight increase."
        case .held(_, let misses):
            let reps = logged.map { "\($0.totalReps) of \($0.targetTotalReps) reps." } ?? "Short of target."
            let left = 3 - misses
            let more = left == 1 ? "One more miss deloads" : "\(spell(left)) more misses deload"
            return "\(reps) \(more) to \(plain(deloadWeight, unit))."
        case .deloaded:
            return "Three misses. Build back up — this is the program working."
        case .skipped:
            return "Skipped. Weight unchanged."
        }
    }

    /// Headline generated from the whole session's outcomes.
    static func headline(_ changes: [Progression.Change], nameFor: (String) -> String) -> String {
        let up = changes.filter { if case .increased = $0.outcome { return true }; return false }
        let down = changes.filter { if case .deloaded = $0.outcome { return true }; return false }

        if up.count == changes.count, up.count > 1 {
            return "Everything goes up."
        }
        if up.count == 1, down.isEmpty {
            return "\(nameFor(up[0].exerciseID)) goes up."
        }
        if up.count == 2 {
            let names = up.map { nameFor($0.exerciseID).lowercased() }
            return "\(nameFor(up[0].exerciseID)) and \(names[1]) both go up."
        }
        if up.count > 2 {
            return "\(spell(up.count).capitalized) lifts go up."
        }
        if let first = down.first {
            return "\(nameFor(first.exerciseID)) deloads."
        }
        if changes.allSatisfy({ $0.outcome == .skipped }) {
            return "Session logged."
        }
        return "Weights hold this session."
    }

    // MARK: - Helpers

    static func ordinal(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// Weight without a unit suffix — used where the unit is already stated
    /// nearby ("185 → 190").
    static func plain(_ lb: Double, _ unit: WeightUnit) -> String {
        let v = WeightFormat.fromLb(lb, unit)
        return v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }

    private static func spell(_ n: Int) -> String {
        ["zero", "one", "two", "three", "four", "five"].indices.contains(n) ? ["zero", "one", "two", "three", "four", "five"][n] : "\(n)"
    }

    /// "Monday" when it was inside the last week, else "" so the caller drops the clause.
    private static func relativeDay(_ date: Date?, now: Date, calendar: Calendar) -> String {
        guard let date else { return "" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        guard days >= 0, days < 7 else { return "" }
        if days == 0 { return "earlier today" }
        if days == 1 { return "yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }
}
