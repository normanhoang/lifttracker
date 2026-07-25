import SwiftUI

/// Five weeks of training at a glance. Replaces the separate Calendar tab —
/// one screen carries both affordances now.
struct WeekStrip: View {
    let sessions: [WorkoutSession]
    var weeks: Int = 5

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last \(weeks) weeks")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(frequencyText)
                    .font(.footnote)
                    .foregroundStyle(.brand)
            }
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(days, id: \.self) { day in
                    cell(day)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Cells

    private func cell(_ day: Date) -> some View {
        let session = sessions.first { calendar.isDate($0.date, inSameDayAs: day) }
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > .now && !isToday

        return RoundedRectangle(cornerRadius: 6)
            .fill(fill(session: session, isFuture: isFuture))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let session {
                    Text(session.type.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            .overlay {
                if isToday, session == nil {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.brand, lineWidth: 1.5)
                }
            }
            .accessibilityLabel(label(day: day, session: session))
    }

    private func fill(session: WorkoutSession?, isFuture: Bool) -> Color {
        guard let session else {
            // Beyond today is invisible against the card rather than an empty slot.
            return isFuture ? .card : .controlTrack
        }
        return (session.hasMiss ? Color.orange : Color.brand).opacity(0.85)
    }

    private func label(day: Date, session: WorkoutSession?) -> String {
        let date = day.formatted(.dateTime.month(.abbreviated).day())
        guard let session else { return "\(date), no session" }
        return "\(date), \(session.type.title)"
    }

    // MARK: - Dates

    /// Full weeks ending with the one containing today, Sunday-first.
    private var days: [Date] {
        let today = calendar.startOfDay(for: .now)
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let start = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek)
        else { return [] }
        return (0..<(weeks * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var frequencyText: String {
        let window = days.first ?? .now
        let count = sessions.filter { $0.date >= window }.count
        guard count > 0 else { return "none yet" }
        let perWeek = Double(count) / Double(weeks)
        return "\(perWeek.rounded() == perWeek ? String(Int(perWeek)) : String(format: "%.1f", perWeek))× / week"
    }
}
