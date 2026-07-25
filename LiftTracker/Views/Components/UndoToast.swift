import SwiftUI

/// Bottom toast with a single reversal. Used after finishing a workout and
/// after deleting a session — the two writes that are otherwise unrecoverable.
struct UndoToast: View {
    let text: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Button("Undo", action: action)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.brand)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.controlTrack, in: Capsule())
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
