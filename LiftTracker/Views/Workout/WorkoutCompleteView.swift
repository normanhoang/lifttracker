import SwiftUI
import SwiftData

/// What just happened to the program. Not a celebration screen — the session is
/// already over; the useful information is what the weights do next.
struct WorkoutCompleteView: View {
    let summary: CompletedSummary
    let unit: WeightUnit

    @Environment(\.dismiss) private var dismiss
    @Query private var progress: [ExerciseProgress]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    private var session: WorkoutSession { summary.session }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    eyebrow
                    headline
                    metadata
                    statRow
                    nextSession
                    Divider().overlay(Color.hairline)
                    VStack(spacing: 10) {
                        ForEach(session.orderedExercises) { logged in
                            LiftResultRow(logged: logged, unit: unit)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 24)
            }
            footer
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
            Text("\(session.type.title.uppercased()) LOGGED")
                .font(.footnote.weight(.semibold))
                .tracking(1)
        }
        .foregroundStyle(.brand)
    }

    private var headline: some View {
        Text(ProgressionCopy.headline(summary.changes) { id in
            Exercise(rawValue: id)?.name ?? id
        })
        .font(.system(size: 32, weight: .bold))
        .tracking(-0.8)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var metadata: some View {
        Text("Session \(summary.number) · \(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · your \(ProgressionCopy.ordinal(summary.quarterCount)) this quarter")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            stat("Duration", durationText, comparison: durationComparison, tone: .neutral)
            divider
            stat("Volume", volumeText, comparison: volumeComparison, tone: .up)
            divider
            stat("Records", "\(recordCount)", comparison: recordNames, tone: recordCount > 0 ? .up : .neutral,
                 valueEmerald: recordCount > 0)
        }
        .padding(.vertical, 20)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(width: 1, height: 40)
    }

    private func stat(_ label: String, _ value: String, comparison: String?,
                      tone: ProgressionCopy.Tone, valueEmerald: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(valueEmerald ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.primary))
            if let comparison {
                Text(comparison)
                    .font(.caption2)
                    .foregroundStyle(tone == .up ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.tertiary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var nextSession: some View {
        let rows = summary.changes.filter { $0.outcome != .skipped }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("NEXT SESSION")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                ForEach(rows) { change in
                    changeRow(change)
                }
            }
        }
    }

    private func changeRow(_ change: Progression.Change) -> some View {
        let name = change.exercise?.name ?? change.exerciseID
        let logged = session.exercises.first { $0.exerciseID == change.exerciseID }
        let prog = progress.first { $0.exerciseID == change.exerciseID }
        let ex = change.exercise ?? .squat
        let deload = prog.map { Progression.deloadWeight($0) } ?? 0
        let step = prog?.increment(for: ex) ?? ex.increment

        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(dotColor(change.outcome))
                .frame(width: 7, height: 7)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(ProgressionCopy.changeTitle(change, name: name, unit: unit))
                    .font(.callout.weight(.semibold))
                Text(ProgressionCopy.changeReason(change, logged: logged, deloadWeight: deload,
                                                  increment: step, unit: unit))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if logged?.isPR == true { PRBadge() }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isHold(change.outcome) ? Color.orange.opacity(0.35) : .clear, lineWidth: 1)
        )
    }

    private func dotColor(_ outcome: Progression.Outcome) -> Color {
        switch outcome {
        case .increased: return .brand
        case .held: return .orange
        case .deloaded: return Color(.systemGray)
        case .skipped: return Color(.systemGray)
        }
    }

    private func isHold(_ outcome: Progression.Outcome) -> Bool {
        if case .held = outcome { return true }
        return false
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            Text("Next up: \(session.type.other.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Stats

    private var durationText: String {
        let s = Int(session.durationSeconds.rounded())
        if s < 60 { return "\(s)sec" }
        let m = s / 60
        return s % 60 == 0 ? "\(m)min" : "\(m):\(String(format: "%02d", s % 60))"
    }

    /// Minutes against the median of the last ten sessions.
    private var durationComparison: String? {
        let past = sessions.filter { $0.id != session.id && $0.durationSeconds > 0 }
            .prefix(10).map(\.durationSeconds)
        guard past.count >= 2 else { return nil }
        let usual = past.sorted()[past.count / 2]
        let delta = Int(((session.durationSeconds - usual) / 60).rounded())
        guard delta != 0 else { return "same as usual" }
        return "\(delta > 0 ? "+" : "")\(delta) vs usual"
    }

    private var volumeText: String {
        let v = WeightFormat.fromLb(session.volumeLb, unit)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let n = f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
        return "\(n)\(unit.rawValue)"
    }

    private var volumeComparison: String? {
        guard let last = sessions.first(where: { $0.id != session.id && $0.type == session.type && $0.volumeLb > 0 })
        else { return nil }
        let pct = Int((((session.volumeLb - last.volumeLb) / last.volumeLb) * 100).rounded())
        guard pct != 0 else { return "same as last \(session.type.rawValue)" }
        return "\(pct > 0 ? "+" : "")\(pct)% vs last \(session.type.rawValue)"
    }

    private var recordCount: Int { session.exercises.filter(\.isPR).count }

    private var recordNames: String? {
        let names = session.exercises.filter(\.isPR).compactMap { $0.exercise?.name }
        return names.isEmpty ? "none this time" : names.joined(separator: ", ")
    }
}
