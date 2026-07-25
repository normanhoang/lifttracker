import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query private var progress: [ExerciseProgress]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue
    @AppStorage("lastBodyWeight") private var lastBodyWeight = 0.0

    @StateObject private var draft = WorkoutDraft()
    @StateObject private var timer = RestTimerModel()

    @State private var loaded = false
    @State private var picking: SetRef?
    @State private var editingBodyWeight = false
    @State private var pendingDiscard: DiscardIntent?
    @State private var resumable: DraftSnapshot?
    @State private var completed: CompletedSummary?
    @State private var finishUndo: FinishUndo?

    var body: some View {
        VStack(spacing: 0) {
            header
            progressHairline
            ScrollView {
                VStack(spacing: 10) {
                    liftStack
                    bodyWeightRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            Spacer(minLength: 0)
            bottom
        }
        .background(Color.black)
        .tint(.brand)
        .animation(.snappy, value: draft.activeLiftIndex)
        .onAppear(perform: setupIfNeeded)
        .onChange(of: progress.map(\.currentWeight)) { _, _ in syncWeightsIfIdle() }
        .onReceive(NotificationCenter.default.publisher(for: DraftStore.changedNotification)) { _ in
            // A Live Activity button mutated the durable draft; adopt it rather
            // than overwriting it on the next local edit.
            draft.reloadFromStore()
            timer.sync(draft.snapshot)
        }
        .sheet(item: $picking) { ref in repPicker(ref) }
        .sheet(isPresented: $editingBodyWeight) { bodyWeightSheet }
        .fullScreenCover(item: $completed) { summary in
            WorkoutCompleteView(summary: summary, unit: unit)
        }
        .alert("Resume workout?", isPresented: Binding(get: { resumable != nil },
                                                       set: { if !$0 { resumable = nil } })) {
            Button("Resume") { if let r = resumable { draft.adopt(r); timer.sync(r) }; resumable = nil }
            Button("Start fresh", role: .destructive) { resumable = nil; startFresh() }
        } message: {
            if let r = resumable {
                Text("\(r.title) from earlier today has \(r.loggedSetCount) logged sets.")
            }
        }
        .overlay(alignment: .bottom) {
            if let undo = finishUndo {
                UndoToast(text: "\(undo.title) saved") { undoFinish(undo) }
                    .padding(.bottom, 12)
                    .task {
                        try? await Task.sleep(for: .seconds(6))
                        withAnimation { finishUndo = nil }
                    }
            }
        }
        .overlay {
            if let intent = pendingDiscard {
                DiscardSheet(
                    title: discardTitle,
                    destructiveLabel: discardLabel(intent),
                    loggedSetCount: draft.loggedSetCount,
                    onConfirm: { apply(intent) },
                    onCancel: { pendingDiscard = nil }
                )
            }
        }
        .animation(.easeOut(duration: 0.18), value: pendingDiscard?.id)
        .sensoryFeedback(.success, trigger: completed?.id)
    }

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(WorkoutType.allCases) { t in
                    Button {
                        request(.switchTo(t))
                    } label: {
                        Label(t.title, systemImage: draft.type == t ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    // White, not emerald: it's a picker, not an action.
                    Text(draft.type.title).font(.headline).foregroundStyle(.primary)
                    Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.primary)
                }
            }
            // The screen's .tint(.brand) would otherwise paint the menu label
            // emerald, which reads as an action.
            .tint(.primary)
            .accessibilityIdentifier("workoutPicker")

            Spacer()

            if let start = draft.startedAt {
                Text(start, style: .timer)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("bottomBar.timer")
            }

            Menu {
                if let active = activeLift {
                    Button("Skip \(active.name) today", systemImage: "minus.circle") {
                        draft.skip(Exercise(rawValue: active.exerciseID) ?? .squat)
                        timer.sync(draft.snapshot)
                    }
                }
                // Always available: with nothing logged `request` skips the
                // confirmation and this is simply a reset, which is worth having
                // as a guaranteed way out of any stuck state.
                Button("Discard workout", systemImage: "trash", role: .destructive) {
                    request(.discard)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
            }
            .accessibilityIdentifier("workoutOverflow")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var progressHairline: some View {
        GeometryReader { geo in
            let total = max(draft.snapshot.totalSetCount, 1)
            let fraction = Double(draft.loggedSetCount) / Double(total)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.card)
                Capsule().fill(Color.brand).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 16)
    }

    // MARK: - Lift stack

    private var activeLift: DraftLift? {
        draft.activeLiftIndex.map { draft.lifts[$0] }
    }

    private var liftStack: some View {
        ForEach(Array(draft.lifts.enumerated()), id: \.element.id) { index, lift in
            if index == draft.activeLiftIndex {
                ActiveLiftCard(
                    lift: lift,
                    unit: unit,
                    note: note(for: lift),
                    increment: increment(for: lift),
                    onStep: { delta in step(lift, delta) },
                    onTapSet: { i in tap(lift, i) },
                    onHoldSet: { i in picking = SetRef(liftID: lift.exerciseID, index: i) },
                    onUndo: { draft.undoLastSet(); timer.sync(draft.snapshot) }
                )
            } else {
                CollapsedLiftRow(
                    name: lift.name,
                    detail: collapsedDetail(lift),
                    state: collapsedState(lift),
                    onTap: lift.skipped ? { draft.unskip(exercise(lift)) } : nil
                )
            }
        }
    }

    private var bodyWeightRow: some View {
        CollapsedLiftRow(
            name: "Body weight",
            detail: draft.bodyWeight.map { WeightFormat.string($0, unit) } ?? "—",
            state: .upcoming,
            symbol: "scalemass",
            onTap: { editingBodyWeight = true }
        )
    }

    private func collapsedState(_ lift: DraftLift) -> CollapsedLiftRow.State {
        if lift.skipped { return .skipped }
        if lift.isComplete { return .done(clean: lift.isClean) }
        return .upcoming
    }

    private func collapsedDetail(_ lift: DraftLift) -> String {
        if lift.skipped { return "Skipped" }
        let weight = WeightFormat.string(lift.weightLb, unit)
        guard lift.isComplete else {
            return "\(lift.reps.count)×\(lift.targetReps) · \(weight)"
        }
        if lift.isClean { return "\(lift.reps.count)×\(lift.targetReps) · \(weight)" }
        let total = lift.reps.compactMap { $0 }.reduce(0, +)
        return "\(total)/\(lift.reps.count * lift.targetReps) · \(weight)"
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottom: some View {
        VStack(spacing: 10) {
            if let end = draft.snapshot.restEndDate,
               let liftID = draft.snapshot.restLiftID,
               let setIndex = draft.snapshot.restSetIndex,
               let lift = draft.snapshot.lift(liftID) {
                RestStrip(
                    endDate: end,
                    targetSeconds: draft.snapshot.restTargetSeconds,
                    liftName: lift.name,
                    setNumber: setIndex + 1,
                    weightText: WeightFormat.string(lift.weightLb, unit),
                    onAdd: { draft.addRest(30); timer.sync(draft.snapshot) },
                    onSkip: { draft.skipRest(); timer.sync(draft.snapshot) }
                )
            }
            finishButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var finishButton: some View {
        Button { finish() } label: {
            Text(draft.isFinishable ? "Finish workout" : draft.snapshot.remainingSetsText)
                .font(.system(size: 18, weight: draft.isFinishable ? .bold : .semibold))
                .foregroundStyle(draft.isFinishable ? AnyShapeStyle(.black) : AnyShapeStyle(.tertiary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(draft.isFinishable ? Color.brand : Color.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!draft.isFinishable)
        .accessibilityIdentifier("finishWorkout")
    }

    // MARK: - Sheets

    @ViewBuilder
    private func repPicker(_ ref: SetRef) -> some View {
        if let lift = draft.snapshot.lift(ref.liftID) {
            RepPickerSheet(
                liftName: lift.name,
                setNumber: ref.index + 1,
                target: lift.targetReps,
                isLogged: lift.reps[ref.index] != nil,
                onPick: { n in
                    draft.log(exercise(lift), ref.index, reps: n)
                    timer.sync(draft.snapshot)
                },
                onClear: {
                    draft.log(exercise(lift), ref.index, reps: nil)
                    timer.sync(draft.snapshot)
                },
                onSkipLift: {
                    draft.skip(exercise(lift))
                    timer.sync(draft.snapshot)
                }
            )
        }
    }

    private var bodyWeightSheet: some View {
        NumberEditSheet(
            title: "Body Weight",
            unitLabel: unit.rawValue,
            step: unit == .kg ? 0.5 : 1,
            value: WeightFormat.fromLb(draft.bodyWeight ?? lastBodyWeight, unit)
        ) { newVal in
            draft.bodyWeight = WeightFormat.toLb(newVal, unit)
        }
    }

    // MARK: - Actions

    private func exercise(_ lift: DraftLift) -> Exercise {
        Exercise(rawValue: lift.exerciseID) ?? .squat
    }

    private func tap(_ lift: DraftLift, _ index: Int) {
        // Tapping a logged tile opens the picker — correction, not a second cycle.
        if lift.reps[index] != nil {
            picking = SetRef(liftID: lift.exerciseID, index: index)
            return
        }
        draft.tapSet(exercise(lift), index)
        timer.sync(draft.snapshot)
    }

    private func step(_ lift: DraftLift, _ delta: Double) {
        let next = max(0, lift.weightLb + delta)
        draft.setWeight(exercise(lift), next)
    }

    private func increment(for lift: DraftLift) -> Double {
        let ex = exercise(lift)
        return row(ex)?.increment(for: ex) ?? ex.increment
    }

    private func note(for lift: DraftLift) -> ProgressionCopy.Note? {
        let ex = exercise(lift)
        guard let prog = row(ex) else { return nil }
        return ProgressionCopy.liftNote(
            increment: prog.increment(for: ex),
            successStreak: prog.successStreak,
            failStreak: prog.failStreak,
            currentWeight: prog.currentWeight,
            deloadedLastSession: false,
            lastDate: lastDate(for: ex),
            unit: unit
        )
    }

    private func lastDate(for ex: Exercise) -> Date? {
        sessions.first { session in
            session.exercises.contains { $0.exerciseID == ex.rawValue && !$0.isSkipped }
        }?.date
    }

    private func row(_ ex: Exercise) -> ExerciseProgress? {
        progress.first { $0.exerciseID == ex.rawValue }
    }

    private func setupIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let stored = DraftStore.load() {
            if DraftStore.isResumable(stored) {
                resumable = stored
                return
            }
            DraftStore.clear()
        }
        startFresh()
    }

    private func startFresh() {
        let suggested = sessions.first?.type.other ?? .a
        draft.reset(type: suggested,
                    weights: weightsMap(),
                    rest: restMap(),
                    bodyWeight: lastBodyWeight > 0 ? lastBodyWeight : nil)
    }

    private func syncWeightsIfIdle() {
        guard !draft.hasProgress else { return }
        draft.reset(type: draft.type, weights: weightsMap(), rest: restMap(),
                    bodyWeight: draft.bodyWeight)
    }

    private func weightsMap() -> [String: Double] {
        var map: [String: Double] = [:]
        for ex in Exercise.allCases {
            map[ex.rawValue] = row(ex)?.currentWeight ?? ex.startingWeight
        }
        return map
    }

    private func restMap() -> [String: Int] {
        var map: [String: Int] = [:]
        for ex in Exercise.allCases {
            map[ex.rawValue] = row(ex)?.restSeconds ?? ex.defaultRestSeconds
        }
        return map
    }

    // MARK: - Discard

    private enum DiscardIntent: Identifiable {
        case discard
        case switchTo(WorkoutType)

        var id: String {
            switch self {
            case .discard: return "discard"
            case .switchTo(let t): return "switch-\(t.rawValue)"
            }
        }
    }

    private var discardTitle: String {
        switch pendingDiscard {
        case .switchTo(let t): return "Switch to \(t.title)?"
        default: return "Discard this workout?"
        }
    }

    private func discardLabel(_ intent: DiscardIntent) -> String {
        switch intent {
        case .discard: return "Discard workout"
        case .switchTo(let t): return "Switch to \(t.title)"
        }
    }

    private func request(_ intent: DiscardIntent) {
        if case .switchTo(let t) = intent, t == draft.type { return }
        guard draft.hasProgress else {     // nothing logged → just do it
            apply(intent)
            return
        }
        // One tick later: presenting straight out of a Menu action races the
        // menu's own dismissal and the dialog is dropped.
        DispatchQueue.main.async { pendingDiscard = intent }
    }

    private func apply(_ intent: DiscardIntent) {
        switch intent {
        case .discard:
            startFresh()
        case .switchTo(let t):
            draft.changeType(t)
        }
        timer.stop()
        pendingDiscard = nil
    }

    // MARK: - Finish

    private func finish() {
        let now = Date()
        let duration = now.timeIntervalSince(draft.startedAt ?? now)
        let session = draft.buildSession(date: now, duration: duration)

        let number = ((try? context.fetchCount(FetchDescriptor<WorkoutSession>())) ?? 0) + 1
        let before = progressSnapshot()

        // Persist edited working weights, then flag PRs against the previous best.
        for lift in draft.lifts {
            let ex = exercise(lift)
            progressRow(ex).currentWeight = lift.weightLb
        }
        for logged in session.exercises where !logged.isSkipped {
            guard let ex = Exercise(rawValue: logged.exerciseID) else { continue }
            let prog = progressRow(ex)
            logged.isPR = prog.bestWeight > 0 && logged.weight > prog.bestWeight
            prog.bestWeight = max(prog.bestWeight, logged.weight)
        }

        context.insert(session)
        let changes = Progression.apply(session: session) { id in
            progressRow(Exercise(rawValue: id) ?? .squat)
        }
        if let bw = draft.bodyWeight {
            lastBodyWeight = bw
            context.insert(BodyWeightEntry(date: now, weightLb: bw))
        }
        do { try context.save() } catch {
            print("WorkoutView: failed to save session: \(error)")
        }

        timer.stop()
        draft.clearPersisted()
        completed = CompletedSummary(number: number, session: session, changes: changes,
                                     unit: unit, quarterCount: quarterCount(including: now))
        finishUndo = FinishUndo(title: session.type.title, session: session, before: before)

        // Start the next suggested workout.
        draft.reset(type: session.type.other, weights: weightsMap(), rest: restMap(),
                    bodyWeight: draft.bodyWeight)
    }

    private func quarterCount(including date: Date) -> Int {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let startMonth = ((month - 1) / 3) * 3 + 1
        guard let start = cal.date(from: DateComponents(year: cal.component(.year, from: date),
                                                        month: startMonth, day: 1)) else { return 1 }
        return sessions.filter { $0.date >= start }.count + 1
    }

    /// Enough of each progress row to put it back if the user undoes the save.
    private func progressSnapshot() -> [String: ProgressState] {
        var map: [String: ProgressState] = [:]
        for p in progress {
            map[p.exerciseID] = ProgressState(weight: p.currentWeight, fail: p.failStreak,
                                              success: p.successStreak, best: p.bestWeight)
        }
        return map
    }

    private func undoFinish(_ undo: FinishUndo) {
        context.delete(undo.session)
        for p in progress {
            guard let s = undo.before[p.exerciseID] else { continue }
            p.currentWeight = s.weight
            p.failStreak = s.fail
            p.successStreak = s.success
            p.bestWeight = s.best
        }
        do { try context.save() } catch {
            print("WorkoutView: failed to undo finish: \(error)")
        }
        finishUndo = nil
        completed = nil
    }

    /// Fetch (or create) the persisted progress row for an exercise.
    private func progressRow(_ ex: Exercise) -> ExerciseProgress {
        if let p = row(ex) { return p }
        let p = ExerciseProgress(exerciseID: ex.rawValue, currentWeight: ex.startingWeight)
        context.insert(p)
        return p
    }
}

/// Which set the rep picker is editing.
private struct SetRef: Identifiable {
    let liftID: String
    let index: Int
    var id: String { "\(liftID).\(index)" }
}

private struct ProgressState {
    let weight: Double
    let fail: Int
    let success: Int
    let best: Double
}

private struct FinishUndo {
    let title: String
    let session: WorkoutSession
    let before: [String: ProgressState]
}

/// Everything the completed screen reports.
struct CompletedSummary: Identifiable {
    let id = UUID()
    let number: Int
    let session: WorkoutSession
    let changes: [Progression.Change]
    let unit: WeightUnit
    let quarterCount: Int
}
