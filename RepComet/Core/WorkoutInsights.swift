import Foundation

public extension WorkoutStore {
    /// Try an unlogged routine first, then rotate to the one least recently finished.
    /// This is a history shortcut, not a prescription or a recovery recommendation.
    var suggestedRoutine: Routine? {
        routines.enumerated().min { left, right in
            let leftDate = lastCompletedDate(for: left.element)
            let rightDate = lastCompletedDate(for: right.element)
            if leftDate == rightDate { return left.offset < right.offset }
            return (leftDate ?? .distantPast) < (rightDate ?? .distantPast)
        }?.element
    }

    func lastCompletedDate(for routine: Routine) -> Date? {
        sessions.filter { session in
            guard session.completedSets > 0, session.finishedAt != nil else { return false }
            if let routineID = session.routineID { return routineID == routine.id }
            return session.routineName.caseInsensitiveCompare(routine.name) == .orderedSame
        }.compactMap(\.finishedAt).max()
    }

    var momentum: WorkoutMomentum {
        WorkoutMomentum(completedWorkouts: sessions.filter { $0.finishedAt != nil && $0.completedSets > 0 }.count)
    }
}

public struct WorkoutMomentum: Equatable, Sendable {
    public let completedWorkouts: Int
    public let target: Int

    public init(completedWorkouts: Int) {
        let completed = max(0, completedWorkouts)
        self.completedWorkouts = completed
        let milestones = [1, 5, 10, 25, 50, 100, 250, 500, 1_000]
        // Stay on a just-earned milestone until the next workout, so it can be celebrated.
        target = milestones.first(where: { $0 >= completed }) ?? (completed <= Int.max - 1_000 ? ((completed - 1) / 1_000 + 1) * 1_000 : Int.max)
    }

    public var isEarned: Bool { completedWorkouts >= target }
    public var remaining: Int { max(0, target - completedWorkouts) }
    public var fraction: Double { min(1, Double(completedWorkouts) / Double(target)) }
    public var title: String {
        switch target {
        case 1: return "Your first little win"
        case 5: return "The high-five club"
        case 10: return "Ten out of ten"
        case 25: return "A quarter century of you"
        case 50: return "Fifty feels good"
        case 100: return "The hundred club"
        default: return "\(target) little wins"
        }
    }
}
