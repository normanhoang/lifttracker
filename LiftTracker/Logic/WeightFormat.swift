import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case lb, kg
    var id: String { rawValue }
}

/// Weights are stored internally in pounds; this converts/formats for display and editing.
enum WeightFormat {
    static let kgPerLb = 0.45359237

    private static func number(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }

    /// e.g. "250lb" or "113.4kg"
    static func string(_ lb: Double, _ unit: WeightUnit) -> String {
        let v = unit == .kg ? lb * kgPerLb : lb
        return "\(number(v))\(unit.rawValue)"
    }

    /// Value shown in an editor field, in the current unit.
    static func fromLb(_ lb: Double, _ unit: WeightUnit) -> Double {
        unit == .kg ? lb * kgPerLb : lb
    }

    /// Convert an edited field value back to pounds for storage.
    static func toLb(_ v: Double, _ unit: WeightUnit) -> Double {
        unit == .kg ? v / kgPerLb : v
    }
}
