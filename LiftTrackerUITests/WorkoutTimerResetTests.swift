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
    }

    /// Tapping the same tile repeatedly must not walk the rep count down — that
    /// cycle is what the redesign replaced.
    func testTappingALoggedTileOpensThePickerInsteadOfCycling() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        XCTAssertEqual(tile.label, "5 reps")

        tile.tap()
        XCTAssertTrue(app.buttons["repPicker.3"].waitForExistence(timeout: 2),
                      "a second tap is a correction, not a decrement")
        app.buttons["repPicker.3"].tap()

        XCTAssertTrue(app.buttons["repCircle.squat.0"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["repCircle.squat.0"].label, "3 reps")
    }
}
