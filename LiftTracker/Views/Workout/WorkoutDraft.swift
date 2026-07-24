import Foundation
import Combine

/// The workout being logged. A thin observable shell over `DraftSnapshot` — the
/// value type holds the rules so the same mutations run from the Live Activity's
/// App Intents, which execute outside any view.
@MainActor
final class WorkoutDraft: ObservableObject {
    @Published private(set) var snapshot: DraftSnapshot

    init() {
        snapshot = DraftSnapshot(typeRaw: WorkoutType.a.rawValue,
                                 title: WorkoutType.a.title,
                                 lifts: [])
    }

    // MARK: - Building

    /// Rebuild for a fresh workout of the given type.
    func reset(type: WorkoutType,
               weights: [String: Double],
               rest: [String: Int] = [:],
               bodyWeight: Double? = nil) {
        snapshot = Self.blank(type: type, weights: weights, rest: rest, bodyWeight: bodyWeight)
        persist()
    }

    /// User switched A/B; keep weights, reset the grid.
    func changeType(_ t: WorkoutType) {
        var weights: [String: Double] = [:]
        var rest: [String: Int] = [:]
        for lift in snapshot.lifts {
            weights[lift.exerciseID] = lift.weightLb
            rest[lift.exerciseID] = lift.restSeconds
        }
        // Lifts only on the other day keep whatever they were seeded with.
        reset(type: t, weights: weights, rest: rest, bodyWeight: snapshot.bodyWeightLb)
    }

    private static func blank(type: WorkoutType,
                              weights: [String: Double],
                              rest: [String: Int],
                              bodyWeight: Double?) -> DraftSnapshot {
        let lifts = type.slots.map { slot in
            DraftLift(exerciseID: slot.exercise.rawValue,
                      name: slot.exercise.name,
                      weightLb: weights[slot.exercise.rawValue] ?? slot.exercise.startingWeight,
                      targetReps: Exercise.targetReps,
                      reps: Array(repeating: nil, count: slot.sets),
                      skipped: false,
                      restSeconds: rest[slot.exercise.rawValue] ?? slot.exercise.defaultRestSeconds)
        }
        var snap = DraftSnapshot(typeRaw: type.rawValue, title: type.title, lifts: lifts)
        snap.bodyWeightLb = bodyWeight
        return snap
    }

    // MARK: - Reading

    var type: WorkoutType { WorkoutType(rawValue: snapshot.typeRaw) ?? .a }
    var lifts: [DraftLift] { snapshot.lifts }
    var hasProgress: Bool { snapshot.hasProgress }
    var loggedSetCount: Int { snapshot.loggedSetCount }
    var isFinishable: Bool { snapshot.isFinishable }
    var activeLiftIndex: Int? { snapshot.activeLiftIndex }
    var startedAt: Date? { snapshot.startedAt }

    var bodyWeight: Double? {
        get { snapshot.bodyWeightLb }
        set { snapshot.bodyWeightLb = newValue; persist() }
    }

    func states(_ ex: Exercise) -> [Int?] { snapshot.lift(ex.rawValue)?.reps ?? [] }

    func weight(_ ex: Exercise) -> Double { snapshot.lift(ex.rawValue)?.weightLb ?? 0 }

    func isSkipped(_ ex: Exercise) -> Bool { snapshot.lift(ex.rawValue)?.skipped ?? false }

    // MARK: - Mutating

    func setWeight(_ ex: Exercise, _ lb: Double) {
        snapshot.setWeight(exerciseID: ex.rawValue, lb: lb)
        persist()
    }

    func setRest(_ ex: Exercise, _ seconds: Int) {
        guard let i = snapshot.lifts.firstIndex(where: { $0.exerciseID == ex.rawValue }) else { return }
        snapshot.lifts[i].restSeconds = seconds
        persist()
    }

    /// Tap: log the target rep count. Returns true when rest should start.
    @discardableResult
    func tapSet(_ ex: Exercise, _ index: Int) -> Bool {
        log(ex, index, reps: Exercise.targetReps)
    }

    /// Hold / picker: log an explicit rep count, or nil to clear the set.
    @discardableResult
    func log(_ ex: Exercise, _ index: Int, reps: Int?) -> Bool {
        let started = snapshot.log(exerciseID: ex.rawValue, setIndex: index, reps: reps)
        persist()
        return started
    }

    func undoLastSet() {
        snapshot.undoLastSet()
        persist()
    }

    func skip(_ ex: Exercise) {
        snapshot.skip(exerciseID: ex.rawValue)
        persist()
    }

    func unskip(_ ex: Exercise) {
        snapshot.unskip(exerciseID: ex.rawValue)
        persist()
    }

    // MARK: - Rest

    func addRest(_ seconds: Int) {
        snapshot.addRest(seconds)
        persist()
    }

    func skipRest() {
        snapshot.clearRest()
        persist()
    }

    // MARK: - Persistence

    func persist() { DraftStore.save(snapshot) }

    func clearPersisted() { DraftStore.clear() }

    /// Adopt a snapshot mutated elsewhere — a Live Activity button, or a resume
    /// on launch.
    func adopt(_ snapshot: DraftSnapshot) { self.snapshot = snapshot }

    /// Re-read the store after an App Intent mutated it.
    func reloadFromStore() {
        guard let stored = DraftStore.load(), stored.typeRaw == snapshot.typeRaw else { return }
        snapshot = stored
    }

    // MARK: - Finishing

    /// Build a persistable session from the current draft (does not insert it).
    func buildSession(date: Date = .now, duration: TimeInterval) -> WorkoutSession {
        let session = WorkoutSession(date: date, type: type)
        for lift in snapshot.lifts {
            let reps: [Int] = lift.skipped ? [] : lift.reps.map { $0 ?? 0 }
            let logged = LoggedExercise(
                exerciseID: lift.exerciseID,
                weight: lift.weightLb,
                reps: reps,
                targetSets: lift.reps.count,
                targetReps: lift.targetReps
            )
            logged.session = session
            session.exercises.append(logged)
        }
        session.durationSeconds = duration
        session.volumeLb = session.exercises.reduce(0) { $0 + $1.volumeLb }
        return session
    }
}
