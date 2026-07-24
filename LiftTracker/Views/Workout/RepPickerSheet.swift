import SwiftUI

/// Press-and-hold (or tap an already-logged tile) to say what actually happened.
/// The only place a rep count other than the target gets entered.
struct RepPickerSheet: View {
    let liftName: String
    let setNumber: Int
    let target: Int
    let isLogged: Bool
    let onPick: (Int) -> Void
    let onClear: () -> Void
    let onSkipLift: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(liftName) · set \(setNumber)")
                    .font(.system(size: 20, weight: .semibold))
                Text("How many reps did you actually get?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(0...target, id: \.self) { n in
                    Button {
                        onPick(n)
                        dismiss()
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.controlTrack, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("repPicker.\(n)")
                }
            }

            VStack(spacing: 12) {
                if isLogged {
                    Button("Clear this set") {
                        onClear()
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                }
                Button("Skip \(liftName) today") {
                    onSkipLift()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium])
        .presentationBackground(Color.card)
    }
}
