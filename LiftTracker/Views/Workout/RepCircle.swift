import SwiftUI

/// A single tappable rep circle.
struct RepCircle: View {
    let state: SetState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(state.display)")
                .font(.title2)
                .foregroundStyle(state.highlighted ? .white : .secondary)
                .frame(width: 60, height: 60)
                .background(
                    Circle().fill(state.highlighted
                                  ? Color.red
                                  : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: state)
    }
}
