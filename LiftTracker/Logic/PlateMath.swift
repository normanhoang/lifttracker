import Foundation

/// Bar loading. Pure arithmetic in whatever unit the caller is working in —
/// callers convert the stored pounds to the display unit first, because a
/// 20.4kg plate does not exist and a plate row that shows one is useless at a rack.
enum PlateMath {
    static let lbPlates: [Double] = [45, 35, 25, 10, 5, 2.5]
    static let kgPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    private static let epsilon = 0.001

    /// Plates for ONE side, heaviest first. Empty when the weight is the bare bar.
    /// `available` is the subset the user owns (Settings → The bar).
    static func perSide(total: Double, bar: Double, available: [Double]) -> [Double] {
        var remaining = (total - bar) / 2
        guard remaining > epsilon else { return [] }
        var out: [Double] = []
        for p in available.sorted(by: >) where p > 0 {
            while remaining >= p - epsilon {
                out.append(p)
                remaining -= p
            }
        }
        return out
    }

    /// True when `perSide` accounts for the whole weight — drives the amber
    /// "closest loadable" state in the lift editor.
    static func isLoadable(total: Double, bar: Double, available: [Double]) -> Bool {
        guard total >= bar - epsilon else { return false }
        let sum = perSide(total: total, bar: bar, available: available).reduce(0, +)
        return abs(bar + sum * 2 - total) < epsilon
    }

    /// Nearest loadable weight at or below `total`, never below the bar.
    ///
    /// This is just what the greedy load actually adds up to: stepping down by
    /// the smallest plate would miss, because loadable weights sit on a
    /// 2×plate lattice (a 5lb plate moves the bar 10lb, so 187.5 can only fall
    /// back to 185, never 182.5).
    static func closestLoadable(to total: Double, bar: Double, available: [Double]) -> Double {
        let perSideSum = perSide(total: total, bar: bar, available: available).reduce(0, +)
        return max(bar, bar + perSideSum * 2)
    }
}
