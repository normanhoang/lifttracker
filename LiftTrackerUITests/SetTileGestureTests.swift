import XCTest

final class SetTileGestureTests: XCTestCase {

    /// Press-and-hold on an untouched tile opens the rep picker. A plain tap on
    /// that tile logs the target instead, so if the hold gesture never fires the
    /// picker never appears.
    func testHoldingAnUntouchedTileOpensTheRepPicker() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        XCTAssertEqual(tile.label, "Set not logged")

        tile.press(forDuration: 0.8)

        XCTAssertTrue(app.buttons["repPicker.3"].waitForExistence(timeout: 2),
                      "hold must open the picker")
    }

    /// The hold must also suppress the tap it is part of — otherwise letting go
    /// logs the target behind the picker and the pick overwrites a set the user
    /// never meant to log.
    func testHoldingDoesNotAlsoLogTheSet() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))

        tile.press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["repPicker.0"].waitForExistence(timeout: 2))

        // Dismiss without picking: the set must still be untouched.
        app.swipeDown(velocity: .fast)

        let after = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(after.waitForExistence(timeout: 2))
        XCTAssertEqual(after.label, "Set not logged", "a hold is not a tap")
    }

    /// Holding a logged tile is the correction path.
    func testHoldingALoggedTileOpensThePickerToo() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        XCTAssertEqual(tile.label, "5 reps")

        tile.press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["repPicker.2"].waitForExistence(timeout: 2))
        app.buttons["repPicker.2"].tap()

        XCTAssertEqual(app.buttons["repCircle.squat.0"].label, "2 reps")
    }
}
