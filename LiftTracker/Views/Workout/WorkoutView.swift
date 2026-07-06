import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query private var progress: [ExerciseProgress]

    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue
    @AppStorage("lastBodyWeight") private var lastBodyWeight = 0.0

    @StateObject private var draft = WorkoutDraft()
    @StateObject private var timer = RestTimerModel()

    @State private var loaded = false
    @State private var editingExercise: Exercise?
    @State private var editingBodyWeight = false
    @State private var workoutStart: Date?
    @State private var completed: CompletedSummary?

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                workoutPicker
                    .padding(.vertical, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(draft.type.slots) { slot in
                            ExerciseRow(
                                slot: slot,
                                weightLb: draft.weight(slot.exercise),
                                unit: unit,
                                states: draft.states(slot.exercise),
                                onTapSet: { i in
                                    if draft.tap(slot.exercise, i) {
                                        if workoutStart == nil { workoutStart = Date() }
                                        timer.start(workoutTitle: draft.type.title)
                                    } else if !draft.hasProgress {
                                        workoutStart = nil
                                        timer.stop()
                                    }
                                },
                                onEditWeight: { editingExercise = slot.exercise }
                            )
                        }

                        bodyWeightRow
                    }
                    .padding()
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .tint(.red)
        .onAppear(perform: setupIfNeeded)
        .onChange(of: progress.map(\.currentWeight)) { _, _ in
            // Pick up Starting-Weight edits from Settings (works even though the
            // page stays mounted); never clobber an in-progress workout.
            if !draft.hasProgress {
                draft.reset(type: draft.type, weights: weightsMap(), bodyWeight: draft.bodyWeight)
            }
        }
        .sheet(item: $editingExercise) { ex in
            NumberEditSheet(
                title: ex.name,
                unitLabel: unit.rawValue,
                step: unit == .kg ? 2.5 : 5,
                value: WeightFormat.fromLb(draft.weight(ex), unit)
            ) { newVal in
                draft.setWeight(ex, WeightFormat.toLb(newVal, unit))
            }
        }
        .sheet(isPresented: $editingBodyWeight) {
            NumberEditSheet(
                title: "Body Weight",
                unitLabel: unit.rawValue,
                step: unit == .kg ? 0.5 : 1,
                value: WeightFormat.fromLb(draft.bodyWeight ?? lastBodyWeight, unit)
            ) { newVal in
                draft.bodyWeight = WeightFormat.toLb(newVal, unit)
            }
        }
        .fullScreenCover(item: $completed) { summary in
            WorkoutCompleteView(summary: summary, unit: unit)
        }
        .sensoryFeedback(.success, trigger: completed?.id)
    }

    // MARK: - Sub-views

    private var workoutPicker: some View {
        Menu {
            ForEach(WorkoutType.allCases) { t in
                Button {
                    draft.changeType(t)
                    timer.stop()
                    workoutStart = nil
                } label: {
                    Label(t.title, systemImage: draft.type == t ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(draft.type.title).font(.headline).foregroundStyle(.red)
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var bodyWeightRow: some View {
        Button { editingBodyWeight = true } label: {
            HStack {
                Text("Body Weight").font(.title3)
                Spacer()
                Text(draft.bodyWeight.map { WeightFormat.string($0, unit) } ?? "—")
                    .font(.title3)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var bottomBar: some View {
        HStack {
            if let start = timer.startDate {
                // Self-updating timer text: no per-second view re-renders.
                // Color marks 5×5 rest guidance: <1:30 keep resting, <3:00 ok
                // for easy sets, 3:00+ go lift.
                TimelineView(.explicit([start.addingTimeInterval(90),
                                        start.addingTimeInterval(180)])) { tl in
                    let elapsed = tl.date.timeIntervalSince(start)
                    Text(start, style: .timer)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(elapsed < 90 ? AnyShapeStyle(.secondary)
                                       : elapsed < 180 ? AnyShapeStyle(.primary)
                                       : AnyShapeStyle(.red))
                }
            } else {
                Text("Rest")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Finish") { finish() }
                .font(.headline.bold())
                .foregroundStyle(draft.hasProgress ? .red : .secondary)
                .disabled(!draft.hasProgress)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func setupIfNeeded() {
        guard !loaded else { return }
        loaded = true
        var latest = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        latest.fetchLimit = 1
        let suggested = (try? context.fetch(latest))?.first?.type.other ?? .a
        draft.reset(type: suggested, weights: weightsMap(), bodyWeight: lastBodyWeight > 0 ? lastBodyWeight : nil)
    }

    private func weightsMap() -> [String: Double] {
        var map: [String: Double] = [:]
        for ex in Exercise.allCases {
            map[ex.rawValue] = progress.first { $0.exerciseID == ex.rawValue }?.currentWeight ?? ex.startingWeight
        }
        return map
    }

    private func finish() {
        // Persist edited working weights back to ExerciseProgress before logging.
        for ex in Exercise.allCases {
            let prog = progressRow(ex)
            prog.currentWeight = draft.weight(ex)
        }

        let session = draft.buildSession()

        // Compute completion stats against prior sessions (before inserting this one).
        let number = ((try? context.fetchCount(FetchDescriptor<WorkoutSession>())) ?? 0) + 1
        let duration = Date().timeIntervalSince(workoutStart ?? session.date)
        let volume = session.exercises.reduce(0.0) { sum, ex in
            sum + ex.reps.reduce(0.0) { $0 + Double($1) * ex.weight }
        }
        let records = countRecords(in: session)

        context.insert(session)
        Progression.apply(session: session) { id in
            progressRow(Exercise(rawValue: id)!)
        }
        if let bw = draft.bodyWeight { lastBodyWeight = bw }
        do { try context.save() } catch {
            print("WorkoutView: failed to save session: \(error)")
        }

        timer.stop()
        completed = CompletedSummary(
            number: number, duration: duration, volumeLb: volume,
            records: records, session: session
        )

        // Start the next suggested workout.
        workoutStart = nil
        draft.reset(type: session.type.other, weights: weightsMap(), bodyWeight: draft.bodyWeight)
    }

    /// Number of lifts whose logged weight beats that lift's previous best.
    private func countRecords(in session: WorkoutSession) -> Int {
        let logged = (try? context.fetch(FetchDescriptor<LoggedExercise>())) ?? []
        var priorBest: [String: Double] = [:]
        for ex in logged where !ex.isSkipped {
            priorBest[ex.exerciseID] = max(priorBest[ex.exerciseID] ?? 0, ex.weight)
        }
        return session.exercises.filter { lift in
            guard !lift.isSkipped, let best = priorBest[lift.exerciseID] else { return false }
            return lift.weight > best
        }.count
    }

    /// Fetch (or create) the persisted progress row for an exercise.
    private func progressRow(_ ex: Exercise) -> ExerciseProgress {
        if let p = progress.first(where: { $0.exerciseID == ex.rawValue }) { return p }
        let p = ExerciseProgress(exerciseID: ex.rawValue, currentWeight: ex.startingWeight)
        context.insert(p)
        return p
    }
}

/// Stats shown on the workout-completed screen.
struct CompletedSummary: Identifiable {
    let id = UUID()
    let number: Int
    let duration: TimeInterval
    let volumeLb: Double
    let records: Int
    let session: WorkoutSession
}
