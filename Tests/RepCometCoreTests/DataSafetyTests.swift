import Foundation
import XCTest
@testable import RepCometCore

final class DataSafetyTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("workouts.json") }
    private let fixedDate = Date(timeIntervalSince1970: 1_788_800_400)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("PepDataSafety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try FileManager.default.removeItem(at: directory)
    }

    func testBackupRoundTripPreservesHistorySettingsAndResumableWorkout() throws {
        let source = WorkoutStore(fileURL: fileURL, now: { self.fixedDate })
        try finishOneWorkout(source)
        XCTAssertTrue(source.addWeight(kilograms: 73.25, date: fixedDate))
        source.setUnit(.lb)
        XCTAssertTrue(source.setWeeklyGoal(5))
        XCTAssertTrue(source.startWorkout(source.routines[1]))
        let exercise = try XCTUnwrap(source.activeSession?.exercises.first)
        XCTAssertTrue(source.updateSet(exerciseID: exercise.id, setID: exercise.sets[0].id, reps: 8, weightKG: 37.5))
        XCTAssertTrue(source.toggleSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertTrue(source.beginRest(seconds: 120))
        let backup = try source.exportBackup()

        let destinationURL = directory.appendingPathComponent("restored.json")
        let destination = WorkoutStore(fileURL: destinationURL)
        let beforePreview = try Data(contentsOf: destinationURL)
        let summary = try destination.backupSummary(backup)
        XCTAssertEqual(summary.routineCount, 3)
        XCTAssertEqual(summary.sessionCount, 1)
        XCTAssertEqual(summary.weightCount, 1)
        XCTAssertTrue(summary.hasActiveWorkout)
        XCTAssertEqual(try Data(contentsOf: destinationURL), beforePreview, "Preview never modifies saved data.")
        try destination.restoreBackup(backup)

        let reopened = WorkoutStore(fileURL: destinationURL)
        XCTAssertEqual(reopened.routines, source.routines)
        XCTAssertEqual(reopened.sessions, source.sessions)
        XCTAssertEqual(reopened.weights, source.weights)
        XCTAssertEqual(reopened.activeSession, source.activeSession)
        XCTAssertEqual(reopened.restEndsAt, source.restEndsAt)
        XCTAssertEqual(reopened.unit, .lb)
        XCTAssertEqual(reopened.weeklyGoal, 5)
        XCTAssertNil(reopened.persistenceError)
    }

    func testRestoreCannotReplaceCurrentWorkout() throws {
        let store = WorkoutStore(fileURL: fileURL, now: { self.fixedDate })
        let backup = try store.exportBackup()
        XCTAssertTrue(store.startWorkout(store.routines[0]))
        let active = store.activeSession
        let original = try Data(contentsOf: fileURL)
        XCTAssertThrowsError(try store.restoreBackup(backup)) { error in
            guard case WorkoutBackupError.activeWorkoutInProgress = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(store.activeSession, active)
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testFutureVersionWithDifferentShapeRemainsUntouchedAndRejectsMutations() throws {
        let future = Data(#"{"schemaVersion":99,"routines":"completely new format"}"#.utf8)
        try future.write(to: fileURL)
        let store = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertTrue(store.persistenceError?.contains("newer") == true)
        XCTAssertFalse(store.addRoutine(WorkoutStore.starterRoutines[0]))
        XCTAssertFalse(store.startWorkout(WorkoutStore.starterRoutines[0]))
        XCTAssertFalse(store.addWeight(kilograms: 70))
        XCTAssertFalse(store.setWeeklyGoal(7))
        store.setUnit(.lb)
        XCTAssertEqual(store.unit, .kg)
        XCTAssertFalse(store.discardWorkout())
        XCTAssertFalse(store.save())
        XCTAssertThrowsError(try store.exportBackup())
        XCTAssertThrowsError(try store.restoreBackup(future))
        XCTAssertEqual(try Data(contentsOf: fileURL), future)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["workouts.json"])
    }

    func testUnreadableFileIsNeverMovedIntoCorruptionRecovery() throws {
        // A directory at the expected file location gives a deterministic read
        // failure without relying on the test process's permissions.
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
        let marker = fileURL.appendingPathComponent("original-data")
        try Data("protected data".utf8).write(to: marker)
        let store = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertFalse(store.save())
        XCTAssertFalse(store.addWeight(kilograms: 72))
        XCTAssertEqual(try Data(contentsOf: marker), Data("protected data".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["workouts.json"])
    }

    func testInvalidImportsDoNotChangeMemoryOrDisk() throws {
        let store = WorkoutStore(fileURL: fileURL, now: { self.fixedDate })
        try finishOneWorkout(store)
        XCTAssertTrue(store.addWeight(kilograms: 72, date: fixedDate))
        let original = try store.exportBackup()
        let originalRoutines = store.routines
        let originalSessions = store.sessions
        let originalWeights = store.weights
        let changes: [(inout [String: Any]) -> Void] = [
            { $0["weeklyGoal"] = 0 },
            { $0["unit"] = "stone" },
            { root in
                var routines = root["routines"] as! [[String: Any]]
                routines.append(routines[0])
                root["routines"] = routines
            },
            { root in
                var routines = root["routines"] as! [[String: Any]]
                var exercises = routines[0]["exercises"] as! [[String: Any]]
                exercises[0]["sets"] = Int.max
                routines[0]["exercises"] = exercises
                root["routines"] = routines
            },
            { root in
                var sessions = root["sessions"] as! [[String: Any]]
                sessions.append(sessions[0])
                root["sessions"] = sessions
            },
            { root in
                var sessions = root["sessions"] as! [[String: Any]]
                sessions[0]["finishedAt"] = "2000-01-01T00:00:00Z"
                root["sessions"] = sessions
            },
            { root in
                var sessions = root["sessions"] as! [[String: Any]]
                sessions[0].removeValue(forKey: "finishedAt")
                root["sessions"] = sessions
            },
            { root in
                var sessions = root["sessions"] as! [[String: Any]]
                var exercises = sessions[0]["exercises"] as! [[String: Any]]
                exercises.append(exercises[0])
                sessions[0]["exercises"] = exercises
                root["sessions"] = sessions
            },
            { root in
                var sessions = root["sessions"] as! [[String: Any]]
                var exercises = sessions[0]["exercises"] as! [[String: Any]]
                var sets = exercises[0]["sets"] as! [[String: Any]]
                sets[1]["id"] = sets[0]["id"]
                exercises[0]["sets"] = sets
                sessions[0]["exercises"] = exercises
                root["sessions"] = sessions
            },
            { root in
                var sessions = root["sessions"] as! [[String: Any]]
                var exercises = sessions[0]["exercises"] as! [[String: Any]]
                var sets = exercises[0]["sets"] as! [[String: Any]]
                sets[0]["weightKG"] = -1
                exercises[0]["sets"] = sets
                sessions[0]["exercises"] = exercises
                root["sessions"] = sessions
            },
            { root in
                var weights = root["weights"] as! [[String: Any]]
                weights[0]["kilograms"] = 1_001
                root["weights"] = weights
            },
            { root in
                var weights = root["weights"] as! [[String: Any]]
                weights.append(weights[0])
                root["weights"] = weights
            },
            { root in
                var sessions = root["sessions"] as! [[String: Any]]
                sessions[0]["startedAt"] = "99999-01-01T00:00:00Z"
                root["sessions"] = sessions
            },
            { $0["restEndsAt"] = "2026-09-07T12:00:00Z" },
            { root in root["activeSession"] = (root["sessions"] as! [[String: Any]])[0] }
        ]
        for (index, change) in changes.enumerated() {
            let invalid = try changing(original, change)
            XCTAssertThrowsError(try store.backupSummary(invalid), "Invalid case \(index) should not be previewed.")
            XCTAssertThrowsError(try store.restoreBackup(invalid), "Invalid case \(index) should not be restored.")
            XCTAssertEqual(store.routines, originalRoutines)
            XCTAssertEqual(store.sessions, originalSessions)
            XCTAssertEqual(store.weights, originalWeights)
            XCTAssertEqual(try Data(contentsOf: fileURL), original)
        }
        XCTAssertThrowsError(try store.restoreBackup(Data("not JSON".utf8)))
    }

    func testOversizedBackupIsRejectedWithoutReplacingCurrentData() throws {
        let store = WorkoutStore(fileURL: fileURL)
        let original = try Data(contentsOf: fileURL)
        let oversized = Data(repeating: 32, count: WorkoutStore.maxBackupBytes + 1)
        XCTAssertThrowsError(try store.backupSummary(oversized)) { error in
            guard case WorkoutBackupError.tooLarge = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertThrowsError(try store.restoreBackup(oversized))
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testSemanticallyCorruptSavedFileIsPreservedBeforeRecovery() throws {
        let source = WorkoutStore(fileURL: fileURL)
        let corrupt = try changing(source.exportBackup()) { root in
            var routines = root["routines"] as! [[String: Any]]
            var exercises = routines[0]["exercises"] as! [[String: Any]]
            exercises[0]["restSeconds"] = Int.max
            routines[0]["exercises"] = exercises
            root["routines"] = routines
        }
        try corrupt.write(to: fileURL)
        let reopened = WorkoutStore(fileURL: fileURL)
        XCTAssertFalse(reopened.isReadOnly)
        XCTAssertNotNil(reopened.persistenceError)
        XCTAssertEqual(reopened.routines, WorkoutStore.starterRoutines)
        let recovery = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first { $0.lastPathComponent.contains("recovered-") })
        XCTAssertEqual(try Data(contentsOf: recovery), corrupt)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testRecoveryCopySurvivesRelaunchAndExportsExactBytesWithoutWriting() throws {
        let original = Data([0x00, 0xFF, 0x7B, 0x0A, 0x31, 0x0D])
        try original.write(to: fileURL)
        let recovered = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(recovered.hasRecoveryCopy)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let preserved = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
        let namesBeforeExport = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        try denyWrites {
            XCTAssertEqual(try recovered.exportRecoveryCopy(), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "Export must not save a replacement log.")
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), namesBeforeExport)
        }

        // Closing immediately after recovery must not hide the preserved file
        // just because the primary data file hasn't been recreated yet.
        let reopened = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(reopened.hasRecoveryCopy)
        XCTAssertTrue(reopened.persistenceError?.contains("recovery backup") == true)
        XCTAssertEqual(try reopened.exportRecoveryCopy(), original)
        let currentLog = try Data(contentsOf: fileURL)
        let reopenedAgain = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(reopenedAgain.hasRecoveryCopy)
        XCTAssertNotNil(reopenedAgain.persistenceError)
        XCTAssertEqual(try reopenedAgain.exportRecoveryCopy(), original)
        XCTAssertEqual(try Data(contentsOf: fileURL), currentLog)
        XCTAssertEqual(try Data(contentsOf: preserved), original)
    }

    func testRecoveryExportSelectsLatestCopyAndNeverReplacesReadOnlyData() throws {
        let older = directory.appendingPathComponent("workouts.recovered-\(UUID().uuidString).json")
        let newer = directory.appendingPathComponent("workouts.recovered-\(UUID().uuidString).json")
        let oldBytes = Data("older broken log".utf8)
        let newBytes = Data("newer broken log".utf8)
        try oldBytes.write(to: older)
        try newBytes.write(to: newer)
        try FileManager.default.setAttributes([.modificationDate: fixedDate.addingTimeInterval(-60)], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.modificationDate: fixedDate], ofItemAtPath: newer.path)
        let unrelated = directory.appendingPathComponent("workouts.recovered-not-a-generated-copy.json")
        try Data("unrelated".utf8).write(to: unrelated)
        let future = Data(#"{"schemaVersion":99,"newShape":true}"#.utf8)
        try future.write(to: fileURL)
        let store = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertTrue(store.hasRecoveryCopy)
        let errorBeforeExport = store.persistenceError
        try denyWrites {
            XCTAssertEqual(try store.exportRecoveryCopy(), newBytes)
            XCTAssertEqual(store.persistenceError, errorBeforeExport)
            XCTAssertEqual(try Data(contentsOf: fileURL), future)
            XCTAssertEqual(try Data(contentsOf: older), oldBytes)
            XCTAssertEqual(try Data(contentsOf: newer), newBytes)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 4)
    }

    func testRecoveryExportRejectsMissingAndOversizedCopiesWithoutChangingThem() throws {
        let fresh = WorkoutStore(fileURL: fileURL)
        XCTAssertFalse(fresh.hasRecoveryCopy)
        XCTAssertThrowsError(try fresh.exportRecoveryCopy()) { error in
            guard case WorkoutBackupError.noRecoveryCopy = error else { return XCTFail("Unexpected error: \(error)") }
        }
        let primary = try Data(contentsOf: fileURL)
        let preserved = directory.appendingPathComponent("workouts.recovered-\(UUID().uuidString).json")
        let tooLarge = Data(repeating: 32, count: WorkoutStore.maxBackupBytes + 1)
        try tooLarge.write(to: preserved)
        let reopened = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(reopened.hasRecoveryCopy)
        XCTAssertThrowsError(try reopened.exportRecoveryCopy()) { error in
            guard case WorkoutBackupError.tooLarge = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(try Data(contentsOf: fileURL), primary)
        XCTAssertEqual(try Data(contentsOf: preserved), tooLarge)
    }

    func testRestoreDiskFailureLeavesExistingMemoryAndFileUnchanged() throws {
        let store = WorkoutStore(fileURL: fileURL)
        let backup = try store.exportBackup()
        XCTAssertTrue(store.addWeight(kilograms: 80, date: fixedDate))
        let currentFile = try Data(contentsOf: fileURL)
        let currentWeights = store.weights
        try denyWrites {
            XCTAssertThrowsError(try store.restoreBackup(backup))
            XCTAssertEqual(store.weights, currentWeights)
            XCTAssertEqual(try Data(contentsOf: fileURL), currentFile)
        }
        try store.restoreBackup(backup)
        XCTAssertTrue(store.weights.isEmpty)
    }

    func testFinishAndDiscardDoNotLoseWorkoutAfterDiskFailure() throws {
        let store = WorkoutStore(fileURL: fileURL, now: { self.fixedDate })
        XCTAssertTrue(store.startWorkout(store.routines[0]))
        let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
        XCTAssertTrue(store.toggleSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertTrue(store.beginRest(seconds: 60))
        let active = store.activeSession
        let rest = store.restEndsAt
        let currentFile = try Data(contentsOf: fileURL)
        try denyWrites {
            XCTAssertNil(store.finishWorkout())
            XCTAssertFalse(store.discardWorkout())
            XCTAssertEqual(store.activeSession, active)
            XCTAssertEqual(store.restEndsAt, rest)
            XCTAssertTrue(store.sessions.isEmpty)
            XCTAssertEqual(try Data(contentsOf: fileURL), currentFile)
        }
        XCTAssertNotNil(store.finishWorkout())
        XCTAssertNil(store.activeSession)
        XCTAssertEqual(WorkoutStore(fileURL: fileURL).sessions.count, 1)
    }

    func testDeletingHistoryIsDurableAndDoesNotTouchActiveWorkout() throws {
        let store = WorkoutStore(fileURL: fileURL, now: { self.fixedDate })
        try finishOneWorkout(store)
        let session = try XCTUnwrap(store.sessions.first)
        XCTAssertTrue(store.startWorkout(store.routines[1]))
        let active = store.activeSession
        try denyWrites {
            XCTAssertFalse(store.deleteSession(id: session.id))
            XCTAssertEqual(store.sessions, [session])
        }
        XCTAssertTrue(store.deleteSession(id: session.id))
        XCTAssertFalse(store.deleteSession(id: session.id))
        XCTAssertEqual(store.activeSession, active)
        let reopened = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(reopened.sessions.isEmpty)
        XCTAssertEqual(reopened.activeSession, active)
    }

    func testFailedLibraryWeightAndPreferenceWritesDoNotPretendToSucceed() throws {
        let store = WorkoutStore(fileURL: fileURL)
        let routines = store.routines
        let original = try Data(contentsOf: fileURL)
        try denyWrites {
            XCTAssertFalse(store.deleteRoutine(id: routines[0].id))
            var edited = routines[0]
            edited.name = "Edited"
            XCTAssertFalse(store.updateRoutine(edited))
            edited.id = UUID()
            XCTAssertFalse(store.addRoutine(edited))
            XCTAssertFalse(store.addWeight(kilograms: 72))
            XCTAssertFalse(store.setWeeklyGoal(6))
            store.setUnit(.lb)
            XCTAssertEqual(store.routines, routines)
            XCTAssertTrue(store.weights.isEmpty)
            XCTAssertEqual(store.weeklyGoal, 3)
            XCTAssertEqual(store.unit, .kg)
            XCTAssertEqual(try Data(contentsOf: fileURL), original)
        }
    }

    func testFailedActiveEditCanBeExportedAndRetriedWithoutLosingProgress() throws {
        let store = WorkoutStore(fileURL: fileURL, now: { self.fixedDate })
        XCTAssertTrue(store.startWorkout(store.routines[0]))
        let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
        XCTAssertFalse(store.hasUnsavedChanges)
        let previousFile = try Data(contentsOf: fileURL)
        try denyWrites {
            XCTAssertTrue(store.updateSet(exerciseID: exercise.id, setID: exercise.sets[0].id, reps: 12, weightKG: 42.5))
            XCTAssertTrue(store.hasUnsavedChanges)
            XCTAssertEqual(try Data(contentsOf: fileURL), previousFile)
            let backup = try store.exportBackup()
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
            let active = try XCTUnwrap(json["activeSession"] as? [String: Any])
            let exercises = try XCTUnwrap(active["exercises"] as? [[String: Any]])
            let sets = try XCTUnwrap(exercises[0]["sets"] as? [[String: Any]])
            XCTAssertEqual(sets[0]["weightKG"] as? Double, 42.5)
        }
        XCTAssertTrue(store.save())
        XCTAssertFalse(store.hasUnsavedChanges)
        XCTAssertNil(store.persistenceError)
        XCTAssertEqual(WorkoutStore(fileURL: fileURL).activeSession?.exercises[0].sets[0].weightKG, 42.5)
    }

    func testPartialWorkoutsRememberLastCompletedLoadsIncludingBodyweight() throws {
        var clock = fixedDate
        let store = WorkoutStore(fileURL: fileURL, now: { clock })
        let routine = Routine(name: "Remember me", exercises: [
            ExerciseTemplate(name: "Press", category: "Chest", sets: 3),
            ExerciseTemplate(name: "Row", category: "Back", sets: 1)
        ])
        XCTAssertTrue(store.addRoutine(routine))
        XCTAssertTrue(store.startWorkout(routine))
        let press = try XCTUnwrap(store.activeSession?.exercises.first)
        for index in press.sets.indices {
            XCTAssertTrue(store.updateSet(exerciseID: press.id, setID: press.sets[index].id, reps: 10, weightKG: Double(index + 2) * 10))
            XCTAssertTrue(store.toggleSet(exerciseID: press.id, setID: press.sets[index].id))
        }
        let row = try XCTUnwrap(store.activeSession?.exercises.last)
        XCTAssertTrue(store.updateSet(exerciseID: row.id, setID: row.sets[0].id, reps: 10, weightKG: 10))
        XCTAssertTrue(store.toggleSet(exerciseID: row.id, setID: row.sets[0].id))
        XCTAssertNotNil(store.finishWorkout())
        clock.addTimeInterval(60)

        XCTAssertTrue(store.startWorkout(routine))
        let partialPress = try XCTUnwrap(store.activeSession?.exercises.first)
        XCTAssertTrue(store.updateSet(exerciseID: partialPress.id, setID: partialPress.sets[0].id, reps: 10, weightKG: 0))
        XCTAssertTrue(store.toggleSet(exerciseID: partialPress.id, setID: partialPress.sets[0].id))
        XCTAssertTrue(store.updateSet(exerciseID: partialPress.id, setID: partialPress.sets[1].id, reps: 10, weightKG: 999))
        XCTAssertNotNil(store.finishWorkout())
        clock.addTimeInterval(60)

        XCTAssertTrue(store.startWorkout(routine))
        XCTAssertEqual(store.activeSession?.exercises[0].sets.map(\.weightKG), [0, 30, 40], "Completed bodyweight is remembered; unchecked estimates are not.")
        XCTAssertEqual(store.activeSession?.exercises[1].sets[0].weightKG, 10, "Skipping an exercise does not erase its last completed load.")
        XCTAssertEqual(store.activeSession?.completedSets, 0)
    }

    func testRenamingRoutineLinksUnambiguousLegacyHistoryBeforeNameChanges() throws {
        let original = WorkoutStore(fileURL: fileURL, now: { self.fixedDate })
        try finishOneWorkout(original)
        let legacy = try changing(original.exportBackup()) { root in
            var sessions = root["sessions"] as! [[String: Any]]
            sessions[0].removeValue(forKey: "routineID")
            root["sessions"] = sessions
        }
        try legacy.write(to: fileURL)
        let store = WorkoutStore(fileURL: fileURL, now: { self.fixedDate })
        XCTAssertNil(store.sessions[0].routineID)
        var renamed = store.routines[0]
        renamed.name = "Still my routine"
        XCTAssertTrue(store.updateRoutine(renamed))
        XCTAssertEqual(store.sessions[0].routineID, renamed.id)
        XCTAssertEqual(store.sessions[0].routineName, original.routines[0].name, "History keeps the name used at the time.")
        XCTAssertTrue(store.startWorkout(renamed))
        XCTAssertEqual(store.activeSession?.exercises[0].sets[0].weightKG, 20)
    }

    private func finishOneWorkout(_ store: WorkoutStore) throws {
        XCTAssertTrue(store.startWorkout(store.routines[0]))
        let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
        XCTAssertTrue(store.updateSet(exerciseID: exercise.id, setID: exercise.sets[0].id, reps: 10, weightKG: 20))
        XCTAssertTrue(store.toggleSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertNotNil(store.finishWorkout())
    }

    private func changing(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        change(&json)
        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    private func denyWrites(_ assertions: () throws -> Void) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
        try assertions()
    }
}
