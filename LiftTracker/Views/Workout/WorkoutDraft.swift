import Foundation

/// State of a single rep circle during a workout.
enum SetState: Equatable {
    case notStarted     // unhighlighted, shows 5
    case done(Int)      // highlighted, shows 0...5

    var display: Int {
        switch self {
        case .notStarted: return 5
        case .done(let n): return n
        }
    }

    var highlighted: Bool {
        if case .done = self { return true }
        return false
    }

    /// Tap cycle: notStarted → done(5) → done(4) … done(0) → notStarted.
    mutating func tap() {
        switch self {
        case .notStarted:
            self = .done(5)
        case .done(let n):
            self = n == 0 ? .notStarted : .done(n - 1)
        }
    }
}

/// In-memory state of the workout currently being logged.
@MainActor
final class WorkoutDraft: ObservableObject {
    @Published var type: WorkoutType = .a
    @Published var sets: [String: [SetState]] = [:]   // keyed by exercise rawValue
    @Published var bodyWeight: Double?

    /// Working weight (lb) per exercise, loaded from ExerciseProgress.
    @Published private(set) var weights: [String: Double] = [:]

    /// Rebuild for a fresh workout of the given type.
    func reset(type: WorkoutType, weights: [String: Double], bodyWeight: Double?) {
        self.type = type
        self.weights = weights
        self.bodyWeight = bodyWeight
        rebuildSets()
    }

    /// User switched A/B from the dropdown; keep weights, reset the grid.
    func changeType(_ t: WorkoutType) {
        type = t
        rebuildSets()
    }

    private func rebuildSets() {
        var grid: [String: [SetState]] = [:]
        for slot in type.slots {
            grid[slot.exercise.rawValue] = Array(repeating: .notStarted, count: slot.sets)
        }
        sets = grid
    }

    func states(_ ex: Exercise) -> [SetState] { sets[ex.rawValue] ?? [] }

    func weight(_ ex: Exercise) -> Double { weights[ex.rawValue] ?? 0 }

    func setWeight(_ ex: Exercise, _ lb: Double) { weights[ex.rawValue] = lb }

    /// Apply a tap. Returns true when this tap started a set (should kick the rest timer).
    func tap(_ ex: Exercise, _ index: Int) -> Bool {
        guard var arr = sets[ex.rawValue], arr.indices.contains(index) else { return false }
        let before = arr[index]
        arr[index].tap()
        sets[ex.rawValue] = arr
        if case .notStarted = before, arr[index].highlighted { return true }
        return false
    }

    /// True when at least one set of any exercise has been started.
    var hasProgress: Bool {
        sets.values.contains { states in states.contains { $0.highlighted } }
    }

    /// Build a persistable session from the current draft (does not insert it).
    func buildSession() -> WorkoutSession {
        let session = WorkoutSession(date: .now, type: type, bodyWeight: bodyWeight)
        for slot in type.slots {
            let states = sets[slot.exercise.rawValue] ?? []
            let attempted = states.contains { $0.highlighted }
            let reps: [Int] = attempted ? states.map { $0.highlighted ? $0.display : 0 } : []
            let logged = LoggedExercise(
                exerciseID: slot.exercise.rawValue,
                weight: weight(slot.exercise),
                reps: reps,
                targetSets: slot.sets,
                targetReps: Exercise.targetReps
            )
            logged.session = session
            session.exercises.append(logged)
        }
        return session
    }
}
