import Foundation
import Observation

public struct WorkoutBackupSummary: Equatable, Sendable {
    public let routineCount: Int
    public let sessionCount: Int
    public let weightCount: Int
    public let hasActiveWorkout: Bool
}

public enum WorkoutBackupError: LocalizedError {
    case invalidData
    case unsupportedVersion
    case activeWorkoutInProgress
    case readOnly
    case tooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "This file isn't a valid Pep backup. Choose an unedited backup exported from Pep. Your current data is unchanged."
        case .unsupportedVersion:
            return "This backup uses a different Pep data version. Update Pep before opening it. Your current data is unchanged."
        case .activeWorkoutInProgress:
            return "Finish or discard your current workout before restoring a backup. Your current data is unchanged."
        case .readOnly:
            return "Pep can't replace saved data while it is unavailable or requires a newer app version. Your saved file is unchanged."
        case .tooLarge:
            return "This backup is too large to open safely. Pep supports backups up to 20 MB. Your current data is unchanged."
        }
    }
}

@Observable
public final class WorkoutStore {
    public static let maxBackupBytes = 20_000_000
    public private(set) var routines: [Routine] = []
    public private(set) var sessions: [WorkoutSession] = []
    public private(set) var weights: [WeightEntry] = []
    public private(set) var activeSession: WorkoutSession?
    public private(set) var restEndsAt: Date?
    public private(set) var unit: WeightUnit = .kg
    public private(set) var weeklyGoal: Int = 3
    public private(set) var persistenceError: String?
    public private(set) var hasUnsavedChanges = false
    /// Incompatible or inaccessible existing data must never be overwritten.
    public var isReadOnly: Bool { !canWrite }

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

    /// Finished history and library changes succeed only after being saved. Active
    /// set edits stay in memory on a disk failure so the user can retry saving.
    @discardableResult
    public func addRoutine(_ routine: Routine) -> Bool {
        guard !isReadOnly, let routine = validatedRoutine(routine),
              !routines.contains(where: { $0.id == routine.id }),
              !hasRoutineNameConflict(routine) else { return false }
        var snapshot = currentSnapshot
        snapshot.routines.append(routine)
        return persist(snapshot)
    }

    @discardableResult
    public func updateRoutine(_ routine: Routine) -> Bool {
        guard !isReadOnly, let routine = validatedRoutine(routine),
              let index = routines.firstIndex(where: { $0.id == routine.id }),
              !hasRoutineNameConflict(routine, excluding: routine.id) else { return false }
        var snapshot = currentSnapshot
        let previousName = routines[index].name
        // Link legacy history before a name change, only when its old name
        // identifies this one routine unambiguously.
        if routines.filter({ $0.name.caseInsensitiveCompare(previousName) == .orderedSame }).count == 1 {
            for sessionIndex in snapshot.sessions.indices where snapshot.sessions[sessionIndex].routineID == nil &&
                snapshot.sessions[sessionIndex].routineName.caseInsensitiveCompare(previousName) == .orderedSame {
                snapshot.sessions[sessionIndex].routineID = routine.id
            }
            if snapshot.activeSession?.routineID == nil,
               snapshot.activeSession?.routineName.caseInsensitiveCompare(previousName) == .orderedSame {
                snapshot.activeSession?.routineID = routine.id
            }
        }
        snapshot.routines[index] = routine
        return persist(snapshot)
    }

    @discardableResult
    public func deleteRoutine(id: UUID) -> Bool {
        guard !isReadOnly, routines.contains(where: { $0.id == id }) else { return false }
        var snapshot = currentSnapshot
        snapshot.routines.removeAll { $0.id == id }
        return persist(snapshot)
    }

    @discardableResult
    public func startWorkout(_ routine: Routine) -> Bool {
        guard !isReadOnly, activeSession == nil, let routine = validatedRoutine(routine), Self.validDate(now()) else { return false }
        let previousSessions = sessions.filter { session in
            if let routineID = session.routineID { return routineID == routine.id }
            return session.routineName.caseInsensitiveCompare(routine.name) == .orderedSame
        }
        activeSession = WorkoutSession(routineID: routine.id, routineName: routine.name, startedAt: now(), exercises: routine.exercises.map { exercise in
            return SessionExercise(name: exercise.name, sets: (0..<exercise.sets).map { setIndex in
                let previousSet = previousSessions.lazy.compactMap { session -> WorkoutSet? in
                    guard let previousExercise = session.exercises.first(where: { $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame }),
                          previousExercise.sets.indices.contains(setIndex) else { return nil }
                    let set = previousExercise.sets[setIndex]
                    return set.isComplete ? set : nil
                }.first
                return WorkoutSet(reps: exercise.reps, weightKG: previousSet?.weightKG ?? 0)
            }, restSeconds: exercise.restSeconds)
        })
        save()
        return true
    }

