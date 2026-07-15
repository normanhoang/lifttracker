import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var progress: [ExerciseProgress]
    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue
    @AppStorage(RestDurationSetting.key) private var restDurationSeconds = RestDurationSetting.defaultValue

    @State private var editingExercise: Exercise?

    private static let restDurationOptions: [Double] = [30, 45, 60, 90, 120, 180]

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    private func weight(_ ex: Exercise) -> Double {
        progress.first { $0.exerciseID == ex.rawValue }?.currentWeight ?? ex.startingWeight
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Weight Unit", selection: $unitRaw) {
                        ForEach(WeightUnit.allCases) { u in
                            Text(u.rawValue).tag(u.rawValue)
                        }
                    }
                    Picker("Rest Duration", selection: $restDurationSeconds) {
                        Text("Off").tag(RestDurationSetting.offValue)
                        ForEach(Self.restDurationOptions, id: \.self) { seconds in
                            Text("\(Int(seconds))s").tag(seconds)
                        }
                    }
                }

                Section("Starting Weights") {
                    ForEach(Exercise.allCases) { ex in
                        Button {
                            editingExercise = ex
                        } label: {
                            HStack {
                                Text(ex.name).foregroundStyle(.primary)
                                Spacer()
                                Text(WeightFormat.string(weight(ex), unit))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .tint(.brand)
        .sheet(item: $editingExercise) { ex in
            NumberEditSheet(
                title: ex.name,
                unitLabel: unit.rawValue,
                step: unit == .kg ? 2.5 : 5,
                value: WeightFormat.fromLb(weight(ex), unit)
            ) { newVal in
                setWeight(ex, WeightFormat.toLb(newVal, unit))
            }
        }
    }

    private func setWeight(_ ex: Exercise, _ lb: Double) {
        if let p = progress.first(where: { $0.exerciseID == ex.rawValue }) {
            p.currentWeight = lb
        } else {
            context.insert(ExerciseProgress(exerciseID: ex.rawValue, currentWeight: lb))
        }
        try? context.save()
    }
}
