import XCTest

final class WorkoutTimerResetTests: XCTestCase {
    /// Logging a set starts the session clock. Undoing the only logged set puts
    /// the screen back where it started — no ticking header, as if the workout
    /// never began.
    func testUndoingTheOnlyLoggedSetClearsTheSession() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))

        tile.tap()
        let sessionClock = app.staticTexts["bottomBar.timer"]
        XCTAssertTrue(sessionClock.waitForExistence(timeout: 2))

        let undo = app.buttons["undoLastSet"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2), "Undo appears once a set is logged")
        undo.tap()

        XCTAssertFalse(app.buttons["undoLastSet"].exists, "nothing left to undo")
        XCTAssertEqual(app.buttons["finishWorkout"].label, "Log a set to finish")
        XCTAssertFalse(sessionClock.exists, "the session clock stops with it")
    }

    /// Discard stays reachable with nothing logged, so there is always a way out
    /// of a screen that has got itself into a state you don't want.
    func testDiscardIsAvailableWithAnEmptyGrid() {
        let app = XCUIApplication.launched()

        let overflow = app.buttons["workoutOverflow"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 3))
        overflow.tap()

        let discard = app.buttons["Discard workout"]
        XCTAssertTrue(discard.waitForExistence(timeout: 2))
        XCTAssertTrue(discard.isEnabled, "an escape hatch that disables itself is not one")
        discard.tap()

        // Nothing to lose, so it resets without asking.
        XCTAssertFalse(app.buttons["keepLogging"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["repCircle.squat.0"].waitForExistence(timeout: 2))
    }

    /// Tapping the same tile repeatedly must not walk the rep count down — that
    /// cycle is what the redesign replaced.
    func testTappingALoggedTileOpensThePickerInsteadOfCycling() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        app.waitForLabel(tile, "5 reps")

        tile.tap()
        XCTAssertTrue(app.buttons["repPicker.3"].waitForExistence(timeout: 2),
                      "a second tap is a correction, not a decrement")
        app.buttons["repPicker.3"].tap()

        XCTAssertTrue(app.buttons["repCircle.squat.0"].waitForExistence(timeout: 2))
        app.waitForLabel(app.buttons["repCircle.squat.0"], "3 reps")
    }
}
