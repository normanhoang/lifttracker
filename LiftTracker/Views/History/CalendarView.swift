import SwiftUI

/// Month grid marking days that have a workout. Tapping a marked day shows its sessions.
struct CalendarView: View {
    let sessions: [WorkoutSession]
    let unit: WeightUnit
    /// Precomputed by the parent so month navigation doesn't rescan sessions.
    let workedDays: Set<DateComponents>

    @State private var month: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: Date?   // persistent highlight
    @State private var sheetDay: Date?      // drives the sessions sheet

    private let cal = Calendar.current
    private let cols = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            header
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                    Text(d).frame(maxWidth: .infinity).foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(daysInMonth(), id: \.self) { day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .sheet(item: Binding(get: { sheetDay.map { IdentifiableDate(date: $0) } },
                             set: { sheetDay = $0?.date })) { wrap in
            DaySessionsSheet(day: wrap.date, sessions: sessionsOn(wrap.date), unit: unit)
        }
    }

    private var header: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(month, format: .dateTime.month(.wide).year()).font(.headline)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
        }
        .tint(.brand)
    }

    private func dayCell(_ day: Date) -> some View {
        let worked = workedDays.contains(cal.dateComponents([.year, .month, .day], from: day))
        let isToday = cal.isDateInToday(day)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false
        return Button {
            if worked { selectedDay = day; sheetDay = day }
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background {
                        // Selected day: filled circle. Today: ring. Both can show together.
                        ZStack {
                            if isSelected { Circle().fill(Color.brand.opacity(0.35)) }
                            if isToday { Circle().stroke(Color.brand, lineWidth: 2) }
                        }
                    }
                Circle()
                    .fill(worked ? Color.brand : .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .disabled(!worked)
    }

    // MARK: - Date math

    private func shift(_ by: Int) {
        if let d = cal.date(byAdding: .month, value: by, to: month) { month = d }
    }

    /// Days of the month padded with leading nils so the 1st lands on the right weekday.
    private func daysInMonth() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }
        let leading = cal.component(.weekday, from: first) - 1   // Sunday = 1
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            cells.append(cal.date(byAdding: .day, value: d - 1, to: first))
        }
        return cells
    }

    private func sessionsOn(_ day: Date) -> [WorkoutSession] {
        sessions.filter { cal.isDate($0.date, inSameDayAs: day) }
    }
}

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct DaySessionsSheet: View {
    let day: Date
    @State var sessions: [WorkoutSession]
    let unit: WeightUnit
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { s in
                    SessionCard(session: s, unit: unit)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(s)
                                do { try context.save() } catch {
                                    print("DaySessionsSheet: failed to delete session: \(error)")
                                }
                                sessions.removeAll { $0 === s }
                                if sessions.isEmpty { dismiss() }
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle(day.formatted(.dateTime.weekday(.abbreviated).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
