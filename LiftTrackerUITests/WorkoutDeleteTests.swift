import XCTest

final class WorkoutDeleteTests: XCTestCase {
    /// Swiping a past workout and tapping the red "Delete" swipe action must
    /// delete it immediately -- no follow-up confirmation dialog.
    func testSwipeDeleteRemovesWorkoutWithoutConfirmation() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["repCircle.squat.0"].tap()
        app.buttons["Finish"].tap()
        app.buttons["Done"].tap()

        app.buttons["History"].tap()
        let row = app.staticTexts["Workout A"]
        XCTAssertTrue(row.waitForExistence(timeout: 2))

        row.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 2))
    }
}
