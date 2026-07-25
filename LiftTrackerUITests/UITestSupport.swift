import XCTest

extension XCUIApplication {
    /// Launch past the first-run screen, and past a resume prompt left by an
    /// earlier run on the same day.
    static func launched(seedDemoData: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if seedDemoData { app.launchArguments.append("-seedDemoData") }
        // UserDefaults reads launch arguments as an override domain, which wins
        // over anything on disk. The draft override is a non-Data value, so
        // DraftStore.load() finds nothing and a draft left by an earlier test
        // can't leak into this one.
        // Key is spelled out: a UI test runs in its own process and doesn't link
        // the app module. Keep in step with DraftStore.key.
        app.launchArguments += ["-hasCompletedFirstRun", "YES", "-workoutDraft", ""]
        app.launch()

        let startFresh = app.buttons["Start fresh"]
        if startFresh.waitForExistence(timeout: 1) { startFresh.tap() }
        return app
    }

    /// Wait for an element's label to become `expected`. A synthesized tap and
    /// the accessibility tree catching up are not the same instant, so reading
    /// `.label` straight after a gesture is a race.
    func waitForLabel(_ element: XCUIElement, _ expected: String,
                      timeout: TimeInterval = 3,
                      file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "expected label '\(expected)', got '\(element.label)'",
                       file: file, line: line)
    }

    /// Open the day menu and choose whichever of A/B isn't showing. Which day
    /// the app suggests depends on the last session, so it can't be hard-coded.
    func tapOtherDay() {
        let picker = buttons["workoutPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        let other = picker.label.contains("Workout A") ? "Workout B" : "Workout A"
        picker.tap()

        let item = buttons.matching(identifier: other).element(boundBy: 0)
        XCTAssertTrue(item.waitForExistence(timeout: 2))
        item.tap()
    }

    /// Tap set tiles until every lift of the current day is logged.
    func logEverySet(timeout: TimeInterval = 5) {
        let finish = buttons["finishWorkout"]
        XCTAssertTrue(finish.waitForExistence(timeout: timeout))

        // 15 sets is the most any day has; the guard is a runaway stop, not a count.
        for _ in 0..<40 {
            if finish.label == "Finish workout" { return }
            // Only untouched tiles: tapping a logged one opens the correction picker.
            let untouched = buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'repCircle.' AND label == %@",
                            "Set not logged")
            )
            guard untouched.count > 0 else { return }
            untouched.element(boundBy: 0).tap()
        }
    }
}
