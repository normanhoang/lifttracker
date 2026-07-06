import XCTest
@testable import LiftTracker

final class LoggedExerciseDisplayTests: XCTestCase {

    private func logged(_ ex: Exercise, weight: Double, reps: [Int], sets: Int) -> LoggedExercise {
        LoggedExercise(exerciseID: ex.rawValue, weight: weight, reps: reps,
                       targetSets: sets, targetReps: Exercise.targetReps)
    }

    func testSkipped() {
        let l = logged(.squat, weight: 100, reps: [], sets: 5)
        XCTAssertEqual(l.resultText(.lb), "Skipped")
    }

    func testFullSuccessMultiSet() {
        let l = logged(.squat, weight: 245, reps: [5, 5, 5, 5, 5], sets: 5)
        XCTAssertEqual(l.resultText(.lb), "5×5 245lb")
    }

    func testFullSuccessSingleSet() {
        let l = logged(.deadlift, weight: 265, reps: [5], sets: 1)
        XCTAssertEqual(l.resultText(.lb), "5×265lb")
    }

    func testPartial() {
        let l = logged(.bench, weight: 185, reps: [5, 5, 5, 4, 5], sets: 5)
        XCTAssertEqual(l.resultText(.lb), "5/5/5/4/5 185lb")
    }

    func testUnitCarriesThrough() {
        let l = logged(.squat, weight: 245, reps: [5, 5, 5, 5, 5], sets: 5)
        XCTAssertTrue(l.resultText(.kg).hasSuffix("kg"))
    }
}

final class WorkoutSessionTests: XCTestCase {

    private func session(_ type: WorkoutType, ordered exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(date: .now, type: type, bodyWeight: nil)
        s.exercises = exercises.map {
            LoggedExercise(exerciseID: $0.rawValue, weight: 100, reps: [5],
                           targetSets: 5, targetReps: 5)
        }
        return s
    }

    func testOrderedExercisesFollowsSlotOrder() {
        // Insert out of canonical order; orderedExercises should restore A's order.
        let s = session(.a, ordered: [.row, .squat, .bench])
        XCTAssertEqual(s.orderedExercises.map(\.exerciseID),
                       [Exercise.squat, .bench, .row].map(\.rawValue))
    }

    func testIsSuccessRequiresEverySetAtTarget() {
        let s = session(.a, ordered: [.squat])
        let sq = s.exercises[0]
        sq.reps = [5, 5, 5, 5, 5]
        XCTAssertTrue(sq.isSuccess)
        sq.reps = [5, 5, 5, 5, 4]
        XCTAssertFalse(sq.isSuccess)
        sq.reps = [5, 5, 5]           // too few sets
        XCTAssertFalse(sq.isSuccess)
    }

    func testIsSkipped() {
        let l = LoggedExercise(exerciseID: Exercise.squat.rawValue, weight: 100,
                               reps: [], targetSets: 5, targetReps: 5)
        XCTAssertTrue(l.isSkipped)
        l.reps = [5]
        XCTAssertFalse(l.isSkipped)
    }
}
