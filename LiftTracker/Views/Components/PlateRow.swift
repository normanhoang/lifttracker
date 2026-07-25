import SwiftUI

/// "PER SIDE 45 25 + 45lb bar". Turns amber when the weight can't be built from
/// the plates you own, so an unloadable number is visible before you walk to the rack.
struct PlateRow: View {
    let weightLb: Double
    let unit: WeightUnit
    /// Compact form for the workout card; the lift editor shows the fallback weight.
    var showsClosest = true

    private var config: (bar: Double, plates: [Double]) { BarSetting.current(unit) }
    private var total: Double { WeightFormat.fromLb(weightLb, unit) }

    private var plates: [Double] {
        PlateMath.perSide(total: total, bar: config.bar, available: config.plates)
    }

    private var loadable: Bool {
        PlateMath.isLoadable(total: total, bar: config.bar, available: config.plates)
    }

    private var tint: Color { loadable ? .brand : .orange }

    var body: some View {
        HStack(spacing: 7) {
            Text("PER SIDE")
                .font(.caption2)
                .tracking(0.8)
                .foregroundStyle(.tertiary)

            ForEach(Array(plates.enumerated()), id: \.offset) { _, p in
                Text(number(p))
                    .font(.caption.bold())
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tint.opacity(0.14)))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.45)))
                    .foregroundStyle(tint)
            }

            if !loadable, showsClosest {
                let near = PlateMath.closestLoadable(to: total, bar: config.bar, available: config.plates)
                Text("closest loadable: \(number(near))")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else {
                Text("+ \(number(config.bar))\(unit.rawValue) bar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }

    private func number(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.2g", v)
    }
}