    @discardableResult
    public func updateSet(exerciseID: UUID, setID: UUID, reps: Int, weightKG: Double) -> Bool {
        guard !isReadOnly, (1...1_000).contains(reps), weightKG.isFinite, (0...1_500).contains(weightKG),
              let indexes = setIndexes(exerciseID: exerciseID, setID: setID) else { return false }
        activeSession!.exercises[indexes.exercise].sets[indexes.set].reps = reps
        activeSession!.exercises[indexes.exercise].sets[indexes.set].weightKG = weightKG
        save()
        return true
    }

    @discardableResult
    public func toggleSet(exerciseID: UUID, setID: UUID) -> Bool {
        guard !isReadOnly, let indexes = setIndexes(exerciseID: exerciseID, setID: setID) else { return false }
        activeSession!.exercises[indexes.exercise].sets[indexes.set].isComplete.toggle()
        save()
        return true
    }

    @discardableResult
    public func addSet(exerciseID: UUID) -> Bool {
        guard !isReadOnly, let index = activeSession?.exercises.firstIndex(where: { $0.id == exerciseID }),
              activeSession!.exercises[index].sets.count < 20 else { return false }
        let lastSet = activeSession!.exercises[index].sets.last
        activeSession!.exercises[index].sets.append(WorkoutSet(reps: lastSet?.reps ?? 10, weightKG: lastSet?.weightKG ?? 0))
        save()
        return true
    }

    @discardableResult
    public func removeSet(exerciseID: UUID, setID: UUID) -> Bool {
        guard !isReadOnly, let indexes = setIndexes(exerciseID: exerciseID, setID: setID),
              activeSession!.exercises[indexes.exercise].sets.count > 1 else { return false }
        activeSession!.exercises[indexes.exercise].sets.remove(at: indexes.set)
        save()
        return true
    }

    @discardableResult
    public func finishWorkout() -> WorkoutSession? {
        guard !isReadOnly, var session = activeSession, session.completedSets > 0, Self.validDate(now()) else { return nil }
        session.finishedAt = max(session.startedAt, now())
        var snapshot = currentSnapshot
        snapshot.sessions.insert(session, at: 0)
        snapshot.activeSession = nil
        snapshot.restEndsAt = nil
        return persist(snapshot) ? session : nil
    }

    @discardableResult
    public func discardWorkout() -> Bool {
        guard !isReadOnly else { return false }
        var snapshot = currentSnapshot
        snapshot.activeSession = nil
        snapshot.restEndsAt = nil
        return persist(snapshot)
    }

    @discardableResult
    public func deleteSession(id: UUID) -> Bool {
        guard !isReadOnly, sessions.contains(where: { $0.id == id }) else { return false }
        var snapshot = currentSnapshot
        snapshot.sessions.removeAll { $0.id == id }
        return persist(snapshot)
    }

    @discardableResult
    public func beginRest(seconds: Int) -> Bool {
        guard !isReadOnly, activeSession != nil, (0...3_600).contains(seconds), Self.validDate(now()) else { return false }
        restEndsAt = seconds == 0 ? nil : now().addingTimeInterval(TimeInterval(seconds))
        save()
        return true
    }

    public func clearRest() {
        guard !isReadOnly else { return }
        restEndsAt = nil
        save()
    }

    @discardableResult
    public func addWeight(kilograms: Double, date: Date = Date()) -> Bool {
        guard !isReadOnly, kilograms.isFinite, kilograms > 0, kilograms <= 1_000, Self.validDate(date) else { return false }
        var snapshot = currentSnapshot
        snapshot.weights.append(WeightEntry(date: date, kilograms: kilograms))
        return persist(snapshot)
    }

    @discardableResult
    public func deleteWeight(id: UUID) -> Bool {
        guard !isReadOnly, weights.contains(where: { $0.id == id }) else { return false }
        var snapshot = currentSnapshot
        snapshot.weights.removeAll { $0.id == id }
        return persist(snapshot)
    }

    public func setUnit(_ unit: WeightUnit) {
        guard !isReadOnly else { return }
        var snapshot = currentSnapshot
        snapshot.unit = unit
        _ = persist(snapshot)
    }

