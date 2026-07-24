import SwiftUI
import Charts

/// One lift over time. The series is a step line, not a smooth curve: a 5×5
/// program holds a weight for several sessions and then jumps, and interpolation
/// draws through weights that were never lifted while hiding the plateaus that
/// are the only interesting feature of the chart.
struct LiftDetailView: View {
    let exercise: Exercise
    let series: LiftSeries
    let progress: ExerciseProgress?
    let unit: WeightUnit

    @State private var range: Range = .threeMonths
    @State private var selectedDate: Date?

    enum Range: String, CaseIterable, Identifiable {
        case sixWeeks = "6w", threeMonths = "3m", sixMonths = "6m", all = "All"
        var id: String { rawValue }
        var months: Int? {
            switch self {
            case .sixWeeks: return 2
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .all: return nil
            }
        }
    }

    private var windowed: LiftSeries { series.windowed(range.months) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headline
                rangePicker
                chart
                statCards
                interpretation
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.black)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(ProgressionCopy.plain(current, unit))
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .tracking(-1.2)
            Text("\(unit.rawValue) working")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(state.text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(stateColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(stateColor.opacity(0.16)))
        }
        .padding(.top, 8)
    }

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(Range.allCases) { r in Text(r.rawValue).tag(r) }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var chart: some View {
        if windowed.points.count < 2 {
            emptyChart
        } else {
            Chart {
                ForEach(Array(windowed.points.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("Date", p.date),
                             y: .value("Weight", WeightFormat.fromLb(p.weightLb, unit)))
                        .foregroundStyle(.brand)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                        .interpolationMethod(.stepEnd)
                }
                ForEach(Array(windowed.points.enumerated()), id: \.offset) { _, p in
                    if p.missed {
                        PointMark(x: .value("Date", p.date),
                                  y: .value("Weight", WeightFormat.fromLb(p.weightLb, unit)))
                            .symbol { missedSymbol }
                            .annotation(position: .top) {
                                Text("missed \(exercise == .deadlift ? "1×5" : "5×5")")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                    }
                }
                if let best = windowed.points.max(by: { $0.weightLb < $1.weightLb }) {
                    PointMark(x: .value("Date", best.date),
                              y: .value("Weight", WeightFormat.fromLb(best.weightLb, unit)))
                        .foregroundStyle(.brand)
                        .symbolSize(45)
                        .annotation(position: .top) {
                            Text("best").font(.caption2).foregroundStyle(.brand)
                        }
                }
                if let sel = selectedPoint {
                    RuleMark(x: .value("Date", sel.date))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .top,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(spacing: 2) {
                                Text(sel.date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(WeightFormat.string(sel.weightLb, unit))
                                    .font(.caption.bold())
                            }
                            .padding(6)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                }
            }
            .chartYScale(domain: yDomain)
            .chartXSelection(value: $selectedDate)
            .frame(height: 300)
        }
    }

    private var missedSymbol: some View {
        Circle()
            .fill(Color.black)
            .overlay(Circle().strokeBorder(Color.orange, lineWidth: 2.2))
            .frame(width: 9, height: 9)
    }

    private var emptyChart: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("Log two sessions to see a trend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var statCards: some View {
        HStack(spacing: 10) {
            statCard("All-time best", WeightFormat.string(series.best ?? current, unit), emerald: false)
            statCard("\(series.weeks()) weeks", signed(series.delta), emerald: series.delta > 0)
            statCard("Sessions", "\(series.points.count)", emerald: false)
        }
    }

    private func statCard(_ label: String, _ value: String, emerald: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(emerald ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.primary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var interpretation: some View {
        HStack(spacing: 10) {
            Image(systemName: series.missCount > 0 ? "circle.dotted" : "checkmark")
                .foregroundStyle(series.missCount > 0 ? Color.orange : Color.brand)
            Text(interpretationText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var interpretationText: String {
        let n = series.points.count
        guard n > 0 else { return "Nothing logged yet" }
        let misses = series.missCount == 0
            ? "No missed sessions in \(n)"
            : "\(series.missCount) missed \(series.missCount == 1 ? "session" : "sessions") in \(n)"
        let deloads = series.deloadCount == 0
            ? "no deloads yet"
            : "\(series.deloadCount) \(series.deloadCount == 1 ? "deload" : "deloads")"
        return "\(misses) · \(deloads)"
    }

    // MARK: - Data

    private var current: Double { progress?.currentWeight ?? series.current ?? exercise.startingWeight }

    private var state: ProgressionCopy.Note {
        series.state(failStreak: progress?.failStreak ?? 0, hitBestToday: false, unit: unit)
    }

    private var stateColor: Color {
        switch state.tone {
        case .up: return .brand
        case .warn: return .orange
        case .neutral: return Color(.systemGray)
        }
    }

    private var selectedPoint: LiftSeries.Point? {
        guard let selectedDate else { return nil }
        return windowed.points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    /// Padded so the line doesn't hug the chart edges.
    private var yDomain: ClosedRange<Double> {
        let values = windowed.points.map { WeightFormat.fromLb($0.weightLb, unit) }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.15, 5)
        return (lo - pad)...(hi + pad)
    }

    private func signed(_ lb: Double) -> String {
        let v = WeightFormat.fromLb(lb, unit)
        let n = v.rounded() == v ? String(Int(v.magnitude)) : String(format: "%.1f", v.magnitude)
        return "\(v < 0 ? "−" : "+")\(n)\(unit.rawValue)"
    }
}
