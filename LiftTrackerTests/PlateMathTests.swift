import XCTest
@testable import LiftTracker

final class PlateMathTests: XCTestCase {

    private let lb = PlateMath.lbPlates      // 45 35 25 10 5 2.5
    private let kg = PlateMath.kgPlates      // 25 20 15 10 5 2.5 1.25

    func testStandardPoundLoads() {
        XCTAssertEqual(PlateMath.perSide(total: 185, bar: 45, available: lb), [45, 25])
        XCTAssertEqual(PlateMath.perSide(total: 135, bar: 45, available: lb), [45])
        XCTAssertEqual(PlateMath.perSide(total: 45, bar: 45, available: lb), [], "bare bar")
    }

    func testWeightBelowTheBarReturnsNoPlates() {
        XCTAssertEqual(PlateMath.perSide(total: 20, bar: 45, available: lb), [],
                       "never negative plates")
    }

    func testUnloadableWeightWithoutSmallPlates() {
        let heavy = lb.filter { $0 >= 5 }    // no 2.5s in the gym
        XCTAssertFalse(PlateMath.isLoadable(total: 187.5, bar: 45, available: heavy))
        XCTAssertEqual(PlateMath.closestLoadable(to: 187.5, bar: 45, available: heavy), 185)
    }

    func testLoadableWeightIsItsOwnClosest() {
        XCTAssertTrue(PlateMath.isLoadable(total: 185, bar: 45, available: lb))
        XCTAssertEqual(PlateMath.closestLoadable(to: 185, bar: 45, available: lb), 185)
    }

    func testMetricGymUsesMetricPlates() {
        // 100kg on a 20kg bar → 40 per side → 25 + 15
        XCTAssertEqual(PlateMath.perSide(total: 100, bar: 20, available: kg), [25, 15])
        XCTAssertTrue(PlateMath.isLoadable(total: 100, bar: 20, available: kg))
    }

    func testMetricOddWeightFallsBackToTheNearestLoadable() {
        let noSmall = kg.filter { $0 >= 5 }
        XCTAssertFalse(PlateMath.isLoadable(total: 82.5, bar: 20, available: noSmall))
        XCTAssertEqual(PlateMath.closestLoadable(to: 82.5, bar: 20, available: noSmall), 80)
    }

    func testClosestLoadableNeverGoesBelowTheBar() {
        XCTAssertEqual(PlateMath.closestLoadable(to: 46, bar: 45, available: [45]), 45)
    }

    func testPlateLabelsKeepEveryDigitOfAMetricPlate() {
        XCTAssertEqual(PlateMath.label(45), "45")
        XCTAssertEqual(PlateMath.label(2.5), "2.5")
        XCTAssertEqual(PlateMath.label(1.25), "1.25", "a 1.25kg plate is not a 1.2kg plate")
    }

    func testEmptyPlateSetIsHandled() {
        XCTAssertEqual(PlateMath.perSide(total: 135, bar: 45, available: []), [])
        XCTAssertFalse(PlateMath.isLoadable(total: 135, bar: 45, available: []))
    }
}

final class BarSettingTests: XCTestCase {

    func testDefaultsAreUnitNative() {
        XCTAssertEqual(BarSetting.defaultBar(.lb), 45)
        XCTAssertEqual(BarSetting.defaultBar(.kg), 20)
        XCTAssertEqual(BarSetting.allPlates(.kg), PlateMath.kgPlates)
    }

    func testCSVRoundTrip() {
        let csv = BarSetting.csv([2.5, 45, 25])
        XCTAssertEqual(csv, "45,25,2.5")
        XCTAssertEqual(BarSetting.parse(csv, unit: .lb), [45, 25, 2.5])
    }

    func testUnparseableCSVFallsBackToTheFullSet() {
        XCTAssertEqual(BarSetting.parse("", unit: .lb), PlateMath.lbPlates,
                       "better the full set than no plates at all")
        XCTAssertEqual(BarSetting.parse("nonsense", unit: .kg), PlateMath.kgPlates)
    }

    func testKeysDifferPerUnit() {
        XCTAssertNotEqual(BarSetting.barKey(.lb), BarSetting.barKey(.kg))
        XCTAssertNotEqual(BarSetting.platesKey(.lb), BarSetting.platesKey(.kg))
    }
}