    @discardableResult
    public func setWeeklyGoal(_ goal: Int) -> Bool {
        guard !isReadOnly, (1...7).contains(goal) else { return false }
        var snapshot = currentSnapshot
        snapshot.weeklyGoal = goal
        return persist(snapshot)
    }

    @discardableResult
    public func save() -> Bool {
        guard canWrite else { return false }
        do {
            try write(currentSnapshot)
            hasUnsavedChanges = false
            persistenceError = recoveryNotice
            return true
        } catch {
            hasUnsavedChanges = true
            persistenceError = "Pep couldn't save your changes. Your current progress is still open. \(error.localizedDescription)"
            return false
        }
    }

    /// Exports the current progress, including unsaved active sets after a disk
    /// failure, so a user can keep a copy outside the app.
    public func exportBackup() throws -> Data {
        guard !isReadOnly else { throw WorkoutBackupError.readOnly }
        let snapshot = try validatedSnapshot(currentSnapshot)
        return try encoded(snapshot)
    }

    /// Validates without mutating data. Show this summary before confirming a restore.
    public func backupSummary(_ data: Data) throws -> WorkoutBackupSummary {
        let snapshot = try decodeSnapshot(data)
        return WorkoutBackupSummary(routineCount: snapshot.routines.count,
                                    sessionCount: snapshot.sessions.count,
                                    weightCount: snapshot.weights.count,
                                    hasActiveWorkout: snapshot.activeSession != nil)
    }

    /// Replaces data only after validation and an atomic disk write both succeed.
    /// Restoring an active workout from the backup is allowed; overwriting one
    /// currently open on this device is not.
    public func restoreBackup(_ data: Data) throws {
        guard !isReadOnly else { throw WorkoutBackupError.readOnly }
        guard activeSession == nil else { throw WorkoutBackupError.activeWorkoutInProgress }
        let snapshot = try decodeSnapshot(data)
        try write(snapshot)
        apply(snapshot)
        hasUnsavedChanges = false
        recoveryNotice = nil
        persistenceError = nil
    }

    private var currentSnapshot: Snapshot {
        Snapshot(schemaVersion: 1, routines: routines, sessions: sessions, weights: weights,
                 activeSession: activeSession, restEndsAt: restEndsAt, unit: unit, weeklyGoal: weeklyGoal)
    }

    private func encoded(_ snapshot: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        guard data.count <= Self.maxBackupBytes else { throw WorkoutBackupError.tooLarge }
        return data
    }

    private func write(_ snapshot: Snapshot) throws {
        let data = try encoded(snapshot)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private func persist(_ snapshot: Snapshot) -> Bool {
        guard !isReadOnly else { return false }
        do {
            try write(snapshot)
            apply(snapshot)
            hasUnsavedChanges = false
            persistenceError = recoveryNotice
            return true
        } catch {
            persistenceError = "Pep couldn't save this change. Your previous data and current workout are unchanged. \(error.localizedDescription)"
            return false
        }
    }

    private func apply(_ snapshot: Snapshot) {
        routines = snapshot.routines
        sessions = snapshot.sessions.sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }
        weights = snapshot.weights.sorted { $0.date > $1.date }
        activeSession = snapshot.activeSession
        restEndsAt = snapshot.restEndsAt
        unit = snapshot.unit
        weeklyGoal = snapshot.weeklyGoal
    }

