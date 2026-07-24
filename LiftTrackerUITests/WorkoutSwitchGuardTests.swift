import XCTest

final class WorkoutSwitchGuardTests: XCTestCase {
    /// Switching A/B used to call `rebuildSets()` unconditionally — one tap in
    /// the menu wiped a session in progress with no warning. This is the
    /// regression the confirmation exists to prevent.
    func testSwitchingDayAsksBeforeDiscardingAndKeepLoggingKeepsTheSets() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        app.buttons["repCircle.squat.1"].tap()
        app.buttons["repCircle.squat.2"].tap()

        let finish = app.buttons["finishWorkout"]
        let before = finish.label

        app.tapOtherDay()

        let keep = app.buttons["keepLogging"]
        XCTAssertTrue(keep.waitForExistence(timeout: 2), "the switch must be confirmed")
        keep.tap()

        XCTAssertEqual(finish.label, before, "all three sets survive")
    }

    /// With nothing logged there is nothing to lose, so the dialog is skipped.
    func testSwitchingWithAnEmptyGridDoesNotAsk() {
        let app = XCUIApplication.launched()
        XCTAssertTrue(app.buttons["workoutPicker"].waitForExistence(timeout: 3))

        app.tapOtherDay()

        XCTAssertFalse(app.buttons["keepLogging"].waitForExistence(timeout: 1))
    }
}
