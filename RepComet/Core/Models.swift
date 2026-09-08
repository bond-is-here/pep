import Foundation

public struct ExerciseTemplate: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var category: String
    public var sets: Int
    public var reps: Int
    public var restSeconds: Int

    public init(id: UUID = UUID(), name: String, category: String, sets: Int = 3, reps: Int = 10, restSeconds: Int = 90) {
        self.id = id
        self.name = name
        self.category = category
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
    }
}

public struct Routine: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var subtitle: String
    public var symbol: String
    public var exercises: [ExerciseTemplate]

    public init(id: UUID = UUID(), name: String, subtitle: String = "Your own rhythm", symbol: String = "dumbbell.fill", exercises: [ExerciseTemplate] = []) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.symbol = symbol
        self.exercises = exercises
    }

    /// Approximate time for each set, rest between sets, and exercise transitions.
    public var estimatedMinutes: Int {
        guard !exercises.isEmpty else { return 0 }
        let seconds = exercises.reduce(0) { total, exercise in
            total + max(exercise.sets, 0) * 40 + max(exercise.sets - 1, 0) * max(exercise.restSeconds, 0) + 45
        }
        return max(1, Int((Double(seconds) / 60).rounded(.up)))
    }

    public var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
}

public struct WorkoutSet: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var reps: Int
    public var weightKG: Double
    public var isComplete: Bool

    public init(id: UUID = UUID(), reps: Int = 10, weightKG: Double = 0, isComplete: Bool = false) {
        self.id = id
        self.reps = reps
        self.weightKG = weightKG
        self.isComplete = isComplete
    }
}

public struct SessionExercise: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var sets: [WorkoutSet]
    public var restSeconds: Int

    public init(id: UUID = UUID(), name: String, sets: [WorkoutSet], restSeconds: Int = 90) {
        self.id = id
        self.name = name
        self.sets = sets
        self.restSeconds = restSeconds
    }

    public var completedSets: Int { sets.filter(\.isComplete).count }
    public var isComplete: Bool { !sets.isEmpty && sets.allSatisfy(\.isComplete) }
}

public struct WorkoutSession: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var routineName: String
    public var startedAt: Date
    public var finishedAt: Date?
    public var exercises: [SessionExercise]

    public init(id: UUID = UUID(), routineName: String, startedAt: Date = Date(), finishedAt: Date? = nil, exercises: [SessionExercise]) {
        self.id = id
        self.routineName = routineName
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exercises = exercises
    }

    public var completedSets: Int { exercises.reduce(0) { $0 + $1.completedSets } }
    public var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    public var completedExercises: Int { exercises.filter(\.isComplete).count }
    /// Only checked-off sets contribute to training volume.
    public var volumeKG: Double {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter(\.isComplete).reduce(0) { $0 + Double($1.reps) * $1.weightKG }
        }
    }
    public var duration: TimeInterval { max(0, (finishedAt ?? Date()).timeIntervalSince(startedAt)) }
}

public struct WeightEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var kilograms: Double

    public init(id: UUID = UUID(), date: Date = Date(), kilograms: Double) {
        self.id = id
        self.date = date
        self.kilograms = kilograms
    }
}

public enum WeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case kg
    case lb

    public var id: Self { self }
    public var symbol: String { rawValue }
    public var title: String { self == .kg ? "Kilograms" : "Pounds" }

    public func kilograms(from value: Double) -> Double {
        self == .kg ? value : value / 2.2046226218487757
    }

    public func value(fromKilograms kilograms: Double) -> Double {
        self == .kg ? kilograms : kilograms * 2.2046226218487757
    }
}
