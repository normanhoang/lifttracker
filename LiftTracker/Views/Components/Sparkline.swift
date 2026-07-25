import SwiftUI

/// The whole logged history of a lift in 88×34pt. No axes, no labels — the
/// shape is the point.
struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let points = layout(in: geo.size)
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for p in points.dropFirst() { path.addLine(to: p) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(color)
                        .frame(width: 5.2, height: 5.2)
                        .position(last)
                }
            }
        }
        .frame(width: 88, height: 34)
        .accessibilityHidden(true)
    }

    private func layout(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else {
            return values.isEmpty ? [] : [CGPoint(x: size.width / 2, y: size.height / 2)]
        }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = max(hi - lo, 1)
        let inset: CGFloat = 3
        let usableH = size.height - inset * 2
        return values.enumerated().map { i, v in
            let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = inset + usableH * (1 - CGFloat((v - lo) / span))
            return CGPoint(x: min(max(x, inset), size.width - inset), y: y)
        }
    }
}
