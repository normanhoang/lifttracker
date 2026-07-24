import XCTest
@testable import LiftTracker

final class ProgressionCopyTests: XCTestCase {

    // MARK: - Workout card note

    func testClimbingNoteNamesTheGainAndTheStreak() {
        let note = ProgressionCopy.liftNote(increment: 5, successStreak: 2, failStreak: 0,
                                            currentWeight: 185, deloadedLastSession: false,
                                            lastDate: nil, unit: .lb)
        XCTAssertEqual(note.tone, .up)
        XCTAssertEqual(note.text, "+5lb · 3rd session climbing")
    }

    func testMissNoteIsAmber() {
        let note = ProgressionCopy.liftNote(increment: 5, successStreak: 0, failStreak: 2,
                                            currentWeight: 155, deloadedLastSession: false,
                                            lastDate: nil, unit: .lb)
        XCTAssertEqual(note.tone, .warn)
        XCTAssertEqual(note.text, "2 misses · deloads after 3")
    }

    func testDeloadNoteWins() {
        let note = ProgressionCopy.liftNote(increment: 5, successStreak: 0, failStreak: 0,
                                            currentWeight: 140, deloadedLastSession: true,
                                            lastDate: nil, unit: .lb)
        XCTAssertEqual(note.text, "−10% after 3 misses")
        XCTAssertEqual(note.tone, .warn)
    }

    func testHoldingNoteIsNeutral() {
        let note = ProgressionCopy.liftNote(increment: 5, successStreak: 0, failStreak: 0,
                                            currentWeight: 95, deloadedLastSession: false,
                                            lastDate: nil, unit: .lb)
        XCTAssertEqual(note.tone, .neutral)
        XCTAssertEqual(note.text, "Holding at 95lb")
    }

    // MARK: - Settings state line

    func testSettingsStateStatesTheNextWeight() {
        let note = ProgressionCopy.settingsState(currentWeight: 185, nextWeight: 190,
                                                 deloadWeight: 165, failStreak: 0, hasLogged: true,
                                                 incrementOverride: nil, unit: .lb)
        XCTAssertEqual(note.text, "190 next session")
    }

    func testSettingsStateStatesTheDeloadTarget() {
        let note = ProgressionCopy.settingsState(currentWeight: 155, nextWeight: 160,
                                                 deloadWeight: 140, failStreak: 2, hasLogged: true,
                                                 incrementOverride: nil, unit: .lb)
        XCTAssertEqual(note.text, "2 misses · deloads to 140 on the next")
        XCTAssertEqual(note.tone, .warn)
    }

    func testSettingsStateMentionsACustomStep() {
        let note = ProgressionCopy.settingsState(currentWeight: 245, nextWeight: 255,
                                                 deloadWeight: 220, failStreak: 0, hasLogged: true,
                                                 incrementOverride: 10, unit: .lb)
        XCTAssertEqual(note.text, "255 next session · +10lb steps")
    }

    // MARK: - Complete screen

    private func change(_ id: String, _ outcome: Progression.Outcome) -> Progression.Change {
        Progression.Change(exerciseID: id, outcome: outcome)
    }

    func testChangeTitleForEachOutcome() {
        XCTAssertEqual(ProgressionCopy.changeTitle(change("squat", .increased(from: 185, to: 190, streak: 3)),
                                                   name: "Squat", unit: .lb), "Squat 185 → 190")
        XCTAssertEqual(ProgressionCopy.changeTitle(change("ohp", .held(weight: 95, misses: 2)),
                                                   name: "Overhead Press", unit: .lb),
                       "Overhead Press stays at 95")
        XCTAssertEqual(ProgressionCopy.changeTitle(change("row", .deloaded(from: 155, to: 140)),
                                                   name: "Barbell Row", unit: .lb), "Barbell Row 155 → 140")
    }

    func testHoldReasonCountsTheMissesLeft() {
        let logged = LoggedExercise(exerciseID: "ohp", weight: 95, reps: [5, 5, 5, 4, 3],
                                    targetSets: 5, targetReps: 5)
        let text = ProgressionCopy.changeReason(change("ohp", .held(weight: 95, misses: 2)),
                                                logged: logged, deloadWeight: 85, increment: 5, unit: .lb)
        XCTAssertEqual(text, "22 of 25 reps. One more miss deloads to 85.")
    }

    func testDeloadReasonFramesItAsTheProgramWorking() {
        let text = ProgressionCopy.changeReason(change("row", .deloaded(from: 155, to: 140)),
                                                logged: nil, deloadWeight: 140, increment: 5, unit: .lb)
        XCTAssertEqual(text, "Three misses. Build back up — this is the program working.")
    }

    func testIncreaseReasonNamesTheStreak() {
        let logged = LoggedExercise(exerciseID: "squat", weight: 185, reps: [5, 5, 5, 5, 5],
                                    targetSets: 5, targetReps: 5)
        let text = ProgressionCopy.changeReason(change("squat", .increased(from: 185, to: 190, streak: 3)),
                                                logged: logged, deloadWeight: 165, increment: 5, unit: .lb)
        XCTAssertEqual(text, "Clean 5×5. 3rd straight increase.")
    }

    // MARK: - Headline

    private func name(_ id: String) -> String { Exercise(rawValue: id)?.name ?? id }

    func testHeadlineForOneIncrease() {
        let changes = [change("squat", .increased(from: 180, to: 185, streak: 1)),
                       change("ohp", .held(weight: 95, misses: 1))]
        XCTAssertEqual(ProgressionCopy.headline(changes, nameFor: name), "Squat goes up.")
    }

    func testHeadlineForTwoIncreases() {
        let changes = [change("squat", .increased(from: 180, to: 185, streak: 1)),
                       change("deadlift", .increased(from: 245, to: 255, streak: 2)),
                       change("ohp", .held(weight: 95, misses: 1))]
        XCTAssertEqual(ProgressionCopy.headline(changes, nameFor: name),
                       "Squat and deadlift both go up.")
    }

    func testHeadlineWhenEverythingClimbs() {
        let changes = [change("squat", .increased(from: 1, to: 2, streak: 1)),
                       change("bench", .increased(from: 1, to: 2, streak: 1)),
                       change("row", .increased(from: 1, to: 2, streak: 1))]
        XCTAssertEqual(ProgressionCopy.headline(changes, nameFor: name), "Everything goes up.")
    }

    func testHeadlineForADeload() {
        let changes = [change("row", .deloaded(from: 155, to: 140)),
                       change("ohp", .held(weight: 95, misses: 1))]
        XCTAssertEqual(ProgressionCopy.headline(changes, nameFor: name), "Barbell Row deloads.")
    }

    func testHeadlineWhenNothingMoves() {
        let changes = [change("squat", .held(weight: 185, misses: 1))]
        XCTAssertEqual(ProgressionCopy.headline(changes, nameFor: name), "Weights hold this session.")
    }

    func testPlainConvertsToTheDisplayUnit() {
        XCTAssertEqual(ProgressionCopy.plain(100, .lb), "100")
        XCTAssertEqual(ProgressionCopy.plain(100, .kg), "45.4")
    }
}
