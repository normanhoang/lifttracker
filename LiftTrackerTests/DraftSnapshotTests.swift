import XCTest
@testable import LiftTracker

final class DraftSnapshotTests: XCTestCase {

    private func snapshot(sets: Int = 5, rest: Int = 90) -> DraftSnapshot {
        DraftSnapshot(
            typeRaw: "A",
            title: "Workout A",
            lifts: [
                lift("squat", sets: sets, rest: rest),
                lift("bench", sets: sets, rest: rest),
            ]
        )
    }

    private func lift(_ id: String, sets: Int, rest: Int) -> DraftLift {
        DraftLift(exerciseID: id, name: id.capitalized, weightLb: 100, targetReps: 5,
                  reps: Array(repeating: nil, count: sets), skipped: false, restSeconds: rest)
    }

    // MARK: - Logging

    func testTapLogsTargetAndStartsRest() {
        var s = snapshot()
        let started = s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        XCTAssertTrue(started, "first log of a set kicks the rest timer")
        XCTAssertEqual(s.lifts[0].reps[0], 5)
        XCTAssertNotNil(s.restEndDate)
        XCTAssertEqual(s.restSetIndex, 1, "ring advances to the next set")
    }

    func testCorrectingALoggedSetDoesNotRestartRest() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        let end = s.restEndDate
        let started = s.log(exerciseID: "squat", setIndex: 0, reps: 3)
        XCTAssertFalse(started)
        XCTAssertEqual(s.lifts[0].reps[0], 3)
        XCTAssertEqual(s.restEndDate, end, "a correction is not a new set")
    }

    func testClearingASetStopsRest() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        s.log(exerciseID: "squat", setIndex: 0, reps: nil)
        XCTAssertNil(s.lifts[0].reps[0])
        XCTAssertNil(s.restEndDate)
    }

    func testZeroRepsIsALoggedSetNotAnEmptyOne() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 0)
        XCTAssertEqual(s.lifts[0].reps[0], 0)
        XCTAssertEqual(s.loggedSetCount, 1)
        XCTAssertTrue(s.hasProgress)
    }

    func testRestOffNeverStartsACountdown() {
        var s = snapshot(rest: 0)
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        XCTAssertNil(s.restEndDate, "rest off for this lift")
    }

    func testRestPointsAtNextLiftWhenTheCurrentOneFinishes() {
        var s = snapshot(sets: 2)
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        s.log(exerciseID: "squat", setIndex: 1, reps: 5)
        XCTAssertEqual(s.restLiftID, "bench")
        XCTAssertEqual(s.restSetIndex, 0)
    }

    // MARK: - Undo

    func testUndoClearsTheLastLoggedSetAndStopsRest() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        s.log(exerciseID: "squat", setIndex: 1, reps: 4)
        s.undoLastSet()
        XCTAssertEqual(s.lifts[0].reps[0], 5)
        XCTAssertNil(s.lifts[0].reps[1])
        XCTAssertNil(s.restEndDate)
    }

    func testUndoOnAnUntouchedDraftIsSafe() {
        var s = snapshot()
        s.undoLastSet()
        XCTAssertEqual(s.loggedSetCount, 0)
    }

    // MARK: - Session clock

    func testUndoingTheOnlyLoggedSetClearsTheSessionStart() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        XCTAssertNotNil(s.startedAt)

        s.undoLastSet()
        XCTAssertNil(s.startedAt, "a mis-tap you took back never started the session")
    }

    func testClearingTheOnlySetFromThePickerClearsTheSessionStart() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        s.log(exerciseID: "squat", setIndex: 0, reps: nil)
        XCTAssertNil(s.startedAt, "clearing and undoing leave the same state")
    }

    func testUndoingOneOfSeveralSetsKeepsTheSessionRunning() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        s.log(exerciseID: "squat", setIndex: 1, reps: 5)
        let started = s.startedAt

        s.undoLastSet()
        XCTAssertEqual(s.startedAt, started, "the session is still underway")
    }

    func testLoggingAgainAfterAFullUndoRestartsTheClock() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        s.undoLastSet()

        let later = Date().addingTimeInterval(600)
        s.log(exerciseID: "squat", setIndex: 0, reps: 5, at: later)
        XCTAssertEqual(s.startedAt, later, "duration runs from the real first set")
    }

    // MARK: - Skip

    func testSkipCompletesTheLiftWithoutLoggingSets() {
        var s = snapshot()
        s.skip(exerciseID: "squat")
        XCTAssertTrue(s.lifts[0].isComplete)
        XCTAssertTrue(s.lifts[0].skipped)
        XCTAssertEqual(s.loggedSetCount, 0)
        XCTAssertTrue(s.hasProgress, "a deliberate skip is something to lose")
        XCTAssertEqual(s.activeLiftIndex, 1, "focus moves to the next lift")
    }

    func testSkipClearsAnyRepsAlreadyLogged() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        s.skip(exerciseID: "squat")
        XCTAssertEqual(s.lifts[0].reps.compactMap { $0 }, [])
    }

    // MARK: - Finish gate

    func testFinishableOnlyWhenEveryLiftIsComplete() {
        var s = snapshot(sets: 1)
        XCTAssertFalse(s.isFinishable)
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        XCTAssertFalse(s.isFinishable, "bench still outstanding")
        s.log(exerciseID: "bench", setIndex: 0, reps: 3)
        XCTAssertTrue(s.isFinishable)
    }

    func testAllSkippedIsNotFinishable() {
        var s = snapshot()
        s.skip(exerciseID: "squat")
        s.skip(exerciseID: "bench")
        XCTAssertFalse(s.isFinishable, "a session with nothing logged is not a session")
    }

    func testRemainingSetsText() {
        var s = snapshot(sets: 2)
        XCTAssertEqual(s.remainingSetsText, "Log a set to finish")
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        XCTAssertEqual(s.remainingSetsText, "3 sets to go")
        s.log(exerciseID: "squat", setIndex: 1, reps: 5)
        s.log(exerciseID: "bench", setIndex: 0, reps: 5)
        XCTAssertEqual(s.remainingSetsText, "1 set to go")
    }

    func testSkippedLiftDoesNotCountTowardRemaining() {
        var s = snapshot(sets: 2)
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        s.skip(exerciseID: "bench")
        XCTAssertEqual(s.remainingSetsText, "1 set to go")
    }

    // MARK: - Rest controls

    func testAddRestExtendsBothEndAndTarget() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        let end = s.restEndDate!
        s.addRest(30)
        XCTAssertEqual(s.restTargetSeconds, 120)
        XCTAssertEqual(s.restEndDate!.timeIntervalSince(end), 30, accuracy: 0.01)
    }

    func testLogRingedSetLogsTheSetTheStripPointsAt() {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 5)
        XCTAssertTrue(s.logRingedSet())
        XCTAssertEqual(s.lifts[0].reps[1], 5)
    }

    func testLogRingedSetIsANoOpWhenNothingIsResting() {
        var s = snapshot()
        XCTAssertFalse(s.logRingedSet())
        XCTAssertEqual(s.loggedSetCount, 0)
    }

    // MARK: - Round trip

    func testCodableRoundTrip() throws {
        var s = snapshot()
        s.log(exerciseID: "squat", setIndex: 0, reps: 4)
        s.skip(exerciseID: "bench")
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(DraftSnapshot.self, from: data)
        XCTAssertEqual(back, s)
    }
}

