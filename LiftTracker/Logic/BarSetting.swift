import Foundation

/// The bar and the plates you own. Device-level, so it lives in UserDefaults
/// alongside "unit" rather than in the store.
///
/// Stored per unit rather than converted: a metric gym has a 20kg bar and
/// 25/20/15/10/5/2.5/1.25 plates, which is not the pound set run through a
/// conversion.
enum BarSetting {
    static let barLbKey = "barWeightLb"
    static let barKgKey = "barWeightKg"
    static let platesLbKey = "ownedPlatesLbCSV"
    static let platesKgKey = "ownedPlatesKgCSV"

    static let defaultBarLb = 45.0
    static let defaultBarKg = 20.0

    static func defaultBar(_ unit: WeightUnit) -> Double {
        unit == .kg ? defaultBarKg : defaultBarLb
    }

    static func barKey(_ unit: WeightUnit) -> String {
        unit == .kg ? barKgKey : barLbKey
    }

    static func platesKey(_ unit: WeightUnit) -> String {
        unit == .kg ? platesKgKey : platesLbKey
    }

    static func allPlates(_ unit: WeightUnit) -> [Double] {
        unit == .kg ? PlateMath.kgPlates : PlateMath.lbPlates
    }

    static func defaultPlatesCSV(_ unit: WeightUnit) -> String {
        csv(allPlates(unit))
    }

    /// Owned plates, heaviest first. An unparseable or empty store falls back to
    /// the full set rather than leaving the user with no plates at all.
    static func parse(_ csv: String, unit: WeightUnit) -> [Double] {
        let values = csv.split(separator: ",").compactMap { Double($0) }
        return values.isEmpty ? allPlates(unit) : values.sorted(by: >)
    }

    /// The bar and owned plates as currently configured, in `unit`.
    static func current(_ unit: WeightUnit, defaults: UserDefaults = .standard) -> (bar: Double, plates: [Double]) {
        let stored = defaults.double(forKey: barKey(unit))
        let bar = stored > 0 ? stored : defaultBar(unit)
        let csv = defaults.string(forKey: platesKey(unit)) ?? defaultPlatesCSV(unit)
        return (bar, parse(csv, unit: unit))
    }

    static func csv(_ plates: [Double]) -> String {
        plates.sorted(by: >)
            .map { $0 == $0.rounded() ? String(Int($0)) : String($0) }
            .joined(separator: ",")
    }
}
