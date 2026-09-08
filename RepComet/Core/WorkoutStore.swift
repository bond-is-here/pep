import Foundation
import Observation

@Observable
public final class WorkoutStore {
    public private(set) var routines: [Routine] = []
    public private(set) var sessions: [WorkoutSession] = []
    public private(set) var weights: [WeightEntry] = []
    public private(set) var activeSession: WorkoutSession?
    public private(set) var restEndsAt: Date?
    public private(set) var unit: WeightUnit = .kg
    public private(set) var weeklyGoal: Int = 3
    public private(set) var persistenceError: String?

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var canWrite = true
    @ObservationIgnored private var recoveryNotice: String?

    /// A file URL and clock can be supplied for isolated stores and deterministic tests.
    public init(fileURL: URL? = nil, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.calendar = calendar
        self.now = now
        load()
    }

    public var sessionsThisWeek: [WorkoutSession] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now()) else { return [] }
        return sessions.filter { session in
            guard let date = session.finishedAt else { return false }
            return date >= interval.start && date < interval.end
        }
    }

    public var weeklyCompletedDays: [Date] {
        Array(Set(sessionsThisWeek.compactMap(\.finishedAt).map { calendar.startOfDay(for: $0) })).sorted()
    }

    public var totalVolumeKG: Double { sessions.reduce(0) { $0 + $1.volumeKG } }

    /// Mutation methods return whether the input was accepted. Disk failures are reported in persistenceError.
    @discardableResult
    public func addRoutine(_ routine: Routine) -> Bool {
        guard let routine = validatedRoutine(routine),
              !routines.contains(where: { $0.id == routine.id }),
              !hasRoutineNameConflict(routine) else { return false }
        routines.append(routine)
        save()
        return true
    }

    @discardableResult
    public func updateRoutine(_ routine: Routine) -> Bool {
        guard let routine = validatedRoutine(routine),
              let index = routines.firstIndex(where: { $0.id == routine.id }),
              !hasRoutineNameConflict(routine, excluding: routine.id) else { return false }
        routines[index] = routine
        save()
        return true
    }

    @discardableResult
    public func deleteRoutine(id: UUID) -> Bool {
        guard routines.contains(where: { $0.id == id }) else { return false }
        routines.removeAll { $0.id == id }
        save()
        return true
    }

    @discardableResult
    public func startWorkout(_ routine: Routine) -> Bool {
        guard activeSession == nil, let routine = validatedRoutine(routine) else { return false }
        let previous = sessions.first { session in
            if let routineID = session.routineID { return routineID == routine.id }
            return session.routineName.caseInsensitiveCompare(routine.name) == .orderedSame
        }
        activeSession = WorkoutSession(routineID: routine.id, routineName: routine.name, startedAt: now(), exercises: routine.exercises.map { exercise in
            let previousExercise = previous?.exercises.first { $0.name == exercise.name }
            return SessionExercise(name: exercise.name, sets: (0..<exercise.sets).map { setIndex in
                let previousSet = previousExercise?.sets.indices.contains(setIndex) == true ? previousExercise?.sets[setIndex] : nil
                return WorkoutSet(reps: exercise.reps, weightKG: previousSet?.isComplete == true ? previousSet!.weightKG : 0)
            }, restSeconds: exercise.restSeconds)
        })
        save()
        return true
    }

    @discardableResult
    public func updateSet(exerciseID: UUID, setID: UUID, reps: Int, weightKG: Double) -> Bool {
        guard (1...1_000).contains(reps), weightKG.isFinite, (0...1_500).contains(weightKG),
              let indexes = setIndexes(exerciseID: exerciseID, setID: setID) else { return false }
        activeSession!.exercises[indexes.exercise].sets[indexes.set].reps = reps
        activeSession!.exercises[indexes.exercise].sets[indexes.set].weightKG = weightKG
        save()
        return true
    }

    @discardableResult
    public func toggleSet(exerciseID: UUID, setID: UUID) -> Bool {
        guard let indexes = setIndexes(exerciseID: exerciseID, setID: setID) else { return false }
        activeSession!.exercises[indexes.exercise].sets[indexes.set].isComplete.toggle()
        save()
        return true
    }

    @discardableResult
    public func addSet(exerciseID: UUID) -> Bool {
        guard let index = activeSession?.exercises.firstIndex(where: { $0.id == exerciseID }),
              activeSession!.exercises[index].sets.count < 20 else { return false }
        let lastSet = activeSession!.exercises[index].sets.last
        activeSession!.exercises[index].sets.append(WorkoutSet(reps: lastSet?.reps ?? 10, weightKG: lastSet?.weightKG ?? 0))
        save()
        return true
    }

    @discardableResult
    public func removeSet(exerciseID: UUID, setID: UUID) -> Bool {
        guard let indexes = setIndexes(exerciseID: exerciseID, setID: setID),
              activeSession!.exercises[indexes.exercise].sets.count > 1 else { return false }
        activeSession!.exercises[indexes.exercise].sets.remove(at: indexes.set)
        save()
        return true
    }

    @discardableResult
    public func finishWorkout() -> WorkoutSession? {
        guard var session = activeSession, session.completedSets > 0 else { return nil }
        session.finishedAt = max(session.startedAt, now())
        sessions.insert(session, at: 0)
        activeSession = nil
        restEndsAt = nil
        save()
        return session
    }

    public func discardWorkout() {
        activeSession = nil
        restEndsAt = nil
        save()
    }

    @discardableResult
    public func beginRest(seconds: Int) -> Bool {
        guard activeSession != nil, (0...3_600).contains(seconds) else { return false }
        restEndsAt = seconds == 0 ? nil : now().addingTimeInterval(TimeInterval(seconds))
        save()
        return true
    }

    public func clearRest() {
        restEndsAt = nil
        save()
    }

    @discardableResult
    public func addWeight(kilograms: Double, date: Date = Date()) -> Bool {
        guard kilograms.isFinite, kilograms > 0, kilograms <= 1_000, date.timeIntervalSinceReferenceDate.isFinite else { return false }
        weights.append(WeightEntry(date: date, kilograms: kilograms))
        weights.sort { $0.date > $1.date }
        save()
        return true
    }

    @discardableResult
    public func deleteWeight(id: UUID) -> Bool {
        guard weights.contains(where: { $0.id == id }) else { return false }
        weights.removeAll { $0.id == id }
        save()
        return true
    }

    public func setUnit(_ unit: WeightUnit) {
        self.unit = unit
        save()
    }

    @discardableResult
    public func setWeeklyGoal(_ goal: Int) -> Bool {
        guard (1...7).contains(goal) else { return false }
        weeklyGoal = goal
        save()
        return true
    }

    @discardableResult
    public func save() -> Bool {
        guard canWrite else { return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let snapshot = Snapshot(schemaVersion: 1, routines: routines, sessions: sessions, weights: weights,
                                    activeSession: activeSession, restEndsAt: restEndsAt, unit: unit, weeklyGoal: weeklyGoal)
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = recoveryNotice
            return true
        } catch {
            persistenceError = "Pep couldn't save your changes. Your current progress is still open. \(error.localizedDescription)"
            return false
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            routines = Self.starterRoutines
            save()
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(Snapshot.self, from: Data(contentsOf: fileURL))
            guard snapshot.schemaVersion == 1 else {
                // A newer version is left untouched so an older app cannot erase it.
                canWrite = false
                persistenceError = "This Pep data was created by a newer app version. Update the app to open it. Your saved file is unchanged."
                return
            }
            routines = snapshot.routines
            sessions = snapshot.sessions.sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }
            weights = snapshot.weights.sorted { $0.date > $1.date }
            activeSession = snapshot.activeSession
            restEndsAt = snapshot.restEndsAt
            unit = snapshot.unit
            weeklyGoal = (1...7).contains(snapshot.weeklyGoal) ? snapshot.weeklyGoal : 3
        } catch {
            routines = Self.starterRoutines
            let backup = fileURL.deletingPathExtension().appendingPathExtension("recovered-\(UUID().uuidString).json")
            do {
                try FileManager.default.moveItem(at: fileURL, to: backup)
                recoveryNotice = "Pep couldn't read your saved data. A backup was kept as \(backup.lastPathComponent). You can start fresh, and the backup will stay safe."
                persistenceError = recoveryNotice
            } catch {
                canWrite = false
                persistenceError = "Pep couldn't read or back up your saved data. Your original file is unchanged. New changes cannot be saved until the file is accessible."
            }
        }
    }

    private func setIndexes(exerciseID: UUID, setID: UUID) -> (exercise: Int, set: Int)? {
        guard let session = activeSession,
              let exercise = session.exercises.firstIndex(where: { $0.id == exerciseID }),
              let set = session.exercises[exercise].sets.firstIndex(where: { $0.id == setID }) else { return nil }
        return (exercise, set)
    }

    private func hasRoutineNameConflict(_ routine: Routine, excluding id: UUID? = nil) -> Bool {
        routines.contains { existing in
            existing.id != id && existing.name.caseInsensitiveCompare(routine.name) == .orderedSame
        }
    }

    private func validatedRoutine(_ routine: Routine) -> Routine? {
        var routine = routine
        routine.name = routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !routine.name.isEmpty, routine.name.count <= 80,
              !routine.exercises.isEmpty, routine.exercises.count <= 40,
              Set(routine.exercises.map(\.id)).count == routine.exercises.count else { return nil }
        for index in routine.exercises.indices {
            routine.exercises[index].name = routine.exercises[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            let exercise = routine.exercises[index]
            guard !exercise.name.isEmpty, exercise.name.count <= 100,
                  (1...20).contains(exercise.sets), (1...1_000).contains(exercise.reps),
                  (0...3_600).contains(exercise.restSeconds) else { return nil }
        }
        return routine
    }

    private static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("RepComet", isDirectory: true).appendingPathComponent("workouts.json")
    }

    private struct Snapshot: Codable {
        var schemaVersion: Int
        var routines: [Routine]
        var sessions: [WorkoutSession]
        var weights: [WeightEntry]
        var activeSession: WorkoutSession?
        var restEndsAt: Date?
        var unit: WeightUnit
        var weeklyGoal: Int
    }
}
