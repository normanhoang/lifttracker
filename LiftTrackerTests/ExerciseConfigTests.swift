import XCTest
@testable import LiftTracker

final class ExerciseConfigTests: XCTestCase {

    func testIncrements() {
        XCTAssertEqual(Exercise.deadlift.increment, 10)
        for ex in Exercise.allCases where ex != .deadlift {
            XCTAssertEqual(ex.increment, 5, "\(ex) should increment by 5")
        }
    }

    func testStartingWeights() {
        XCTAssertEqual(Exercise.squat.startingWeight, 45)
        XCTAssertEqual(Exercise.bench.startingWeight, 45)
        XCTAssertEqual(Exercise.ohp.startingWeight, 45)
        XCTAssertEqual(Exercise.row.startingWeight, 65)
        XCTAssertEqual(Exercise.deadlift.startingWeight, 95)
    }

    func testCountsTowardTotalIsSquatBenchDeadliftOnly() {
        let counted = Exercise.allCases.filter(\.countsTowardTotal)
        XCTAssertEqual(Set(counted), [.squat, .bench, .deadlift])
    }

    func testNames() {
        XCTAssertEqual(Exercise.row.name, "Barbell Row")
        XCTAssertEqual(Exercise.ohp.name, "Overhead Press")
    }

    func testWorkoutTypeSlots() {
        XCTAssertEqual(WorkoutType.a.slots.map(\.exercise), [.squat, .bench, .row])
        XCTAssertEqual(WorkoutType.b.slots.map(\.exercise), [.squat, .ohp, .deadlift])
    }

    func testDeadliftIsSingleSet() {
        let deadliftSlot = WorkoutType.b.slots.first { $0.exercise == .deadlift }
        XCTAssertEqual(deadliftSlot?.sets, 1)
        // everything else is 5 sets
        let others = (WorkoutType.a.slots + WorkoutType.b.slots).filter { $0.exercise != .deadlift }
        XCTAssertTrue(others.allSatisfy { $0.sets == 5 })
    }

    func testOtherToggles() {
        XCTAssertEqual(WorkoutType.a.other, .b)
        XCTAssertEqual(WorkoutType.b.other, .a)
    }

    func testTitle() {
        XCTAssertEqual(WorkoutType.a.title, "Workout A")
        XCTAssertEqual(WorkoutType.b.title, "Workout B")
    }
}
