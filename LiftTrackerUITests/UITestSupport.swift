import XCTest

extension XCUIApplication {
    /// Launch past the first-run screen, and past a resume prompt left by an
    /// earlier run on the same day.
    static func launched() -> XCUIApplication {
        let app = XCUIApplication()
        // UserDefaults reads launch arguments as an override domain.
        app.launchArguments += ["-hasCompletedFirstRun", "YES"]
        app.launch()

        let startFresh = app.buttons["Start fresh"]
        if startFresh.waitForExistence(timeout: 1) { startFresh.tap() }
        return app
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
