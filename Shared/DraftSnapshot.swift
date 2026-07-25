import Foundation

/// One lift inside an in-progress workout. `reps[i] == nil` means that set has
/// not been logged yet; a value is the reps actually achieved (0...target).
struct DraftLift: Codable, Equatable, Identifiable {
    var exerciseID: String
    var name: String
    var weightLb: Double
    var targetReps: Int
    var reps: [Int?]
    var skipped: Bool
    var restSeconds: Int

    var id: String { exerciseID }

    /// A lift is done when it was skipped or every set carries a value.
    var isComplete: Bool { skipped || reps.allSatisfy { $0 != nil } }

    var loggedCount: Int { reps.compactMap { $0 }.count }

    /// Index of the set the ring sits on, or nil when the lift is finished.
    var nextIndex: Int? { skipped ? nil : reps.firstIndex { $0 == nil } }

    /// Highest index that carries a value — what `Undo last set` clears.
    var lastLoggedIndex: Int? { reps.lastIndex { $0 != nil } }

    var isClean: Bool { !skipped && reps.allSatisfy { $0 == targetReps } }
}

/// The whole in-progress workout as a value. Persisted verbatim so a session
/// survives the process dying mid-workout, and so a Live Activity App Intent
/// can mutate the same state the app is showing.
struct DraftSnapshot: Codable, Equatable {
    var typeRaw: String
    var title: String
    var lifts: [DraftLift]
    var bodyWeightLb: Double?
    var startedAt: Date?
    var savedAt: Date

    // Rest state lives here so the strip, the Live Activity and the intents
    // all read one source of truth.
    var restEndDate: Date?
    var restTargetSeconds: Int = 0
    var restLiftID: String?
    var restSetIndex: Int?

    init(typeRaw: String, title: String, lifts: [DraftLift],
         bodyWeightLb: Double? = nil, startedAt: Date? = nil, savedAt: Date = .now) {
        self.typeRaw = typeRaw
        self.title = title
        self.lifts = lifts
        self.bodyWeightLb = bodyWeightLb
        self.startedAt = startedAt
        self.savedAt = savedAt
    }
}

// MARK: - Derived state

extension DraftSnapshot {
    var loggedSetCount: Int { lifts.reduce(0) { $0 + $1.loggedCount } }

    var totalSetCount: Int { lifts.reduce(0) { $0 + $1.reps.count } }

    /// At least one set logged or one lift skipped — i.e. there is something to lose.
    var hasProgress: Bool { loggedSetCount > 0 || lifts.contains(where: \.skipped) }

    /// The expanded lift: the first one that isn't finished.
    var activeLiftIndex: Int? { lifts.firstIndex { !$0.isComplete } }

    var isFinishable: Bool { !lifts.isEmpty && lifts.allSatisfy(\.isComplete) && loggedSetCount > 0 }

    /// Copy shown on the Finish button while sets are outstanding.
    var remainingSetsText: String {
        let remaining = totalSetCount - lifts.reduce(0) { sum, lift in
            sum + (lift.skipped ? lift.reps.count : lift.loggedCount)
        }
        if loggedSetCount == 0 { return "Log a set to finish" }
        return remaining == 1 ? "1 set to go" : "\(remaining) sets to go"
    }

    func lift(_ exerciseID: String) -> DraftLift? {
        lifts.first { $0.exerciseID == exerciseID }
    }
}

// MARK: - Mutations

extension DraftSnapshot {
    /// Log (or correct, or clear with `reps == nil`) one set.
    /// Returns true when this started rest — i.e. a set went from empty to logged.
    @discardableResult
    mutating func log(exerciseID: String, setIndex: Int, reps value: Int?, at now: Date = .now) -> Bool {
        guard let i = lifts.firstIndex(where: { $0.exerciseID == exerciseID }),
              lifts[i].reps.indices.contains(setIndex) else { return false }
        let wasEmpty = lifts[i].reps[setIndex] == nil
        lifts[i].reps[setIndex] = value
        lifts[i].skipped = false
        if startedAt == nil, value != nil { startedAt = now }

        guard wasEmpty, value != nil else {
            if value == nil {
                clearRest()
                clearStartIfEmpty()
            }
            return false
        }
        startRest(after: i, at: now)
        return true
    }

    /// Clear the most recently logged set of the active lift and stop resting.
    mutating func undoLastSet() {
        guard let i = activeLiftIndex ?? lifts.indices.last,
              let last = lifts[i].lastLoggedIndex else { return }
        lifts[i].reps[last] = nil
        clearRest()
        clearStartIfEmpty()
    }

    /// Undoing (or clearing) the last remaining set means the session never
    /// really started. Leaving the clock running would bank the time between a
    /// mis-tap and the real first set into the saved duration.
    private mutating func clearStartIfEmpty() {
        if loggedSetCount == 0 { startedAt = nil }
    }

    /// Mark a lift deliberately skipped: no sets, no progression change.
    mutating func skip(exerciseID: String) {
        guard let i = lifts.firstIndex(where: { $0.exerciseID == exerciseID }) else { return }
        lifts[i].skipped = true
        lifts[i].reps = Array(repeating: nil, count: lifts[i].reps.count)
        if restLiftID == exerciseID { clearRest() }
    }

    mutating func unskip(exerciseID: String) {
        guard let i = lifts.firstIndex(where: { $0.exerciseID == exerciseID }) else { return }
        lifts[i].skipped = false
    }

    mutating func setWeight(exerciseID: String, lb: Double) {
        guard let i = lifts.firstIndex(where: { $0.exerciseID == exerciseID }) else { return }
        lifts[i].weightLb = lb
    }

    /// Start the countdown for whatever comes after the set just logged.
    /// `restSeconds == 0` means the user turned rest off for this lift.
    mutating func startRest(after liftIndex: Int, at now: Date = .now) {
        let seconds = lifts[liftIndex].restSeconds
        guard seconds > 0 else { clearRest(); return }

        // The set the user comes back to: the next one on this lift, else the
        // first set of the next unfinished lift.
        if let next = lifts[liftIndex].nextIndex {
            restLiftID = lifts[liftIndex].exerciseID
            restSetIndex = next
        } else if let nextLift = lifts.dropFirst(liftIndex + 1).firstIndex(where: { !$0.isComplete }) {
            restLiftID = lifts[nextLift].exerciseID
            restSetIndex = lifts[nextLift].nextIndex ?? 0
        } else {
            clearRest()
            return
        }
        restTargetSeconds = seconds
        restEndDate = now.addingTimeInterval(TimeInterval(seconds))
    }

    mutating func addRest(_ seconds: Int) {
        guard let end = restEndDate else { return }
        restEndDate = end.addingTimeInterval(TimeInterval(seconds))
        restTargetSeconds += seconds
    }

    mutating func clearRest() {
        restEndDate = nil
        restTargetSeconds = 0
        restLiftID = nil
        restSetIndex = nil
    }

    /// Log the set the rest strip is pointing at, at target reps. Drives the
    /// Live Activity's "Log set n" button.
    @discardableResult
    mutating func logRingedSet(at now: Date = .now) -> Bool {
        guard let id = restLiftID, let index = restSetIndex,
              let lift = lift(id) else { return false }
        return log(exerciseID: id, setIndex: index, reps: lift.targetReps, at: now)
    }
}
