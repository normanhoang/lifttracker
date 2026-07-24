import SwiftUI

/// A day in History. The list rows stay summarised ("22/25 · 95lb"); this is
/// where the individual sets live, so you can see *which* ones you missed —
/// the last two is a different problem from the first two.
struct SessionDetailSheet: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let onDelete: (WorkoutSession) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(session.orderedExercises) { logged in
                        LiftResultCard(logged: logged, unit: unit)
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.card)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.headline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(.brand)
    }

    private var subtitle: String {
        var parts = [session.type.title]
        if session.durationSeconds > 0 { parts.append(durationText) }
        if session.volumeLb > 0 { parts.append(volumeText) }
        return parts.joined(separator: " · ")
    }

    private var footer: some View {
        HStack {
            Text("\(session.exercises.count) lifts logged")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Delete", role: .destructive) {
                onDelete(session)
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.red)
            .accessibilityIdentifier("deleteSession")
        }
        .padding(.top, 8)
    }

    private var durationText: String {
        let m = Int(session.durationSeconds.rounded()) / 60
        return "\(max(m, 1))min"
    }

    private var volumeText: String {
        let v = WeightFormat.fromLb(session.volumeLb, unit)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: v)) ?? "\(Int(v))")\(unit.rawValue)"
    }
}

/// One lift with its per-set pips. Same colour vocabulary as the live rep
/// tiles, so a set that was amber while you logged it stays amber forever.
private struct LiftResultCard: View {
    let logged: LoggedExercise
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                LiftStatusGlyph(logged: logged)
                Text(logged.exercise?.name ?? logged.exerciseID)
                    .font(.callout.weight(.semibold))
                Spacer(minLength: 8)
                if logged.isPR { PRBadge() }
                Text(WeightFormat.string(logged.weight, unit))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if logged.isSkipped {
                Text("Skipped — weight unchanged")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(logged.reps.enumerated()), id: \.offset) { _, r in
                        let hit = r >= logged.targetReps
                        Text("\(r)")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9)
                                .fill((hit ? Color.brand : .orange).opacity(hit ? 0.16 : 0.18)))
                            .foregroundStyle(hit ? Color.brand : .orange)
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
    }
}
