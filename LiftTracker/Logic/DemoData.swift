#if DEBUG
import Foundation
import SwiftData

/// Ten weeks of plausible training, for App Store screenshots. The redesigned
/// History and Progress screens are the ones that need data to look like
/// anything, and a fresh install shows neither.
///
/// Debug-only: this never compiles into a Release build.
enum DemoData {
    /// Wipe and rebuild. Sessions are run through `Progression` as they are
    /// generated, so the working weights, streaks and bests on the Progress and
    /// Settings screens agree with the history behind them.
    static func reset(_ context: ModelContext, now: Date = .now) {
        for s in (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? [] { context.delete(s) }
        for b in (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? [] { context.delete(b) }

        let rows = (try? context.fetch(FetchDescriptor<ExerciseProgress>())) ?? []
        var byID: [String: ExerciseProgress] = [:]
        for row in rows {
            guard let ex = row.exercise else { continue }
            row.currentWeight = ex.startingWeight
            row.failStreak = 0
            row.successStreak = 0
            row.bestWeight = 0
            row.restSeconds = ex.defaultRestSeconds
            byID[row.exerciseID] = row
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -67, to: today) else { return }

        var index = 0
        for week in 0..<10 {
            for day in [0, 2, 4] {
                guard let date = calendar.date(byAdding: .day, value: week * 7 + day, to: start),
                      date < today,
                      let at = calendar.date(bySettingHour: 8, minute: 5, second: 0, of: date)
                else { continue }

                let type: WorkoutType = index.isMultiple(of: 2) ? .a : .b
                let session = WorkoutSession(date: at, type: type)

                for slot in type.slots {
                    guard let prog = byID[slot.exercise.rawValue] else { continue }
                    let reps = repsFor(slot: slot, sessionIndex: index)
                    let logged = LoggedExercise(
                        exerciseID: slot.exercise.rawValue,
                        weight: prog.currentWeight,
                        reps: reps,
                        targetSets: slot.sets,
                        targetReps: Exercise.targetReps
                    )
                    logged.isPR = prog.bestWeight > 0 && prog.currentWeight > prog.bestWeight
                    prog.bestWeight = max(prog.bestWeight, prog.currentWeight)
                    logged.session = session
                    session.exercises.append(logged)
                }

                session.durationSeconds = Double(2400 + (index % 5) * 240)
                session.volumeLb = session.exercises.reduce(0) { $0 + $1.volumeLb }
                context.insert(session)
                Progression.apply(session: session) { id in
                    byID[id] ?? ExerciseProgress(exerciseID: id, currentWeight: 45)
                }
                index += 1
            }
        }

        // A weigh-in most weeks, drifting down.
        for week in 0..<10 {
            guard let date = calendar.date(byAdding: .day, value: week * 7 + 1, to: start) else { continue }
            context.insert(BodyWeightEntry(date: date, weightLb: 184 - Double(week) * 0.6))
        }

        do { try context.save() } catch {
            print("DemoData: failed to save: \(error)")
        }
    }

    /// Mostly clean, with a scripted stall so the screens show their amber state:
    /// overhead press misses the last two sessions, and squat missed once early,
    /// which is the annotation on the lift-detail chart.
    private static func repsFor(slot: ExerciseSlot, sessionIndex: Int) -> [Int] {
        switch slot.exercise {
        case .ohp where sessionIndex >= 25:
            return [5, 5, 5, 4, 3]
        case .squat where sessionIndex == 12:
            return [5, 5, 5, 5, 4]
        default:
            return Array(repeating: Exercise.targetReps, count: slot.sets)
        }
    }
}
#endif
