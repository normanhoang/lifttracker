import XCTest
@testable import LiftTracker

final class SetStateTests: XCTestCase {

    func testTapCycle() {
        var s = SetState.notStarted
        s.tap(); XCTAssertEqual(s, .done(5))
        s.tap(); XCTAssertEqual(s, .done(4))
        s.tap(); XCTAssertEqual(s, .done(3))
        s.tap(); XCTAssertEqual(s, .done(2))
        s.tap(); XCTAssertEqual(s, .done(1))
        s.tap(); XCTAssertEqual(s, .done(0))
        s.tap(); XCTAssertEqual(s, .notStarted, "done(0) wraps back to notStarted")
    }

    func testDisplayAndHighlighted() {
        XCTAssertEqual(SetState.notStarted.display, 5)
        XCTAssertFalse(SetState.notStarted.highlighted)
        XCTAssertEqual(SetState.done(3).display, 3)
        XCTAssertTrue(SetState.done(3).highlighted)
        XCTAssertTrue(SetState.done(0).highlighted)
    }
}

@MainActor
final class WorkoutDraftTests: XCTestCase {

    private func draft(_ type: WorkoutType = .a,
                       weights: [String: Double] = [:]) -> WorkoutDraft {
        let d = WorkoutDraft()
        d.reset(type: type, weights: weights, bodyWeight: nil)
        return d
    }

    func testResetBuildsGridPerSlot() {
        let d = draft(.a)
        XCTAssertEqual(d.states(.squat).count, 5)
        XCTAssertEqual(d.states(.bench).count, 5)
        XCTAssertEqual(d.states(.row).count, 5)
        XCTAssertTrue(d.states(.squat).allSatisfy { $0 == .notStarted })
        XCTAssertTrue(d.states(.ohp).isEmpty, "OHP is not in workout A")
    }

    func testTapReturnsTrueOnlyWhenStartingASet() {
        let d = draft(.a)
        XCTAssertTrue(d.tap(.squat, 0), "first tap starts the set → kicks rest timer")
        XCTAssertFalse(d.tap(.squat, 0), "subsequent taps on a started set do not")
    }

    func testTapOutOfRangeIsSafe() {
        let d = draft(.a)
        XCTAssertFalse(d.tap(.squat, 99))
        XCTAssertFalse(d.tap(.ohp, 0), "OHP absent from workout A")
    }

    func testHasProgress() {
        let d = draft(.a)
        XCTAssertFalse(d.hasProgress)
        _ = d.tap(.bench, 2)
        XCTAssertTrue(d.hasProgress)
    }

    func testChangeTypeResetsGridKeepsWeights() {
        let d = draft(.a, weights: [Exercise.squat.rawValue: 200])
        _ = d.tap(.squat, 0)
        d.changeType(.b)
        XCTAssertEqual(d.states(.deadlift).count, 1)
        XCTAssertFalse(d.hasProgress, "grid reset on type change")
        XCTAssertEqual(d.weight(.squat), 200, "weights preserved")
    }

    func testBuildSessionFullSuccess() {
        let d = draft(.a, weights: [Exercise.squat.rawValue: 100])
        for i in 0..<5 { _ = d.tap(.squat, i) }   // each → done(5)
        let session = d.buildSession()
        let squat = session.exercises.first { $0.exerciseID == Exercise.squat.rawValue }!
        XCTAssertEqual(squat.reps, [5, 5, 5, 5, 5])
        XCTAssertEqual(squat.weight, 100)
        XCTAssertTrue(squat.isSuccess)
    }

    func testBuildSessionPartial() {
        let d = draft(.a)
        _ = d.tap(.bench, 0)                 // done(5)
        _ = d.tap(.bench, 1); _ = d.tap(.bench, 1)   // two taps → done(4)
        let session = d.buildSession()
        let bench = session.exercises.first { $0.exerciseID == Exercise.bench.rawValue }!
        XCTAssertEqual(bench.reps, [5, 4, 0, 0, 0])
        XCTAssertFalse(bench.isSuccess)
        XCTAssertFalse(bench.isSkipped)
    }

    func testBuildSessionSkippedExerciseHasEmptyReps() {
        let d = draft(.a)
        _ = d.tap(.squat, 0)                 // only squat touched
        let session = d.buildSession()
        let row = session.exercises.first { $0.exerciseID == Exercise.row.rawValue }!
        XCTAssertTrue(row.reps.isEmpty)
        XCTAssertTrue(row.isSkipped)
    }
}
