import Foundation

/// One lift's logged history, reduced to the handful of numbers the Progress
/// screen and the lift detail screen both need. Pure so it can be tested
/// without a store.
struct LiftSeries {
    struct Point: Equatable {
        let date: Date
        let weightLb: Double
        let missed: Bool
    }

    let points: [Point]

    init(points: [Point]) {
        self.points = points
    }

    /// Newest last.
    init(exerciseID: String, sessions: [WorkoutSession]) {
        points = sessions
            .sorted { $0.date < $1.date }
            .compactMap { session in
                guard let logged = session.exercises.first(where: { $0.exerciseID == exerciseID }),
                      !logged.isSkipped else { return nil }
                return Point(date: session.date, weightLb: logged.weight, missed: !logged.isSuccess)
            }
    }

    var isEmpty: Bool { points.isEmpty }

    var current: Double? { points.last?.weightLb }

    var best: Double? { points.map(\.weightLb).max() }

    var missCount: Int { points.filter(\.missed).count }

    /// A drop from one logged session to the next is a deload.
    var deloadCount: Int {
        zip(points, points.dropFirst()).filter { $1.weightLb < $0.weightLb }.count
    }

    /// Gain from the first logged session to the last.
    var delta: Double {
        guard let first = points.first?.weightLb, let last = points.last?.weightLb else { return 0 }
        return last - first
    }

    /// Whole weeks spanned, at least 1 once anything is logged.
    func weeks(calendar: Calendar = .current) -> Int {
        guard let first = points.first?.date, let last = points.last?.date else { return 0 }
        let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
        return max(1, Int((Double(days) / 7).rounded(.up)))
    }

    /// Weeks since the weight last changed — "flat · 4wk".
    func flatWeeks(calendar: Calendar = .current, now: Date = .now) -> Int? {
        guard let last = points.last else { return nil }
        var since = last.date
        for point in points.reversed() {
            if point.weightLb != last.weightLb { break }
            since = point.date
        }
        let days = calendar.dateComponents([.day], from: since, to: now).day ?? 0
        return max(0, Int((Double(days) / 7).rounded()))
    }

    /// Trimmed to a trailing window.
    func windowed(_ months: Int?, now: Date = .now, calendar: Calendar = .current) -> LiftSeries {
        guard let months, let cutoff = calendar.date(byAdding: .month, value: -months, to: now) else {
            return self
        }
        return LiftSeries(points: points.filter { $0.date >= cutoff })
    }

    /// State line on the Progress row.
    func state(failStreak: Int, hitBestToday: Bool, unit: WeightUnit) -> ProgressionCopy.Note {
        if hitBestToday { return .init(text: "New best today", tone: .up) }
        if failStreak > 0 {
            return .init(text: "Stalled · \(failStreak) \(failStreak == 1 ? "miss" : "misses")", tone: .warn)
        }
        if deloadCount > 0, points.suffix(3).contains(where: \.missed) {
            let n = deloadCount == 1 ? "once" : deloadCount == 2 ? "twice" : "\(deloadCount) times"
            return .init(text: "Deloaded \(n)", tone: .neutral)
        }
        if let best {
            return .init(text: "Climbing · best \(ProgressionCopy.plain(best, unit))", tone: .up)
        }
        return .init(text: "Not logged yet", tone: .neutral)
    }
}
