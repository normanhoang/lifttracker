import SwiftUI

extension Color {
    /// App accent — emerald.
    static let brand = Color(red: 0.19, green: 0.84, blue: 0.55)

    /// Card ground, #1C1C1E.
    static let card = Color(.secondarySystemBackground)
    /// Segmented-control track and picker buttons, #2C2C2E.
    static let controlTrack = Color(.tertiarySystemBackground)
    /// Neutral selected segment, #636366.
    static let selectedSegment = Color(.systemGray2)
    /// Collapsed row for a lift already done, #101010.
    static let rowDone = Color(white: 0.063)
    /// Collapsed row for a lift still to come, #0B0B0B.
    static let rowUpcoming = Color(white: 0.043)
    /// Hairlines and tile borders.
    static let hairline = Color(.separator)
}

/// Lets `.brand` work in `foregroundStyle`, `background`, etc.
extension ShapeStyle where Self == Color {
    static var brand: Color { .brand }
}
