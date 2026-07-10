import SwiftUI

extension Color {
    /// App accent — emerald.
    static let brand = Color(red: 0.19, green: 0.84, blue: 0.55)
}

/// Lets `.brand` work in `foregroundStyle`, `background`, etc.
extension ShapeStyle where Self == Color {
    static var brand: Color { .brand }
}
