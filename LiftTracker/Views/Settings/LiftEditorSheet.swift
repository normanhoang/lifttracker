import SwiftUI
import SwiftData

/// Everything about one lift in one sheet: the three numbers that define how
/// the program treats it. Replaces `NumberEditSheet` for lifts — that sheet is
/// generic and does one of them.
struct LiftEditorSheet: View {
    let exercise: Exercise
    @Bindable var progress: ExerciseProgress

    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var manuallyEdited = false

    private static let restOptions = [0, 60, 90, 120, 180]

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }
    private var step: Double { progress.increment(for: exercise) }
    private var incrementOptions: [Double] {
        unit == .kg ? [1.25, 2.5, 5] : [2.5, 5, 10]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stepperRow
                    PlateRow(weightLb: progress.currentWeight, unit: unit)
                    segmented("ADD AFTER A CLEAN 5×5",
                              options: incrementOptions,
                              selection: incrementBinding) { WeightFormat.string($0, unit) }
                    segmented("REST BETWEEN SETS",
                              options: Self.restOptions,
                              selection: $progress.restSeconds) { $0 == 0 ? "Off" : "\($0)s" }
                    Button("Reset \(exercise.name) to \(WeightFormat.string(exercise.startingWeight, unit))",
                           role: .destructive, action: reset)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.card)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(exercise.name).font(.headline)
                        Text(state.text)
                            .font(.caption)
                            .foregroundStyle(stateColor)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save(); dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(.brand)
    }

    // MARK: - Sections

    private var stepperRow: some View {
        HStack {
            circleButton("minus", tint: Color(.tertiaryLabel)) { adjust(-1) }
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                Text(ProgressionCopy.plain(progress.currentWeight, unit))
                    .font(.system(size: 42, weight: .semibold))
                    .monospacedDigit()
                    .tracking(-1.2)
                Text("working weight · \(unit.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            circleButton("plus", tint: .brand) { adjust(1) }
        }
    }

    private func circleButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint == .brand ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.secondary))
                .frame(width: 52, height: 52)
                .overlay(Circle().strokeBorder(tint, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "Increase weight" : "Decrease weight")
    }

    private func segmented<T: Hashable>(_ title: String,
                                        options: [T],
                                        selection: Binding<T>,
                                        label: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
            HStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    let selected = selection.wrappedValue == option
                    Button { selection.wrappedValue = option } label: {
                        Text(label(option))
                            .font(.footnote.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? AnyShapeStyle(.black) : AnyShapeStyle(.secondary))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selected ? Color.brand : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.black, in: Capsule())
        }
    }

    // MARK: - State line

    private var state: ProgressionCopy.Note {
        ProgressionCopy.settingsState(
            currentWeight: progress.currentWeight,
            nextWeight: Progression.nextWeight(progress, exercise),
            deloadWeight: Progression.deloadWeight(progress),
            failStreak: progress.failStreak,
            hasLogged: progress.bestWeight > 0,
            incrementOverride: progress.incrementOverride,
            unit: unit
        )
    }

    private var stateColor: Color {
        switch state.tone {
        case .up: return .brand
        case .warn: return .orange
        case .neutral: return Color(.secondaryLabel)
        }
    }

    // MARK: - Editing

    private var incrementBinding: Binding<Double> {
        Binding(
            get: { WeightFormat.fromLb(step, unit) },
            set: { progress.incrementOverride = WeightFormat.toLb($0, unit) }
        )
    }

    private func adjust(_ direction: Double) {
        let next = progress.currentWeight + direction * step
        progress.currentWeight = max(step, next)
        manuallyEdited = true
    }

    private func reset() {
        progress.currentWeight = exercise.startingWeight
        progress.failStreak = 0
        progress.successStreak = 0
        manuallyEdited = false
        save()
        dismiss()
    }

    /// A hand-set weight is a new starting point. Leaving the streak alone let a
    /// manual edit deload from failures at the *old* weight.
    private func save() {
        if manuallyEdited {
            progress.failStreak = 0
            progress.successStreak = 0
        }
        do { try context.save() } catch {
            print("LiftEditorSheet: failed to save: \(error)")
        }
    }
}
