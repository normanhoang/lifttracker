import XCTest

final class ScreenshotUITests: XCTestCase {
    /// Captured against ten weeks of seeded training — History and Progress are
    /// the screens this release improved most and both look like nothing empty.
    func testCaptureAllTabs() {
        let app = XCUIApplication.launched(seedDemoData: true)

        let tabs = ["Workout", "History", "Progress", "Settings"]
        for (index, tab) in tabs.enumerated() {
            app.buttons[tab].tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = String(format: "%02d_%@", index + 1, tab.lowercased())
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// The one screen that only ever appears on a fresh install.
    func testCaptureFirstRun() {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedFirstRun", "NO"]
        app.launch()

        XCTAssertTrue(app.buttons["Start with an empty bar"].waitForExistence(timeout: 3))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "00_first_run"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
