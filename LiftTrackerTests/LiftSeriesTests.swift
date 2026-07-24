import XCTest
@testable import LiftTracker

final class LiftSeriesTests: XCTestCase {

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: .now)!
    }

    private func series(_ weights: [(Int, Double, Bool)]) -> LiftSeries {
        LiftSeries(points: weights.map { LiftSeries.Point(date: day($0.0), weightLb: $0.1, missed: $0.2) })
    }

    func testDeltaAndBest() {
        let s = series([(-28, 45, false), (-14, 95, false), (0, 135, false)])
        XCTAssertEqual(s.delta, 90)
        XCTAssertEqual(s.best, 135)
        XCTAssertEqual(s.current, 135)
    }

    func testDeloadCountsEveryDropBetweenSessions() {
        let s = series([(-28, 155, false), (-21, 155, true), (-14, 140, false), (-7, 145, false), (0, 130, false)])
        XCTAssertEqual(s.deloadCount, 2)
    }

    func testMissCount() {
        let s = series([(-14, 100, false), (-7, 100, true), (0, 100, true)])
        XCTAssertEqual(s.missCount, 2)
    }

    func testWeeksSpanned() {
        XCTAssertEqual(series([(-21, 100, false), (0, 130, false)]).weeks(), 3)
        XCTAssertEqual(series([(0, 100, false)]).weeks(), 1, "one session is still a week")
        XCTAssertEqual(series([]).weeks(), 0)
    }

    func testFlatWeeksMeasuresFromTheLastChange() {
        let s = series([(-28, 100, false), (-21, 155, false), (-14, 155, false), (-7, 155, false)])
        XCTAssertEqual(s.flatWeeks(), 3, "155 first appeared 21 days ago")
    }

    func testWindowedTrimsToTheRange() {
        let s = series([(-120, 45, false), (-30, 100, false), (0, 135, false)])
        XCTAssertEqual(s.windowed(2).points.count, 2)
        XCTAssertEqual(s.windowed(nil).points.count, 3)
    }

    func testStateIsStalledWhileTheStreakRuns() {
        let s = series([(-14, 155, false), (-7, 155, true), (0, 155, true)])
        let note = s.state(failStreak: 2, hitBestToday: false, unit: .lb)
        XCTAssertEqual(note.tone, .warn)
        XCTAssertEqual(note.text, "Stalled · 2 misses")
    }

    func testStateIsClimbingWithTheBest() {
        let s = series([(-14, 175, false), (-7, 180, false), (0, 185, false)])
        let note = s.state(failStreak: 0, hitBestToday: false, unit: .lb)
        XCTAssertEqual(note.tone, .up)
        XCTAssertEqual(note.text, "Climbing · best 185")
    }

    func testNewBestTodayWins() {
        let s = series([(0, 185, false)])
        XCTAssertEqual(s.state(failStreak: 0, hitBestToday: true, unit: .lb).text, "New best today")
    }

    func testEmptySeriesIsSafe() {
        let s = series([])
        XCTAssertTrue(s.isEmpty)
        XCTAssertNil(s.current)
        XCTAssertEqual(s.delta, 0)
        XCTAssertEqual(s.state(failStreak: 0, hitBestToday: false, unit: .lb).text, "Not logged yet")
    }
}
