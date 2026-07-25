import XCTest

final class WorkoutDeleteTests: XCTestCase {
    /// Deleting a session is an explicit action at the foot of the day sheet,
    /// not a hidden swipe, and it leaves an undo behind.
    func testDeletingFromTheDaySheetOffersAnUndo() {
        let app = XCUIApplication.launched()

        app.logEverySet()
        let finish = app.buttons["finishWorkout"]
        XCTAssertEqual(finish.label, "Finish workout", "every set logged")
        finish.tap()

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()

        app.buttons["History"].tap()

        let card = app.buttons.matching(identifier: "sessionCard").element(boundBy: 0)
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()

        let delete = app.buttons["deleteSession"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()

        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 3),
                      "a delete you cannot take back is the wrong kind of quiet")
    }
}
