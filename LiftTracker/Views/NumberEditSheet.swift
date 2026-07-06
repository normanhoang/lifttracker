import SwiftUI

/// A small sheet for editing a single numeric value: type on the numpad or use +/- steppers.
struct NumberEditSheet: View {
    let title: String
    let unitLabel: String
    let step: Double
    @State var value: Double
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var text: String = ""

    private static func format(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                HStack(spacing: 24) {
                    Button { adjust(-step) } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 44))
                    }
                    VStack {
                        TextField("0", text: $text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 52, weight: .bold))
                            .focused($focused)
                            .fixedSize()
                            .onChange(of: text) { _, newValue in
                                if let v = Double(newValue) { value = v }
                            }
                        Text(unitLabel).foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 140)
                    Button { adjust(step) } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 44))
                    }
                }
                .tint(.red)
                Spacer()
            }
            .padding(.top, 48)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(Double(text) ?? value); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { text = Self.format(value) }
    }

    private func adjust(_ delta: Double) {
        value = max(0, value + delta)
        text = Self.format(value)
    }
}
