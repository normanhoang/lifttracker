import SwiftUI

/// The status vocabulary shared by History, the complete screen and the day
/// sheet: emerald check = clean, amber broken ring = partial, grey dash = skipped.
struct LiftStatusGlyph: View {
    let logged: LoggedExercise

    var body: some View {
        Group {
            if logged.isSkipped {
                Image(systemName: "minus").foregroundStyle(.tertiary)
            } else if logged.isSuccess {
                Image(systemName: "checkmark").foregroundStyle(.brand)
            } else {
                Image(systemName: "circle.dotted").foregroundStyle(.orange)
            }
        }
        .font(.headline.weight(.semibold))
        .frame(width: 20)
    }
}

/// One lift's line inside a session card.
struct LiftResultRow: View {
    let logged: LoggedExercise
    let unit: WeightUnit

    private var resultStyle: AnyShapeStyle {
        if logged.isSkipped { return AnyShapeStyle(.tertiary) }
        if logged.isSuccess { return AnyShapeStyle(.secondary) }
        return AnyShapeStyle(Color.orange)
    }

    var body: some View {
        HStack(spacing: 10) {
            LiftStatusGlyph(logged: logged)
            Text(logged.exercise?.name ?? logged.exerciseID)
                .font(.callout)
                .foregroundStyle(logged.isSkipped ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            Spacer(minLength: 8)
            if logged.isPR { PRBadge() }
            Text(logged.resultText(unit))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(resultStyle)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

struct PRBadge: View {
    var body: some View {
        Text("PR")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.brand)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.brand.opacity(0.18)))
    }
}
