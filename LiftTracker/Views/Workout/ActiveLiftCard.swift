import SwiftUI

/// The one expanded lift. Everything you need with a loaded bar in front of
/// you: what it is, what's on it, which set is next.
struct ActiveLiftCard: View {
    let lift: DraftLift
    let unit: WeightUnit
    let note: ProgressionCopy.Note?
    let increment: Double
    let onStep: (Double) -> Void
    let onTapSet: (Int) -> Void
    let onHoldSet: (Int) -> Void
    let onUndo: () -> Void

    private var noteColor: Color {
        switch note?.tone {
        case .up: return .brand
        case .warn: return .orange
        default: return Color(.secondaryLabel)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            PlateRow(weightLb: lift.weightLb, unit: unit, showsClosest: false)
            tiles
            footer
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.brand.opacity(0.28), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lift.name)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                if let note {
                    Text(note.text)
                        .font(.subheadline)
                        .foregroundStyle(noteColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 8) {
                Text(WeightFormat.string(lift.weightLb, unit))
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
                    .tracking(-0.6)
                HStack(spacing: 10) {
                    stepper("minus") { onStep(-increment) }
                    stepper("plus") { onStep(increment) }
                }
            }
        }
    }

    private func stepper(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Color(.tertiaryLabel), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "Increase weight" : "Decrease weight")
    }

    private var tiles: some View {
        HStack(spacing: 10) {
            ForEach(lift.reps.indices, id: \.self) { i in
                SetTile(
                    reps: lift.reps[i],
                    target: lift.targetReps,
                    isNext: lift.nextIndex == i,
                    onTap: { onTapSet(i) },
                    onHold: { onHoldSet(i) }
                )
                .accessibilityIdentifier("repCircle.\(lift.exerciseID).\(i)")
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Tap to log \(lift.targetReps) · hold to pick reps")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 8)
            if lift.loggedCount > 0 {
                Button("Undo last set", action: onUndo)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.brand)
                    .accessibilityIdentifier("undoLastSet")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}
