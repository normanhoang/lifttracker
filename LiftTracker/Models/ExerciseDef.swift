import Foundation

/// The two alternating workout days.
enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"

    var id: String { rawValue }
    var title: String { "Workout \(rawValue)" }
    var other: WorkoutType { self == .a ? .b : .a }

    /// Exercises performed on this day, in order.
    var slots: [ExerciseSlot] {
        switch self {
        case .a:
            return [
                ExerciseSlot(exercise: .squat, sets: 5),
                ExerciseSlot(exercise: .bench, sets: 5),
                ExerciseSlot(exercise: .row, sets: 5),
            ]
        case .b:
            return [
                ExerciseSlot(exercise: .squat, sets: 5),
                ExerciseSlot(exercise: .ohp, sets: 5),
                ExerciseSlot(exercise: .deadlift, sets: 1),
            ]
        }
    }
}

/// The five lifts and their static configuration.
enum Exercise: String, Codable, CaseIterable, Identifiable {
    case squat, bench, row, ohp, deadlift

    static let targetReps = 5

    var id: String { rawValue }

    var name: String {
        switch self {
        case .squat: return "Squat"
        case .bench: return "Bench Press"
        case .row: return "Barbell Row"
        case .ohp: return "Overhead Press"
        case .deadlift: return "Deadlift"
        }
    }

    /// Pounds added after a successful session.
    var increment: Double { self == .deadlift ? 10 : 5 }

    /// Default working weight (lb) seeded on first launch.
    var startingWeight: Double {
        switch self {
        case .squat: return 45
        case .bench: return 45
        case .row: return 65
        case .ohp: return 45
        case .deadlift: return 95
        }
    }

    /// Squat + Bench + Deadlift make up the "Total" on the Progress screen.
    var countsTowardTotal: Bool {
        self == .squat || self == .bench || self == .deadlift
    }
}

/// One exercise as it appears in a workout day (which lift, how many sets).
struct ExerciseSlot: Identifiable {
    let exercise: Exercise
    let sets: Int
    var id: String { exercise.id }
}
