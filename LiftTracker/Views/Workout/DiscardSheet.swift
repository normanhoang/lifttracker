import SwiftUI

/// The missing exit. Today a mis-started session can only be ended by tapping
/// Finish — which writes it to history and advances your weights — or by
/// switching the A/B picker, which silently wipes the grid.
///
/// Built in-view rather than as `confirmationDialog`: the system dialog does not
/// expose its cancel row, and the whole point of this sheet is that the cancel
/// says "Keep logging".
struct DiscardSheet: View {
    let title: String
    let destructiveLabel: String
    let loggedSetCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .background(.ultraThinMaterial.opacity(0.5))
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        // Naming what does *not* happen is the point: the whole
                        // anxiety about this button is whether it touches the program.
                        Text("\(loggedSetCount) logged \(loggedSetCount == 1 ? "set" : "sets") will be deleted. No weights change and nothing is written to your history.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Rectangle().fill(Color.hairline).frame(height: 1)

                    Button(action: onConfirm) {
                        Text(destructiveLabel)
                            .font(.system(size: 19))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("confirmDiscard")
                }
                .background(Color(white: 0.15).opacity(0.94), in: RoundedRectangle(cornerRadius: 16))

                Button(action: onCancel) {
                    Text("Keep logging")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(white: 0.18).opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("keepLogging")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .transition(.opacity)
    }
}
