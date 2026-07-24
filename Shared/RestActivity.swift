import Foundation
import ActivityKit

/// Owns the Live Activity for the rest countdown. Lives in `Shared` because the
/// App Intents behind the Lock Screen buttons run in the app's process and need
/// the same start/update/end path the workout screen uses.
enum RestActivity {
    /// Build the Lock Screen payload from the draft, or nil when nothing is resting.
    static func contentState(from snapshot: DraftSnapshot) -> RestTimerAttributes.ContentState? {
        guard let end = snapshot.restEndDate,
              let liftID = snapshot.restLiftID,
              let setIndex = snapshot.restSetIndex,
              let lift = snapshot.lift(liftID) else { return nil }

        let unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: "unit") ?? "") ?? .lb
        return RestTimerAttributes.ContentState(
            endDate: end,
            targetSeconds: snapshot.restTargetSeconds,
            liftName: lift.name,
            setNumber: setIndex + 1,
            totalSets: lift.reps.count,
            weightText: WeightFormat.string(lift.weightLb, unit),
            liftID: liftID,
            setIndex: setIndex
        )
    }

    /// Push the draft's rest state to the Lock Screen, starting or ending the
    /// activity as needed.
    static func sync(_ snapshot: DraftSnapshot) async {
        guard let state = contentState(from: snapshot) else {
            await end()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Stale 30 min past the end so an abandoned workout doesn't leave a
        // live-looking timer on the Lock Screen.
        let stale = state.endDate.addingTimeInterval(30 * 60)
        let content = ActivityContent(state: state, staleDate: stale)

        if let activity = current {
            await activity.update(content)
        } else {
            _ = try? Activity.request(
                attributes: RestTimerAttributes(workoutTitle: snapshot.title),
                content: content
            )
        }
    }

    static func end() async {
        guard let activity = current else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    private static var current: Activity<RestTimerAttributes>? {
        Activity<RestTimerAttributes>.activities.first
    }
}
