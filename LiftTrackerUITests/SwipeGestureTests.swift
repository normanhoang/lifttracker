import XCTest

final class SwipeGestureTests: XCTestCase {
    /// Squat's rep-circle row is a nested horizontal ScrollView. A page-swipe
    /// starting there must still switch tabs instead of losing the touch to
    /// that inner ScrollView.
    func testSwipeOverRepCircleRowChangesTab() {
        let app = XCUIApplication()
        app.launch()

        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.18))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.18))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertTrue(app.buttons["History"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["History"].isSelected)
    }
}
