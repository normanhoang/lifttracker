import XCTest

final class WorkoutTimerResetTests: XCTestCase {
    /// Selecting a rep circle starts the rest timer. Cycling that same circle
    /// all the way back to notStarted (deselecting it) should stop the timer
    /// and revert the bottom bar to "Rest", as if the workout never started.
    func testDeselectingAllCirclesResetsTimer() {
        let app = XCUIApplication()
        app.launch()

        let circle = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(circle.waitForExistence(timeout: 2))

        circle.tap() // notStarted -> done(5): starts the timer
        XCTAssertFalse(app.staticTexts["Rest"].exists)

        // done(5) -> done(4) -> done(3) -> done(2) -> done(1) -> done(0) -> notStarted
        for _ in 0..<6 {
            circle.tap()
        }

        XCTAssertTrue(app.staticTexts["Rest"].waitForExistence(timeout: 2))
    }
}
