import SwiftUI
import SwiftData
import Charts

struct ProgressScreen: View {
    @Query private var progress: [ExerciseProgress]
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    private func weight(_ ex: Exercise) -> Double {
        progress.first { $0.exerciseID == ex.rawValue }?.currentWeight ?? ex.startingWeight
    }

    /// Squat + Bench + Deadlift.
    private var total: Double {
        Exercise.allCases.filter(\.countsTowardTotal).reduce(0) { $0 + weight($1) }
    }

    private var latestBodyWeight: Double? {
        sessions.compactMap(\.bodyWeight).last
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Exercise.allCases) { ex in
                        NavigationLink {
                            ExerciseChart(exercise: ex, sessions: sessions, unit: unit)
                        } label: {
                            row(ex.name, WeightFormat.string(weight(ex), unit))
                        }
                    }
                }
                Section {
                    row("Total", WeightFormat.string(total, unit))
                } footer: {
                    Text("Total represents the sum of your Squat, Bench & Deadlift.")
                }
                Section {
                    NavigationLink {
                        BodyWeightChart(sessions: sessions, unit: unit)
                    } label: {
                        row("Body Weight",
                            latestBodyWeight.map { WeightFormat.string($0, unit) } ?? "—")
                    }
                }
            }
            .navigationTitle("Progress")
        }
        .tint(.brand)
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Line chart of an exercise's logged weight over time.
private struct ExerciseChart: View {
    let exercise: Exercise
    let sessions: [WorkoutSession]
    let unit: WeightUnit

    var body: some View {
        TrendChart(title: exercise.name, unitLabel: unit.rawValue, points: sessions.compactMap { s in
            guard let logged = s.exercises.first(where: { $0.exerciseID == exercise.rawValue }),
                  !logged.isSkipped else { return nil }
            return WeightPoint(date: s.date, weight: WeightFormat.fromLb(logged.weight, unit))
        })
    }
}

/// Line chart of the body weight logged with each session.
private struct BodyWeightChart: View {
    let sessions: [WorkoutSession]
    let unit: WeightUnit

    var body: some View {
        TrendChart(title: "Body Weight", unitLabel: unit.rawValue, points: sessions.compactMap { s in
            s.bodyWeight.map { WeightPoint(date: s.date, weight: WeightFormat.fromLb($0, unit)) }
        })
    }
}

private struct WeightPoint: Identifiable {
    let date: Date
    let weight: Double
    var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Shared weight-over-time line chart with drag-to-read scrubbing.
private struct TrendChart: View {
    let title: String
    let unitLabel: String
    let points: [WeightPoint]

    @State private var selectedDate: Date?

    private var selectedPoint: WeightPoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    /// Padded so the line doesn't hug the chart edges.
    private var yDomain: ClosedRange<Double> {
        guard let lo = points.map(\.weight).min(),
              let hi = points.map(\.weight).max() else { return 0...1 }
        let pad = max((hi - lo) * 0.15, 5)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        VStack {
            if points.isEmpty {
                ContentUnavailableView("No data yet",
                                       systemImage: "chart.line.uptrend.xyaxis",
                                       description: Text("Log workouts to see the trend."))
            } else {
                Chart {
                    ForEach(points) { p in
                        LineMark(x: .value("Date", p.date), y: .value("Weight", p.weight))
                            .foregroundStyle(.brand)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", p.date), y: .value("Weight", p.weight))
                            .foregroundStyle(.brand)
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
                                    Text("\(sel.weight.formatted(.number.precision(.fractionLength(0...1)))) \(unitLabel)")
                                        .font(.caption.bold())
                                }
                                .padding(6)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            }
                    }
                }
                .chartYScale(domain: yDomain)
                .chartYAxisLabel(unitLabel)
                .chartXSelection(value: $selectedDate)
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
