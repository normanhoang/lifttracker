import SwiftUI

/// Shown once. The app never explains A/B, 5×5, the +5 or the deload anywhere,
/// and there is no account to create — so one screen, no carousel.
struct FirstRunView: View {
    let onSeedDefaults: () -> Void
    let onSetWeights: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 34))
                        .foregroundStyle(.brand)

                    Text("Two workouts,\nfive lifts, forever.")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.8)

                    Text("You alternate A and B, three times a week. Hit all five sets and the app adds weight next time. Miss three sessions in a row and it takes 10% off so you can build back up. That's the whole program.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    dayCard(.a)
                    dayCard(.b)
                }
                .padding(.top, 44)
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private func dayCard(_ type: WorkoutType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(type.title).font(.callout.weight(.semibold))
                Text(type.dayHint).font(.footnote).foregroundStyle(.tertiary)
            }
            ForEach(type.slots) { slot in
                HStack {
                    Text(slot.exercise.name).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(slot.sets)×\(Exercise.targetReps)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: onSeedDefaults) {
                Text("Start with an empty bar")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.brand, in: Capsule())
            }
            .buttonStyle(.plain)

            Button("I already lift — set my weights", action: onSetWeights)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.brand)

            Text("Everything stays on this iPhone. No account, ever.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
}
