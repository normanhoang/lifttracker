import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var progress: [ExerciseProgress]
    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue

    @AppStorage(BarSetting.barLbKey) private var barLb = BarSetting.defaultBarLb
    @AppStorage(BarSetting.barKgKey) private var barKg = BarSetting.defaultBarKg
    @AppStorage(BarSetting.platesLbKey) private var platesLbCSV = BarSetting.csv(PlateMath.lbPlates)
    @AppStorage(BarSetting.platesKgKey) private var platesKgCSV = BarSetting.csv(PlateMath.kgPlates)

    @State private var editingExercise: Exercise?
    @State private var editingBar = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.top, 22)
                    unitRow
                    workingWeights
                    theBar
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.black)
        }
        .tint(.brand)
        .sheet(item: $editingExercise) { ex in
            LiftEditorSheet(exercise: ex, progress: progressRow(ex))
        }
        .sheet(isPresented: $editingBar) {
            NumberEditSheet(
                title: "Bar weight",
                unitLabel: unit.rawValue,
                step: unit == .kg ? 2.5 : 5,
                value: bar
            ) { newVal in
                if unit == .kg { barKg = newVal } else { barLb = newVal }
            }
        }
    }

    // MARK: - Unit

    private var unitRow: some View {
        HStack {
            Text("Weight unit").font(.body)
            Spacer()
            HStack(spacing: 2) {
                ForEach(WeightUnit.allCases) { u in
                    let selected = unitRaw == u.rawValue
                    Button { unitRaw = u.rawValue } label: {
                        Text(u.rawValue)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? AnyShapeStyle(.black) : AnyShapeStyle(.secondary))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selected ? Color.brand : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.card, in: Capsule())
            .frame(width: 128)
        }
    }

    // MARK: - Working weights

    private var workingWeights: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Renamed from "Starting Weights", which was a lie — it edits the
            // live working weight.
            sectionHeader("WORKING WEIGHTS", trailing: "weight · rest")
            VStack(spacing: 0) {
                ForEach(Array(Exercise.allCases.enumerated()), id: \.element) { index, ex in
                    Button { editingExercise = ex } label: { liftRow(ex) }
                        .buttonStyle(.plain)
                    if index < Exercise.allCases.count - 1 {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func liftRow(_ ex: Exercise) -> some View {
        let prog = progressRow(ex)
        let state = ProgressionCopy.settingsState(
            currentWeight: prog.currentWeight,
            nextWeight: Progression.nextWeight(prog, ex),
            deloadWeight: Progression.deloadWeight(prog),
            failStreak: prog.failStreak,
            hasLogged: prog.bestWeight > 0,
            incrementOverride: prog.incrementOverride,
            unit: unit
        )
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name).font(.body).foregroundStyle(.primary)
                Text(state.text)
                    .font(.caption)
                    .foregroundStyle(tone(state.tone))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(WeightFormat.string(prog.currentWeight, unit))
                .font(.body)
                .monospacedDigit()
            Text(prog.restSeconds == 0 ? "Off" : "\(prog.restSeconds)s")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - The bar

    private var theBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // This section is what makes the plate row on the workout card possible.
            sectionHeader("THE BAR", trailing: nil)
            VStack(spacing: 0) {
                Button { editingBar = true } label: {
                    HStack {
                        Text("Bar weight").font(.body).foregroundStyle(.primary)
                        Spacer()
                        Text("\(plateLabel(bar))\(unit.rawValue)")
                            .font(.body)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Rectangle().fill(Color.hairline).frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Plates you own").font(.body)
                        Spacer()
                        Text("per side").font(.subheadline).foregroundStyle(.tertiary)
                    }
                    plateGrid
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    /// One row when the set fits — the kg set (seven plates, "1.25" among them)
    /// does not, and a squeezed row wraps the chip text mid-number.
    private var plateGrid: some View {
        let all = BarSetting.allPlates(unit)
        return ViewThatFits(in: .horizontal) {
            plateChips(all)
            VStack(alignment: .leading, spacing: 8) {
                plateChips(Array(all.prefix((all.count + 1) / 2)))
                plateChips(Array(all.suffix(all.count / 2)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func plateChips(_ plates: [Double]) -> some View {
        let owned = Set(BarSetting.parse(platesCSV, unit: unit))
        return HStack(spacing: 8) {
            ForEach(plates, id: \.self) { plate in
                let isOwned = owned.contains(plate)
                Button { toggle(plate) } label: {
                    Text(plateLabel(plate))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundStyle(isOwned ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.tertiary))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isOwned ? Color.brand.opacity(0.14) : .clear))
                        .overlay(Capsule().strokeBorder(isOwned ? Color.brand.opacity(0.45) : Color.hairline))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, trailing: String?) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(0.85)
                .foregroundStyle(.tertiary)
            Spacer()
            if let trailing {
                Text(trailing).font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private func tone(_ t: ProgressionCopy.Tone) -> AnyShapeStyle {
        switch t {
        case .up: return AnyShapeStyle(Color.brand)
        case .warn: return AnyShapeStyle(Color.orange)
        case .neutral: return AnyShapeStyle(.secondary)
        }
    }

    private var bar: Double { unit == .kg ? barKg : barLb }

    private var platesCSV: String { unit == .kg ? platesKgCSV : platesLbCSV }

    private func plateLabel(_ plate: Double) -> String { PlateMath.label(plate) }

    private func toggle(_ plate: Double) {
        var owned = Set(BarSetting.parse(platesCSV, unit: unit))
        if owned.contains(plate) {
            owned.remove(plate)
        } else {
            owned.insert(plate)
        }
        let csv = BarSetting.csv(Array(owned))
        if unit == .kg { platesKgCSV = csv } else { platesLbCSV = csv }
    }

    private func progressRow(_ ex: Exercise) -> ExerciseProgress {
        if let p = progress.first(where: { $0.exerciseID == ex.rawValue }) { return p }
        let p = ExerciseProgress(exerciseID: ex.rawValue, currentWeight: ex.startingWeight)
        context.insert(p)
        return p
    }
}
