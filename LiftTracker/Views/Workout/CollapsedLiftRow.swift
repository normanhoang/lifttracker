import SwiftUI

/// A lift that isn't the active one: one line, done above, still-to-come below.
struct CollapsedLiftRow: View {
    enum State {
        case done(clean: Bool)
        case skipped
        case upcoming
    }

    let name: String
    let detail: String
    let state: State
    var symbol: String?          // body-weight row uses a scale glyph
    var onTap: (() -> Void)?

    private var background: Color {
        switch state {
        case .done, .skipped: return .rowDone
        case .upcoming: return .rowUpcoming
        }
    }

    private var borderOpacity: Double {
        switch state {
        case .done, .skipped: return 0.35
        case .upcoming: return 0.28
        }
    }

    var body: some View {
        Button { onTap?() } label: {
            HStack(spacing: 12) {
                glyph
                Text(name)
                    .font(.body)
                    .foregroundStyle(isSkipped ? .tertiary : .secondary)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(detailStyle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 46)
            .background(background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.hairline.opacity(borderOpacity), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    private var isSkipped: Bool { if case .skipped = state { return true }; return false }

    private var detailStyle: HierarchicalShapeStyle {
        switch state {
        case .done: return .secondary
        case .skipped, .upcoming: return .tertiary
        }
    }

    @ViewBuilder private var glyph: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.tertiary)
                .frame(width: 20, height: 20)
        } else {
            switch state {
            case .done(let clean):
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(clean ? Color.brand : .orange)
                    .frame(width: 20, height: 20)
            case .skipped:
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, height: 20)
            case .upcoming:
                Circle()
                    .strokeBorder(Color(.tertiaryLabel), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
            }
        }
    }
}
