import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

@main
struct RestTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            lockScreen(context)
                .padding(14)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.brand)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.brand)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.state.liftName) · set \(context.state.setNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .frame(maxWidth: 64)
                        .foregroundStyle(.brand)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    buttons(context.state)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.brand)
            } compactTrailing: {
                countdown(context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
                    .foregroundStyle(.brand)
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.brand)
            }
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<RestTimerAttributes>) -> some View {
        let state = context.state
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(context.attributes.workoutTitle) · \(state.liftName)")
                        .font(.subheadline.weight(.semibold))
                    Text("Set \(state.setNumber) of \(state.totalSets) · \(state.weightText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                countdown(state)
                    .font(.title.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.brand)
            }

            ProgressView(timerInterval: state.startDate...state.endDate, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(.brand)

            buttons(state)
        }
        .opacity(context.isStale ? 0.4 : 1)
    }

    private func countdown(_ state: RestTimerAttributes.ContentState) -> Text {
        Text(timerInterval: state.startDate...state.endDate, countsDown: true)
    }

    /// With these the phone can stay in your pocket for a whole session.
    private func buttons(_ state: RestTimerAttributes.ContentState) -> some View {
        HStack(spacing: 8) {
            Button(intent: AddRestIntent()) {
                Text("+30s")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.brand.opacity(0.16), in: Capsule())

            Button(intent: LogRingedSetIntent()) {
                Text("Log set \(state.setNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.10), in: Capsule())
        }
    }
}
