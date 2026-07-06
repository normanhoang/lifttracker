import SwiftUI
import WidgetKit
import ActivityKit

@main
struct RestTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock Screen / banner presentation.
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context.state.startDate, style: .timer)
                        .font(.title.monospacedDigit().bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(context.attributes.workoutTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .opacity(context.isStale ? 0.4 : 1)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(.red)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startDate, style: .timer)
                        .monospacedDigit()
                        .frame(maxWidth: 64)
                        .foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Resting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Text(context.state.startDate, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
                    .foregroundStyle(.red)
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.red)
            }
        }
    }
}
