import SwiftUI

/// Celebration screen shown after finishing a workout (see IMG_8298.PNG).
struct WorkoutCompleteView: View {
    let summary: CompletedSummary
    let unit: WeightUnit
    @Environment(\.dismiss) private var dismiss

    private var durationText: String {
        let s = Int(summary.duration.rounded())
        if s < 60 { return "\(s)sec" }
        let m = s / 60
        return s % 60 == 0 ? "\(m)min" : "\(m):\(String(format: "%02d", s % 60))"
    }

    private var volumeText: String {
        let v = WeightFormat.fromLb(summary.volumeLb, unit)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let n = f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
        return "\(n)\(unit.rawValue)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "laurel.leading")
                    .font(.system(size: 80)).foregroundStyle(.orange)
                VStack(spacing: 4) {
                    Text("Workout\n\(summary.number) done!")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("Awesome!")
                        .font(.title3).foregroundStyle(.secondary)
                }
                Image(systemName: "laurel.trailing")
                    .font(.system(size: 80)).foregroundStyle(.orange)
            }
            .padding(.top, 8)

            statRow
                .padding(.vertical, 28)

            SessionCard(session: summary.session, unit: unit)
                .padding(.horizontal)

            Spacer()

            Button { dismiss() } label: {
                Text("Done")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.red, in: Capsule())
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            stat("Duration", durationText)
            Divider().frame(height: 40)
            stat("Volume", volumeText)
            Divider().frame(height: 40)
            stat("Records", "\(summary.records)")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
    }
}
