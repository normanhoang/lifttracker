import XCTest
@testable import LiftTracker

final class WeightFormatTests: XCTestCase {

    func testWholeNumbersHaveNoDecimal() {
        XCTAssertEqual(WeightFormat.string(250, .lb), "250lb")
        XCTAssertEqual(WeightFormat.string(0, .lb), "0lb")
    }

    func testKilogramsFormatWithOneDecimalWhenFractional() {
        // 250 lb → 113.398... kg → "113.4kg"
        XCTAssertEqual(WeightFormat.string(250, .kg), "113.4kg")
    }

    func testKilogramsDropDecimalWhenWhole() {
        // pick a lb value that converts to a whole kg: 1 kg = 1/kgPerLb lb
        let oneKgInLb = 1 / WeightFormat.kgPerLb
        XCTAssertEqual(WeightFormat.string(oneKgInLb, .kg), "1kg")
    }

    func testFromLbAndToLbRoundTrip() {
        for lb in [45.0, 137.5, 315.0] {
            let kg = WeightFormat.fromLb(lb, .kg)
            XCTAssertEqual(WeightFormat.toLb(kg, .kg), lb, accuracy: 1e-9)
        }
    }

    func testLbUnitIsIdentity() {
        XCTAssertEqual(WeightFormat.fromLb(185, .lb), 185)
        XCTAssertEqual(WeightFormat.toLb(185, .lb), 185)
    }

    func testConversionConstant() {
        XCTAssertEqual(WeightFormat.fromLb(1, .kg), WeightFormat.kgPerLb, accuracy: 1e-12)
    }
}
