import SwiftUI

/// One set in the active lift card. Tap logs the target; press-and-hold opens
/// the picker. The old tap-cycle is gone — fixing a mis-tap used to cost six
/// taps and every intermediate value was a real logged rep count.
struct SetTile: View {
    let reps: Int?
    let target: Int
    let isNext: Bool
    let onTap: () -> Void
    let onHold: () -> Void

    private var isDone: Bool { reps == target }
    private var isPartial: Bool { reps != nil && reps != target }

    private var fill: Color {
        if isDone { return .brand }
        if isPartial { return .orange }
        if isNext { return .brand.opacity(0.10) }
        return .black
    }

    private var digitColor: Color {
        if isDone || isPartial { return .black }
        if isNext { return .brand }
        return Color(.tertiaryLabel)
    }

    private var border: (Color, CGFloat) {
        if isNext { return (.brand, 2) }
        if isDone || isPartial { return (.clear, 0) }
        return (.hairline, 1)
    }

    var body: some View {
        Button(action: onTap) {
            Text("\(reps ?? target)")
                .font(.title2)
                .fontWeight(isDone || isPartial || isNext ? .semibold : .regular)
                .monospacedDigit()
                .foregroundStyle(digitColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 58)
                .background(RoundedRectangle(cornerRadius: 16).fill(fill))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(border.0, lineWidth: border.1)
                )
        }
        .buttonStyle(.plain)
        // 0.42s: long enough that a hard tap with cold hands doesn't trigger it,
        // short enough to feel like a press rather than a wait.
        .onLongPressGesture(minimumDuration: 0.42, perform: onHold)
        .sensoryFeedback(.impact(weight: .medium), trigger: reps)
        .accessibilityLabel(reps == nil ? "Set not logged" : "\(reps!) reps")
    }
}
