import SwiftUI

/// One exercise block on the Workout screen: title, weight, and a row of rep circles.
struct ExerciseRow: View {
    let slot: ExerciseSlot
    let weightLb: Double
    let unit: WeightUnit
    let states: [SetState]
    let onTapSet: (Int) -> Void
    let onEditWeight: () -> Void

    private var target: String {
        // Multi-set lifts show "5×5 250lb"; a single-set lift (Deadlift) shows "5×265lb".
        let w = WeightFormat.string(weightLb, unit)
        return slot.sets == 1
            ? "\(Exercise.targetReps)×\(w)"
            : "\(slot.sets)×\(Exercise.targetReps) \(w)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(slot.exercise.name)
                    .font(.title2).bold()
                Spacer()
                Button(action: onEditWeight) {
                    HStack(spacing: 4) {
                        Text(target)
                            .font(.title3)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(states.indices, id: \.self) { i in
                        RepCircle(state: states[i]) { onTapSet(i) }
                    }
                }
            }
        }
    }
}
