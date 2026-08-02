import XCTest
import UserNotifications
@testable import LiftTracker

final class ReliabilityTests: XCTestCase {
    func testDraftMutationsAreSerialized() {
        let suiteName = "ReliabilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        DraftStore.save(snapshot(), to: defaults)
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            DraftStore.mutate(to: defaults) { draft in
                draft.bodyWeightLb = (draft.bodyWeightLb ?? 0) + 1
            }
        }

        XCTAssertEqual(DraftStore.load(from: defaults)?.bodyWeightLb, 100)
    }

    @MainActor
    func testLocalDraftMutationUsesTheLatestDurableSnapshot() {
        let suiteName = "ReliabilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let draft = WorkoutDraft(defaults: defaults)
        draft.reset(type: .a, weights: [:], rest: [:], bodyWeight: nil)
        DraftStore.mutate(to: defaults) { $0.bodyWeightLb = 180 }

        draft.setWeight(.squat, 100)

        let stored = DraftStore.load(from: defaults)
        XCTAssertEqual(stored?.bodyWeightLb, 180)
        XCTAssertEqual(stored?.lift(Exercise.squat.rawValue)?.weightLb, 100)
    }

    @MainActor
    func testMutationWithoutAStoredDraftStillApplies() {
        let suiteName = "ReliabilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let draft = WorkoutDraft(defaults: defaults)
        draft.reset(type: .a, weights: [:], rest: [:], bodyWeight: nil)
        DraftStore.clear(from: defaults)

        draft.setWeight(.squat, 105)

        XCTAssertEqual(draft.weight(.squat), 105)
        XCTAssertEqual(DraftStore.load(from: defaults)?.lift(Exercise.squat.rawValue)?.weightLb, 105)
    }

    @MainActor
    func testStoppingRestCancelsAnAddThatHasNotFinished() async {
        let center = TestNotificationCenter()
        let model = RestTimerModel(notificationCenter: center)
        var draft = snapshot()
        draft.restEndDate = .now.addingTimeInterval(60)
        draft.restTargetSeconds = 60

        model.sync(draft)
        await center.waitUntilAddStarts()
        model.stop()
        center.finishAdd()
        await model.waitForNotificationOperations()

        XCTAssertEqual(center.addedRequestIDs, [])
    }

    @MainActor
    func testStaleNotificationsFromAPreviousLaunchAreSwept() async {
        let center = TestNotificationCenter(pending: ["restTimerElapsed.stale"])
        let model = RestTimerModel(notificationCenter: center)

        await model.waitForNotificationOperations()

        XCTAssertEqual(center.addedRequestIDs, [])
    }

    private func snapshot() -> DraftSnapshot {
        DraftSnapshot(
            typeRaw: WorkoutType.a.rawValue,
            title: WorkoutType.a.title,
            lifts: [DraftLift(exerciseID: Exercise.squat.rawValue,
                              name: Exercise.squat.name,
                              weightLb: Exercise.squat.startingWeight,
                              targetReps: Exercise.targetReps,
                              reps: [nil],
                              skipped: false,
                              restSeconds: 60)]
        )
    }
}

private final class TestNotificationCenter: RestNotificationCenter {
    private var addContinuation: CheckedContinuation<Void, Never>?
    private(set) var addedRequestIDs: [String]

    init(pending: [String] = []) {
        addedRequestIDs = pending
    }

    func add(_ request: UNNotificationRequest) async throws {
        await withCheckedContinuation { continuation in
            addContinuation = continuation
        }
        addedRequestIDs.append(request.identifier)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        addedRequestIDs.removeAll { identifiers.contains($0) }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        addedRequestIDs.map {
            UNNotificationRequest(identifier: $0, content: UNMutableNotificationContent(), trigger: nil)
        }
    }

    func waitUntilAddStarts() async {
        while addContinuation == nil {
            await Task.yield()
        }
    }

    func finishAdd() {
        addContinuation?.resume()
        addContinuation = nil
    }
}
