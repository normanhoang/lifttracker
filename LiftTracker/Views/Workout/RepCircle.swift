import SwiftUI

/// A single tappable rep tile.
struct RepCircle: View {
    let state: SetState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(state.display)")
                .font(.title2)
                .foregroundStyle(state.highlighted ? .black : .secondary)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(state.highlighted
                              ? Color.brand
                              : Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(.tertiaryLabel), lineWidth: state.highlighted ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: state)
    }
}
