import XCTest
@testable import LiftTracker

final class RestTimerSupportTests: XCTestCase {

    func testResolveFallsBackToDefaultWhenNil() {
        XCTAssertEqual(RestDurationSetting.resolve(nil), 60)
    }

    func testResolveFallsBackToDefaultWhenZero() {
        // UserDefaults.double(forKey:) returns 0 for a missing key — must not
        // be treated as a real user-chosen duration.
        XCTAssertEqual(RestDurationSetting.resolve(0), 60)
    }

    func testResolveUsesStoredValue() {
        XCTAssertEqual(RestDurationSetting.resolve(90), 90)
    }

    func testResolveReturnsNilWhenOff() {
        XCTAssertNil(RestDurationSetting.resolve(RestDurationSetting.offValue))
    }
}
