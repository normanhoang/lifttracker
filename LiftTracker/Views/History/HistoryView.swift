import SwiftUI
import SwiftData

struct HistoryView: View {
    /// Lets the empty state actually go somewhere.
    var onStartWorkout: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue

    @State private var detail: WorkoutSession?
    @State private var recentlyDeleted: DeletedSession?

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    title
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        WeekStrip(sessions: sessions)
                        ForEach(groups, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.title.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .tracking(0.85)
                                    .foregroundStyle(.tertiary)
                                ForEach(group.sessions) { session in
                                    Button { detail = session } label: {
                                        SessionCard(session: session, unit: unit)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("sessionCard")
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.black)
        }
        .tint(.brand)
        .sheet(item: $detail) { session in
            SessionDetailSheet(session: session, unit: unit) { delete($0) }
        }
        .overlay(alignment: .bottom) {
            if let deleted = recentlyDeleted {
                UndoToast(text: "\(deleted.title) deleted") { restore(deleted) }
                    .padding(.bottom, 12)
                    .task {
                        try? await Task.sleep(for: .seconds(6))
                        withAnimation { recentlyDeleted = nil }
                    }
            }
        }
    }

    private var title: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("History").font(.largeTitle.bold())
            Spacer()
            if !sessions.isEmpty {
                Text("\(sessions.count) \(sessions.count == 1 ? "session" : "sessions")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Nothing logged yet")
                .font(.system(size: 20, weight: .semibold))
            Text("Finish your first Workout A and it lands here — every set, every session, forever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onStartWorkout) {
                Text("Start Workout A")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.brand)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .overlay(Capsule().strokeBorder(Color.brand, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 80)
    }

    // MARK: - Grouping

    private struct Group {
        let title: String
        let sessions: [WorkoutSession]
    }

    private var groups: [Group] {
        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: [WorkoutSession]] = [:]
        for session in sessions {
            let key = weekTitle(for: session.date, calendar: calendar)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(session)
        }
        return order.map { Group(title: $0, sessions: buckets[$0] ?? []) }
    }

    private func weekTitle(for date: Date, calendar: Calendar) -> String {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start,
              let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return "Earlier" }
        let diff = calendar.dateComponents([.weekOfYear], from: week, to: thisWeek).weekOfYear ?? 0
        switch diff {
        case 0: return "This week"
        case 1: return "Last week"
        default: return week.formatted(.dateTime.month(.wide).day())
        }
    }

    // MARK: - Delete

    private struct DeletedSession {
        let title: String
        let date: Date
        let type: WorkoutType
        let duration: Double
        let volume: Double
        let lifts: [(id: String, weight: Double, reps: [Int], sets: Int, target: Int, pr: Bool)]
    }

    /// Snapshot before deleting: re-inserting a deleted `@Model` is not reliable,
    /// and the cascade takes the `LoggedExercise` children with it.
    private func delete(_ session: WorkoutSession) {
        recentlyDeleted = DeletedSession(
            title: session.type.title,
            date: session.date,
            type: session.type,
            duration: session.durationSeconds,
            volume: session.volumeLb,
            lifts: session.orderedExercises.map {
                ($0.exerciseID, $0.weight, $0.reps, $0.targetSets, $0.targetReps, $0.isPR)
            }
        )
        context.delete(session)
        do { try context.save() } catch {
            print("HistoryView: failed to delete session: \(error)")
        }
    }

    /// Restores the record. Note it does not roll the program back — the weights
    /// this session moved you to stay where they are.
    private func restore(_ deleted: DeletedSession) {
        let session = WorkoutSession(date: deleted.date, type: deleted.type)
        session.durationSeconds = deleted.duration
        session.volumeLb = deleted.volume
        for lift in deleted.lifts {
            let logged = LoggedExercise(exerciseID: lift.id, weight: lift.weight, reps: lift.reps,
                                        targetSets: lift.sets, targetReps: lift.target)
            logged.isPR = lift.pr
            logged.session = session
            session.exercises.append(logged)
        }
        context.insert(session)
        do { try context.save() } catch {
            print("HistoryView: failed to restore session: \(error)")
        }
        recentlyDeleted = nil
    }
}

/// One workout summarised as a card.
struct SessionCard: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(session.type.title) · \(session.date.formatted(.dateTime.weekday(.abbreviated).day()))")
                    .font(.headline)
                Spacer(minLength: 8)
                if let stats = statsText {
                    Text(stats)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(session.orderedExercises) { logged in
                LiftResultRow(logged: logged, unit: unit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var statsText: String? {
        var parts: [String] = []
        if session.durationSeconds > 0 {
            parts.append("\(max(Int(session.durationSeconds.rounded()) / 60, 1))min")
        }
        if session.volumeLb > 0 {
            let v = WeightFormat.fromLb(session.volumeLb, unit)
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            parts.append("\(f.string(from: NSNumber(value: v)) ?? "\(Int(v))")\(unit.rawValue)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
