import SwiftUI
import SwiftData

/// "How am I doing" without tapping into anything.
struct ProgressScreen: View {
    @Environment(\.modelContext) private var context
    @Query private var progress: [ExerciseProgress]
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @Query(sort: \BodyWeightEntry.date) private var bodyWeights: [BodyWeightEntry]
    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue
    @AppStorage("lastBodyWeight") private var lastBodyWeight = 0.0

    @State private var loggingBodyWeight = false
    @State private var selected: Exercise?

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    headerBlock
                    ForEach(Exercise.allCases) { ex in
                        liftRow(ex)
                    }
                    totalRow.padding(.top, 4)
                    bodyWeightRow
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.black)
            .navigationDestination(item: $selected) { ex in
                LiftDetailView(exercise: ex,
                               series: LiftSeries(exerciseID: ex.rawValue, sessions: sessions),
                               progress: row(ex),
                               unit: unit)
            }
        }
        .tint(.brand)
        .sheet(isPresented: $loggingBodyWeight) {
            NumberEditSheet(
                title: "Body Weight",
                unitLabel: unit.rawValue,
                step: unit == .kg ? 0.5 : 1,
                value: WeightFormat.fromLb(latestBodyWeight ?? lastBodyWeight, unit)
            ) { newVal in
                let lb = WeightFormat.toLb(newVal, unit)
                context.insert(BodyWeightEntry(date: .now, weightLb: lb))
                lastBodyWeight = lb
                try? context.save()
            }
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Progress")
                .font(.largeTitle.bold())
                .padding(.top, 20)
            HStack(spacing: 0) {
                Text(summaryPrefix)
                Text(totalDelta == 0 ? "" : " \(signed(totalDelta))")
                    .foregroundStyle(.brand)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 6)
    }

    private var summaryPrefix: String {
        let weeks = allSeries.map { $0.weeks() }.max() ?? 0
        let sessionText = "\(sessions.count) \(sessions.count == 1 ? "session" : "sessions")"
        guard weeks > 0 else { return sessionText }
        return "\(weeks) \(weeks == 1 ? "week" : "weeks") · \(sessionText) · SBD \(WeightFormat.string(total, unit))"
    }

    // MARK: - Rows

    private func liftRow(_ ex: Exercise) -> some View {
        let series = LiftSeries(exerciseID: ex.rawValue, sessions: sessions)
        let prog = row(ex)
        let state = series.state(failStreak: prog?.failStreak ?? 0,
                                 hitBestToday: hitBestToday(ex),
                                 unit: unit)
        return Button { selected = ex } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ex.name).font(.headline)
                    Text(state.text)
                        .font(.footnote)
                        .foregroundStyle(tint(state.tone))
                }
                Spacer(minLength: 4)
                Sparkline(values: series.points.map(\.weightLb), color: sparkColor(state.tone))
                VStack(alignment: .trailing, spacing: 2) {
                    Text(WeightFormat.string(weight(ex), unit))
                        .font(.system(size: 19, weight: .semibold))
                        .monospacedDigit()
                    Text(deltaText(series))
                        .font(.caption)
                        .foregroundStyle(series.delta > 0 ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.tertiary))
                }
                .frame(minWidth: 62, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(state.tone == .warn ? Color.orange.opacity(0.35) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var totalRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SBD total").font(.headline)
                // The arithmetic replaces the old explanatory footnote entirely.
                Text(Exercise.allCases.filter(\.countsTowardTotal)
                    .map { ProgressionCopy.plain(weight($0), unit) }
                    .joined(separator: " + "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(WeightFormat.string(total, unit))
                    .font(.system(size: 19, weight: .semibold))
                    .monospacedDigit()
                if totalDelta != 0 {
                    Text("\(signed(totalDelta)) · \(maxWeeks)wk")
                        .font(.caption)
                        .foregroundStyle(.brand)
                }
            }
            .frame(minWidth: 62, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var bodyWeightRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Body weight").font(.headline)
                Text(lastWeighInText).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Sparkline(values: bodyWeights.map(\.weightLb), color: Color(.systemGray))
            Text(latestBodyWeight.map { WeightFormat.string($0, unit) } ?? "—")
                .font(.system(size: 19, weight: .semibold))
                .monospacedDigit()
            Button { loggingBodyWeight = true } label: {
                Text("Log")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(Capsule().strokeBorder(Color.brand, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Data

    private var allSeries: [LiftSeries] {
        Exercise.allCases.map { LiftSeries(exerciseID: $0.rawValue, sessions: sessions) }
    }

    private var maxWeeks: Int { allSeries.map { $0.weeks() }.max() ?? 0 }

    private func row(_ ex: Exercise) -> ExerciseProgress? {
        progress.first { $0.exerciseID == ex.rawValue }
    }

    private func weight(_ ex: Exercise) -> Double {
        row(ex)?.currentWeight ?? ex.startingWeight
    }

    private var total: Double {
        Exercise.allCases.filter(\.countsTowardTotal).reduce(0) { $0 + weight($1) }
    }

    private var totalDelta: Double {
        Exercise.allCases.filter(\.countsTowardTotal)
            .reduce(0) { $0 + LiftSeries(exerciseID: $1.rawValue, sessions: sessions).delta }
    }

    private var latestBodyWeight: Double? { bodyWeights.last?.weightLb }

    private var lastWeighInText: String {
        guard let date = bodyWeights.last?.date else { return "not logged yet" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date),
                                                   to: Calendar.current.startOfDay(for: .now)).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        return "\(days) days ago"
    }

    private func hitBestToday(_ ex: Exercise) -> Bool {
        guard let latest = sessions.last,
              Calendar.current.isDateInToday(latest.date),
              let logged = latest.exercises.first(where: { $0.exerciseID == ex.rawValue })
        else { return false }
        return logged.isPR
    }

    private func deltaText(_ series: LiftSeries) -> String {
        guard series.delta != 0 else {
            return "flat · \(series.flatWeeks() ?? 0)wk"
        }
        return "\(signed(series.delta)) · \(series.weeks())wk"
    }

    private func signed(_ lb: Double) -> String {
        let v = WeightFormat.fromLb(lb, unit)
        let n = v.rounded() == v ? String(Int(v.magnitude)) : String(format: "%.1f", v.magnitude)
        return "\(v < 0 ? "−" : "+")\(n)"
    }

    private func tint(_ tone: ProgressionCopy.Tone) -> AnyShapeStyle {
        switch tone {
        case .up: return AnyShapeStyle(Color.brand)
        case .warn: return AnyShapeStyle(Color.orange)
        case .neutral: return AnyShapeStyle(.secondary)
        }
    }

    private func sparkColor(_ tone: ProgressionCopy.Tone) -> Color {
        switch tone {
        case .up: return .brand
        case .warn: return .orange
        case .neutral: return Color(.systemGray)
        }
    }
}
