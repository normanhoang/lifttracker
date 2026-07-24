import SwiftUI

/// The countdown between sets. Counts *down* against the lift's target, so
/// "am I ready" is a glance rather than a calculation. At zero it flips to a go
/// state and counts overtime up quietly.
struct RestStrip: View {
    let endDate: Date
    let targetSeconds: Int
    let liftName: String
    let setNumber: Int
    let weightText: String
    let onAdd: () -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = endDate.timeIntervalSince(context.date)
            content(remaining: remaining)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func content(remaining: TimeInterval) -> some View {
        HStack(spacing: 14) {
            ring(remaining: remaining)
            if remaining > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clock(remaining))
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                    Text("\(liftName) · set \(setNumber) next")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                capsuleButton("+30s", tint: .brand, action: onAdd)
                capsuleButton("Skip", tint: Color(.tertiaryLabel), action: onSkip)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go — set \(setNumber)")
                        .font(.headline)
                        .foregroundStyle(.brand)
                    Text(weightText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("+\(clock(-remaining))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                capsuleButton("Skip", tint: Color(.tertiaryLabel), action: onSkip)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func ring(remaining: TimeInterval) -> some View {
        if remaining > 0 {
            let fraction = max(0, min(1, remaining / Double(max(targetSeconds, 1))))
            ZStack {
                Circle()
                    .stroke(Color.controlTrack, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 46, height: 46)
        } else {
            ZStack {
                Circle().fill(Color.brand.opacity(0.25))
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.brand)
            }
            .frame(width: 46, height: 46)
        }
    }

    private func capsuleButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint == .brand ? Color.brand : Color(.secondaryLabel))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(tint, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
