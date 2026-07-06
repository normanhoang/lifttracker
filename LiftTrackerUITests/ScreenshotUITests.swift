import XCTest

final class ScreenshotUITests: XCTestCase {
    func testCaptureAllTabs() {
        let app = XCUIApplication()
        app.launch()

        let tabs = ["Workout", "History", "Progress", "Settings"]
        for (index, tab) in tabs.enumerated() {
            app.buttons[tab].tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = String(format: "%02d_%@", index + 1, tab.lowercased())
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
