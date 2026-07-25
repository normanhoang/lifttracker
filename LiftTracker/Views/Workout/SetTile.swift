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

    /// Set when the hold fires, so releasing doesn't also log the set. Cleared
    /// when a new touch begins rather than after the tap, because a successful
    /// long press means no tap arrives to clear it.
    @State private var didHold = false

    var body: some View {
        // Deliberately not a Button: a Button consumes the whole touch sequence,
        // so a long-press gesture attached alongside it never recognises and the
        // press just fires the tap action on release.
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
            .contentShape(RoundedRectangle(cornerRadius: 16))
            // 0.42s: long enough that a hard tap with cold hands doesn't trigger
            // it, short enough to feel like a press rather than a wait.
            .onLongPressGesture(minimumDuration: 0.42) {
                didHold = true
                onHold()
            } onPressingChanged: { pressing in
                if pressing { didHold = false }
            }
            .onTapGesture {
                guard !didHold else { return }
                onTap()
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: reps)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(reps == nil ? "Set not logged" : "\(reps!) reps")
    }
}
