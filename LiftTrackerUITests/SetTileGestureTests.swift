import XCTest

final class SetTileGestureTests: XCTestCase {

    /// Press-and-hold on an untouched tile opens the rep picker. A plain tap on
    /// that tile logs the target instead, so if the hold gesture never fires the
    /// picker never appears.
    func testHoldingAnUntouchedTileOpensTheRepPicker() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        app.waitForLabel(tile, "Set not logged")

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
        let pick = app.buttons["repPicker.0"]
        XCTAssertTrue(pick.waitForExistence(timeout: 2))

        // Dismiss without picking. Dragged from inside the sheet rather than
        // swiping the whole app, which lands wherever the app happens to be.
        pick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0)))

        let after = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(after.waitForExistence(timeout: 3))
        app.waitForLabel(after, "Set not logged")
        // The clock is the independent witness: it only starts when a set is
        // logged, so its absence proves the hold didn't log one.
        XCTAssertFalse(app.staticTexts["bottomBar.timer"].exists)
    }

    /// Holding a logged tile is the correction path.
    func testHoldingALoggedTileOpensThePickerToo() {
        let app = XCUIApplication.launched()

        let tile = app.buttons["repCircle.squat.0"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        app.waitForLabel(tile, "5 reps")

        tile.press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["repPicker.2"].waitForExistence(timeout: 2))
        app.buttons["repPicker.2"].tap()

        app.waitForLabel(app.buttons["repCircle.squat.0"], "2 reps")
    }
}
