import XCTest
@testable import LiftTracker

final class ProgressionTests: XCTestCase {

    // Build a session with one logged exercise at `weight`, with the given reps.
    private func session(_ ex: Exercise, weight: Double, reps: [Int], sets: Int = 5) -> WorkoutSession {
        let s = WorkoutSession(date: .now, type: .a)
        let logged = LoggedExercise(exerciseID: ex.rawValue, weight: weight, reps: reps,
                                    targetSets: sets, targetReps: Exercise.targetReps)
        logged.session = s
        s.exercises = [logged]
        return s
    }

    // Apply progression against a single ExerciseProgress row we own.
    @discardableResult
    private func apply(_ s: WorkoutSession, _ prog: ExerciseProgress) -> [Progression.Change] {
        Progression.apply(session: s) { _ in prog }
    }

    // MARK: - Rules (unchanged contract)

    func testRound5() {
        XCTAssertEqual(Progression.round5(0), 0)
        XCTAssertEqual(Progression.round5(2), 0)
        XCTAssertEqual(Progression.round5(3), 5)
        XCTAssertEqual(Progression.round5(47), 45)
        XCTAssertEqual(Progression.round5(48), 50)
    }

    func testSuccessAddsIncrementAndResetsStreak() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 100, failStreak: 2)
        apply(session(.squat, weight: 100, reps: [5, 5, 5, 5, 5]), prog)
        XCTAssertEqual(prog.currentWeight, 105)   // squat increment 5
        XCTAssertEqual(prog.failStreak, 0)
    }

    func testDeadliftIncrementIsTen() {
        let prog = ExerciseProgress(exerciseID: Exercise.deadlift.rawValue, currentWeight: 200)
        apply(session(.deadlift, weight: 200, reps: [5], sets: 1), prog)
        XCTAssertEqual(prog.currentWeight, 210)
    }

    func testSingleFailureIncrementsStreakOnly() {
        let prog = ExerciseProgress(exerciseID: Exercise.bench.rawValue, currentWeight: 135)
        apply(session(.bench, weight: 135, reps: [5, 5, 5, 5, 4]), prog)  // one short → not success
        XCTAssertEqual(prog.currentWeight, 135, "weight unchanged on a single failure")
        XCTAssertEqual(prog.failStreak, 1)
    }

    func testThirdFailureDeloadsTenPercentRoundedTo5() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 200, failStreak: 2)
        apply(session(.squat, weight: 200, reps: [5, 5, 5, 5, 0]), prog)  // 3rd straight fail
        XCTAssertEqual(prog.currentWeight, 180, "200 * 0.9 = 180")
        XCTAssertEqual(prog.failStreak, 0, "streak resets after deload")
    }

    func testDeloadRoundsToNearestFive() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 47, failStreak: 2)
        apply(session(.squat, weight: 47, reps: [1], sets: 5), prog)
        // 47 * 0.9 = 42.3 → round5 → 40
        XCTAssertEqual(prog.currentWeight, 40)
    }

    func testDeloadNeverBelowFive() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 5, failStreak: 2)
        apply(session(.squat, weight: 5, reps: [0], sets: 5), prog)
        XCTAssertEqual(prog.currentWeight, 5, "deload floors at 5")
    }

    func testSkippedExerciseUnchanged() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 100, failStreak: 1)
        apply(session(.squat, weight: 100, reps: []), prog)   // empty reps ⇒ skipped
        XCTAssertEqual(prog.currentWeight, 100)
        XCTAssertEqual(prog.failStreak, 1, "skip touches nothing")
    }

    // MARK: - Per-lift increment

    func testIncrementOverrideWinsOverTheLiftDefault() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 100)
        prog.incrementOverride = 2.5
        apply(session(.squat, weight: 100, reps: [5, 5, 5, 5, 5]), prog)
        XCTAssertEqual(prog.currentWeight, 102.5)
    }

    func testNilOverrideKeepsTheLiftDefault() {
        let prog = ExerciseProgress(exerciseID: Exercise.deadlift.rawValue, currentWeight: 200)
        XCTAssertNil(prog.incrementOverride)
        XCTAssertEqual(prog.increment(for: .deadlift), 10)
    }

    // MARK: - Outcomes

    func testSuccessReportsIncreaseWithStreak() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 180)
        prog.successStreak = 2
        let changes = apply(session(.squat, weight: 180, reps: [5, 5, 5, 5, 5]), prog)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].outcome, .increased(from: 180, to: 185, streak: 3))
    }

    func testMissReportsHoldWithMissCount() {
        let prog = ExerciseProgress(exerciseID: Exercise.ohp.rawValue, currentWeight: 95)
        let changes = apply(session(.ohp, weight: 95, reps: [5, 5, 5, 4, 3]), prog)
        XCTAssertEqual(changes[0].outcome, .held(weight: 95, misses: 1))
    }

    func testThirdMissReportsDeload() {
        let prog = ExerciseProgress(exerciseID: Exercise.row.rawValue, currentWeight: 155, failStreak: 2)
        let changes = apply(session(.row, weight: 155, reps: [5, 5, 5, 5, 4]), prog)
        XCTAssertEqual(changes[0].outcome, .deloaded(from: 155, to: 140))
    }

    func testSkipReportsSkipped() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 100)
        let changes = apply(session(.squat, weight: 100, reps: []), prog)
        XCTAssertEqual(changes[0].outcome, .skipped)
    }

    func testSuccessStreakResetsOnAMiss() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 100)
        prog.successStreak = 4
        apply(session(.squat, weight: 100, reps: [5, 5, 5, 5, 1]), prog)
        XCTAssertEqual(prog.successStreak, 0)
    }

    // MARK: - Preview

    func testNextWeightPreview() {
        let prog = ExerciseProgress(exerciseID: Exercise.squat.rawValue, currentWeight: 185)
        XCTAssertEqual(Progression.nextWeight(prog, .squat), 190)
    }

    func testDeloadWeightPreview() {
        let prog = ExerciseProgress(exerciseID: Exercise.row.rawValue, currentWeight: 155)
        XCTAssertEqual(Progression.deloadWeight(prog), 140, "155 * 0.9 = 139.5 → 140")
    }
}
