import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue
    @State private var mode = 0   // 0 = List, 1 = Calendar

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("", selection: $mode) {
                    Text("List").tag(0)
                    Text("Calendar").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if sessions.isEmpty {
                    ContentUnavailableView("No workouts yet",
                                           systemImage: "dumbbell",
                                           description: Text("Finish a workout to see it here."))
                } else if mode == 0 {
                    listView
                } else {
                    CalendarView(sessions: sessions, unit: unit, workedDays: workedDays)
                }
            }
            .navigationTitle("History")
        }
        .tint(.brand)
    }

    /// Days that have at least one session, passed to CalendarView so it doesn't rescan
    /// on every month shift. Recomputed on each render (a single cheap map over sessions).
    private var workedDays: Set<DateComponents> {
        let cal = Calendar.current
        return Set(sessions.map { cal.dateComponents([.year, .month, .day], from: $0.date) })
    }

    private var listView: some View {
        List {
            ForEach(sessions) { session in
                SessionCard(session: session, unit: unit)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            context.delete(session)
                            do { try context.save() } catch {
                                print("HistoryView: failed to delete session: \(error)")
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

/// One workout summarised as a card.
struct SessionCard: View {
    let session: WorkoutSession
    let unit: WeightUnit

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.type.title).foregroundStyle(.secondary)
                Spacer()
                Text(Self.dateFmt.string(from: session.date)).foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            ForEach(session.orderedExercises) { ex in
                HStack {
                    Text(ex.exercise?.name ?? ex.exerciseID)
                    Spacer()
                    Text(ex.resultText(unit))
                }
                .font(.title3)
                .padding(.vertical, 10)
                Divider()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
