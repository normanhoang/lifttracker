import XCTest
@testable import LiftTracker

@MainActor
final class WorkoutDraftTests: XCTestCase {

    private func draft(_ type: WorkoutType = .a,
                       weights: [String: Double] = [:],
                       rest: [String: Int] = [:]) -> WorkoutDraft {
        let d = WorkoutDraft()
        d.reset(type: type, weights: weights, rest: rest, bodyWeight: nil)
        return d
    }

    override func tearDown() {
        DraftStore.clear()
        super.tearDown()
    }

    func testResetBuildsGridPerSlot() {
        let d = draft(.a)
        XCTAssertEqual(d.states(.squat).count, 5)
        XCTAssertEqual(d.states(.bench).count, 5)
        XCTAssertEqual(d.states(.row).count, 5)
        XCTAssertTrue(d.states(.squat).allSatisfy { $0 == nil })
        XCTAssertTrue(d.states(.ohp).isEmpty, "OHP is not in workout A")
    }

    func testResetSeedsPerLiftRestDefaults() {
        let d = draft(.b)
        XCTAssertEqual(d.lifts.first { $0.exerciseID == "squat" }?.restSeconds, 180)
        XCTAssertEqual(d.lifts.first { $0.exerciseID == "ohp" }?.restSeconds, 90)
    }

    func testTapReturnsTrueOnlyWhenStartingASet() {
        let d = draft(.a)
        XCTAssertTrue(d.tapSet(.squat, 0), "first tap starts the set → kicks rest timer")
        XCTAssertFalse(d.tapSet(.squat, 0), "logging the same set again is a correction")
    }

    func testTapLogsTargetRepsNotACycle() {
        let d = draft(.a)
        d.tapSet(.squat, 0)
        d.tapSet(.squat, 0)
        d.tapSet(.squat, 0)
        XCTAssertEqual(d.states(.squat)[0], 5, "tapping never counts down")
    }

    func testTapOutOfRangeIsSafe() {
        let d = draft(.a)
        XCTAssertFalse(d.tapSet(.squat, 99))
        XCTAssertFalse(d.tapSet(.ohp, 0), "OHP absent from workout A")
    }

    func testHasProgressAndLoggedSetCount() {
        let d = draft(.a)
        XCTAssertFalse(d.hasProgress)
        XCTAssertEqual(d.loggedSetCount, 0)
        d.tapSet(.bench, 2)
        XCTAssertTrue(d.hasProgress)
        XCTAssertEqual(d.loggedSetCount, 1)
    }

    func testUndoLastSet() {
        let d = draft(.a)
        d.tapSet(.squat, 0)
        d.tapSet(.squat, 1)
        d.undoLastSet()
        XCTAssertEqual(d.loggedSetCount, 1)
        XCTAssertNil(d.states(.squat)[1])
    }

    func testChangeTypeResetsGridKeepsWeights() {
        let d = draft(.a, weights: [Exercise.squat.rawValue: 200])
        d.tapSet(.squat, 0)
        d.changeType(.b)
        XCTAssertEqual(d.states(.deadlift).count, 1)
        XCTAssertFalse(d.hasProgress, "grid reset on type change")
        XCTAssertEqual(d.weight(.squat), 200, "weights preserved")
    }

    func testBuildSessionFullSuccess() {
        let d = draft(.a, weights: [Exercise.squat.rawValue: 100])
        for i in 0..<5 { d.tapSet(.squat, i) }
        let session = d.buildSession(duration: 60)
        let squat = session.exercises.first { $0.exerciseID == Exercise.squat.rawValue }!
        XCTAssertEqual(squat.reps, [5, 5, 5, 5, 5])
        XCTAssertEqual(squat.weight, 100)
        XCTAssertTrue(squat.isSuccess)
        XCTAssertEqual(session.durationSeconds, 60)
        XCTAssertEqual(session.volumeLb, 2500, "25 reps × 100lb")
    }

    func testBuildSessionPartial() {
        let d = draft(.a)
        d.tapSet(.bench, 0)
        d.log(.bench, 1, reps: 4)
        let session = d.buildSession(duration: 0)
        let bench = session.exercises.first { $0.exerciseID == Exercise.bench.rawValue }!
        XCTAssertEqual(bench.reps, [5, 4, 0, 0, 0])
        XCTAssertFalse(bench.isSuccess)
        XCTAssertFalse(bench.isSkipped)
    }

    func testBuildSessionSkippedLiftHasEmptyReps() {
        let d = draft(.a)
        d.skip(.row)
        let session = d.buildSession(duration: 0)
        let row = session.exercises.first { $0.exerciseID == Exercise.row.rawValue }!
        XCTAssertTrue(row.reps.isEmpty)
        XCTAssertTrue(row.isSkipped)
    }

    /// An untouched lift is *not* a skip — the finish gate requires every lift
    /// to be complete, so this can only be reached by building a session by hand.
    func testUntouchedLiftBuildsAsZeros() {
        let d = draft(.a)
        d.tapSet(.squat, 0)
        let session = d.buildSession(duration: 0)
        let row = session.exercises.first { $0.exerciseID == Exercise.row.rawValue }!
        XCTAssertEqual(row.reps, [0, 0, 0, 0, 0])
        XCTAssertFalse(row.isSkipped)
    }

    func testEveryMutationPersists() {
        let d = draft(.a)
        d.tapSet(.squat, 0)
        XCTAssertEqual(DraftStore.load()?.loggedSetCount, 1,
                       "a 45-minute session must survive the process dying")
    }
}