    private func load() {
        let data: Data
        do {
            let properties = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard properties.isRegularFile == true else { throw CocoaError(.fileReadUnknown) }
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            data = try handle.read(upToCount: Self.maxBackupBytes + 1) ?? Data()
        } catch let error as NSError where Self.isMissingFile(error) {
            routines = Self.starterRoutines
            save()
            return
        } catch {
            // Read failures can be temporary (for example, device data protection).
            // A file that cannot be read is not evidence of corrupt contents.
            canWrite = false
            persistenceError = "Pep can't access your saved data right now. Your original file is unchanged. Reopen Pep when the file is available."
            return
        }
        do {
            apply(try decodeSnapshot(data))
        } catch WorkoutBackupError.unsupportedVersion {
            canWrite = false
            persistenceError = "This Pep data uses a different app version. Update to a newer Pep version to open it. Your saved file is unchanged."
        } catch WorkoutBackupError.tooLarge {
            canWrite = false
            persistenceError = "Your saved data is too large for this Pep version to open safely. Your original file is unchanged."
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

    private func decodeSnapshot(_ data: Data) throws -> Snapshot {
        guard data.count <= Self.maxBackupBytes else { throw WorkoutBackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            // Read the version independently: future versions may replace every
            // other field, and must never enter corrupt-file recovery.
            let header = try decoder.decode(SnapshotHeader.self, from: data)
            guard header.schemaVersion == 1 else { throw WorkoutBackupError.unsupportedVersion }
            return try validatedSnapshot(decoder.decode(Snapshot.self, from: data))
        } catch let error as WorkoutBackupError {
            throw error
        } catch {
            throw WorkoutBackupError.invalidData
        }
    }

    private func validatedSnapshot(_ snapshot: Snapshot) throws -> Snapshot {
        guard (1...7).contains(snapshot.weeklyGoal),
              Self.uniqueIDs(snapshot.routines), Self.uniqueIDs(snapshot.sessions), Self.uniqueIDs(snapshot.weights) else {
            throw WorkoutBackupError.invalidData
        }
        var snapshot = snapshot
        for index in snapshot.routines.indices {
            guard let routine = validatedRoutine(snapshot.routines[index]) else { throw WorkoutBackupError.invalidData }
            snapshot.routines[index] = routine
        }
        for session in snapshot.sessions {
            guard validSession(session, isActive: false) else { throw WorkoutBackupError.invalidData }
        }
        if let active = snapshot.activeSession {
            guard validSession(active, isActive: true), !snapshot.sessions.contains(where: { $0.id == active.id }) else {
                throw WorkoutBackupError.invalidData
            }
        }
        if let rest = snapshot.restEndsAt {
            guard snapshot.activeSession != nil, Self.validDate(rest) else { throw WorkoutBackupError.invalidData }
        }
        for weight in snapshot.weights {
            guard Self.validDate(weight.date), weight.kilograms.isFinite, weight.kilograms > 0, weight.kilograms <= 1_000 else {
                throw WorkoutBackupError.invalidData
            }
        }
        return snapshot
    }

    private func validSession(_ session: WorkoutSession, isActive: Bool) -> Bool {
        guard !session.routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              session.routineName.count <= 80, Self.validDate(session.startedAt),
              (1...40).contains(session.exercises.count), Self.uniqueIDs(session.exercises),
              Self.uniqueIDs(session.exercises.flatMap(\.sets)) else { return false }
        if isActive {
            guard session.finishedAt == nil else { return false }
        } else {
            guard let finish = session.finishedAt, Self.validDate(finish), finish >= session.startedAt else { return false }
        }
        for exercise in session.exercises {
            guard !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  exercise.name.count <= 100, (0...3_600).contains(exercise.restSeconds),
                  (1...20).contains(exercise.sets.count), Self.uniqueIDs(exercise.sets) else { return false }
            for set in exercise.sets {
                guard (1...1_000).contains(set.reps), set.weightKG.isFinite, (0...1_500).contains(set.weightKG) else { return false }
            }
        }
        return isActive || session.completedSets > 0
    }

    private static func uniqueIDs<T: Identifiable>(_ values: [T]) -> Bool where T.ID: Hashable {
        Set(values.map(\.id)).count == values.count
    }

    private static func validDate(_ date: Date) -> Bool {
        let seconds = date.timeIntervalSince1970
        // A bounded Gregorian range keeps Foundation calendars and UI formatters
        // safe while allowing old imports and a device clock set in the future.
        return seconds.isFinite && (-62_135_596_800...253_402_300_799).contains(seconds)
    }

    private static func isMissingFile(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError { return true }
        // ENOENT and ENOTDIR prove that no saved file exists at this path. Other
        // IO errors (especially access denied) must preserve read-only state.
        if error.domain == NSPOSIXErrorDomain && [2, 20].contains(error.code) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isMissingFile(underlying)
        }
        return false
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
              routine.subtitle.count <= 200, routine.symbol.count <= 100,
              !routine.exercises.isEmpty, routine.exercises.count <= 40,
              Set(routine.exercises.map(\.id)).count == routine.exercises.count else { return nil }
        for index in routine.exercises.indices {
            routine.exercises[index].name = routine.exercises[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            let exercise = routine.exercises[index]
            guard !exercise.name.isEmpty, exercise.name.count <= 100,
                  exercise.category.count <= 100,
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

    private struct SnapshotHeader: Decodable {
        var schemaVersion: Int
    }
}