final class DraftStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "DraftStoreTests")!
        defaults.removePersistentDomain(forName: "DraftStoreTests")
    }

    private func snapshot(savedAt: Date, logged: Bool) -> DraftSnapshot {
        var s = DraftSnapshot(
            typeRaw: "A", title: "Workout A",
            lifts: [DraftLift(exerciseID: "squat", name: "Squat", weightLb: 100, targetReps: 5,
                              reps: [nil, nil], skipped: false, restSeconds: 90)],
            savedAt: savedAt
        )
        if logged { s.log(exerciseID: "squat", setIndex: 0, reps: 5) }
        s.savedAt = savedAt
        return s
    }

    func testSaveLoadRoundTrip() {
        let s = snapshot(savedAt: .now, logged: true)
        DraftStore.save(s, to: defaults)
        let back = DraftStore.load(from: defaults)
        XCTAssertEqual(back?.loggedSetCount, 1)
    }

    func testClear() {
        DraftStore.save(snapshot(savedAt: .now, logged: true), to: defaults)
        DraftStore.clear(from: defaults)
        XCTAssertNil(DraftStore.load(from: defaults))
    }

    func testResumableOnlySameDay() {
        let today = snapshot(savedAt: .now, logged: true)
        XCTAssertTrue(DraftStore.isResumable(today))

        let yesterday = snapshot(savedAt: Date().addingTimeInterval(-60 * 60 * 24), logged: true)
        XCTAssertFalse(DraftStore.isResumable(yesterday),
                       "a stale draft would stamp today's date on last session's lifts")
    }

    func testEmptyDraftIsNotWorthResuming() {
        XCTAssertFalse(DraftStore.isResumable(snapshot(savedAt: .now, logged: false)))
    }
}
