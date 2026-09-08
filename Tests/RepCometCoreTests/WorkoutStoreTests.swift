import Foundation
import XCTest
@testable import RepCometCore

final class WorkoutStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("workouts.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("RepCometTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testFirstLaunchOffersStarterRoutinesWithoutInventedActivity() throws {
        let store = WorkoutStore(fileURL: fileURL)
        XCTAssertEqual(store.routines.map(\.name), ["Upper body", "Lower body", "Full body"])
        XCTAssertEqual(store.routines.map { $0.exercises.count }, [5, 4, 5])
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.weights.isEmpty)
        XCTAssertNil(store.activeSession)
        XCTAssertNil(store.persistenceError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testPersistenceRoundTripPreservesRoutinesPreferencesAndActiveWorkout() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_788_800_400)
        let store = WorkoutStore(fileURL: fileURL, now: { fixedDate })
        let routine = makeRoutine()
        XCTAssertTrue(store.addRoutine(routine))
        store.setUnit(.lb)
        XCTAssertTrue(store.setWeeklyGoal(5))
        XCTAssertTrue(store.addWeight(kilograms: 74.25, date: fixedDate))
        XCTAssertTrue(store.startWorkout(routine))
        let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
        let set = try XCTUnwrap(exercise.sets.first)
        XCTAssertTrue(store.updateSet(exerciseID: exercise.id, setID: set.id, reps: 8, weightKG: 32.5))
        XCTAssertTrue(store.toggleSet(exerciseID: exercise.id, setID: set.id))
        XCTAssertTrue(store.beginRest(seconds: 90))

        let restored = WorkoutStore(fileURL: fileURL, now: { fixedDate })
        XCTAssertEqual(restored.routines, store.routines)
        XCTAssertEqual(restored.activeSession, store.activeSession)
        XCTAssertEqual(restored.weights, store.weights)
        XCTAssertEqual(restored.unit, .lb)
        XCTAssertEqual(restored.weeklyGoal, 5)
        XCTAssertEqual(restored.restEndsAt, fixedDate.addingTimeInterval(90))
        XCTAssertNil(restored.persistenceError)
    }

    func testCannotFinishWorkoutWithoutCompletedSetsOrReplaceAnActiveWorkout() throws {
        let store = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(store.startWorkout(makeRoutine()))
        let activeID = try XCTUnwrap(store.activeSession?.id)
        XCTAssertNil(store.finishWorkout())
        XCTAssertEqual(store.activeSession?.id, activeID)
        XCTAssertFalse(store.startWorkout(store.routines[0]))
        XCTAssertEqual(store.activeSession?.id, activeID)
        XCTAssertTrue(store.sessions.isEmpty)
    }

    func testFinishingPartialWorkoutArchivesOnlyCompletedVolumeAndClearsActiveState() throws {
        var currentDate = Date(timeIntervalSince1970: 1_788_800_400)
        let store = WorkoutStore(fileURL: fileURL, now: { currentDate })
        XCTAssertTrue(store.startWorkout(makeRoutine()))
        let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
        XCTAssertTrue(store.updateSet(exerciseID: exercise.id, setID: exercise.sets[0].id, reps: 8, weightKG: 40))
        XCTAssertTrue(store.updateSet(exerciseID: exercise.id, setID: exercise.sets[1].id, reps: 12, weightKG: 100))
        XCTAssertTrue(store.toggleSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertTrue(store.beginRest(seconds: 90))
        currentDate = currentDate.addingTimeInterval(600)
        var archived = try XCTUnwrap(store.finishWorkout())

        XCTAssertNil(store.activeSession)
        XCTAssertNil(store.restEndsAt)
        XCTAssertEqual(archived.completedSets, 1)
        XCTAssertEqual(archived.totalSets, 3)
        XCTAssertEqual(archived.volumeKG, 320)
        XCTAssertEqual(archived.duration, 600)
        XCTAssertEqual(store.totalVolumeKG, 320)
        XCTAssertNil(store.finishWorkout(), "A second finish cannot duplicate history.")
        archived.exercises[0].sets[0].weightKG = 900
        XCTAssertEqual(store.sessions[0].volumeKG, 320, "Archived values cannot mutate store history through a returned copy.")

        let restored = WorkoutStore(fileURL: fileURL)
        XCTAssertNil(restored.activeSession)
        XCTAssertEqual(restored.sessions.count, 1)
        XCTAssertEqual(restored.totalVolumeKG, 320)
    }

    func testEditingDeletingRoutineDoesNotChangeArchivedSession() throws {
        let store = WorkoutStore(fileURL: fileURL)
        var routine = makeRoutine()
        XCTAssertTrue(store.addRoutine(routine))
        XCTAssertTrue(store.startWorkout(routine))
        let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
        XCTAssertTrue(store.toggleSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        let finished = try XCTUnwrap(store.finishWorkout())
        routine.name = "Changed name"
        routine.exercises[0].name = "Changed exercise"
        XCTAssertTrue(store.updateRoutine(routine))
        XCTAssertTrue(store.deleteRoutine(id: routine.id))
        XCTAssertEqual(store.sessions[0], finished)
        XCTAssertEqual(store.sessions[0].routineName, "My session")
        XCTAssertEqual(store.sessions[0].exercises[0].name, "Bench press")
    }

    func testNewSessionRemembersCompletedWeightsWithoutMarkingSetsComplete() throws {
        let store = WorkoutStore(fileURL: fileURL)
        let routine = makeRoutine()
        XCTAssertTrue(store.startWorkout(routine))
        let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
        XCTAssertTrue(store.updateSet(exerciseID: exercise.id, setID: exercise.sets[0].id, reps: 8, weightKG: 32.5))
        XCTAssertTrue(store.toggleSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertNotNil(store.finishWorkout())
        XCTAssertTrue(store.startWorkout(routine))
        XCTAssertEqual(store.activeSession?.exercises[0].sets[0].weightKG, 32.5)
        XCTAssertEqual(store.activeSession?.completedSets, 0)
        XCTAssertEqual(store.activeSession?.volumeKG, 0)
    }

    func testSetValidationAndAddRemoveRespectBounds() throws {
        let store = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(store.startWorkout(makeRoutine(sets: 1)))
        let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
        let set = try XCTUnwrap(exercise.sets.first)
        XCTAssertFalse(store.updateSet(exerciseID: exercise.id, setID: set.id, reps: 0, weightKG: 10))
        XCTAssertFalse(store.updateSet(exerciseID: exercise.id, setID: set.id, reps: 10, weightKG: -1))
        XCTAssertFalse(store.updateSet(exerciseID: exercise.id, setID: set.id, reps: 10, weightKG: .nan))
        XCTAssertFalse(store.updateSet(exerciseID: exercise.id, setID: set.id, reps: 10, weightKG: .infinity))
        XCTAssertFalse(store.updateSet(exerciseID: UUID(), setID: set.id, reps: 10, weightKG: 10))
        XCTAssertFalse(store.toggleSet(exerciseID: exercise.id, setID: UUID()))
        XCTAssertFalse(store.removeSet(exerciseID: exercise.id, setID: set.id))
        XCTAssertTrue(store.updateSet(exerciseID: exercise.id, setID: set.id, reps: 12, weightKG: 0))
        for _ in 1..<20 { XCTAssertTrue(store.addSet(exerciseID: exercise.id)) }
        XCTAssertFalse(store.addSet(exerciseID: exercise.id))
        XCTAssertEqual(store.activeSession?.totalSets, 20)
        XCTAssertTrue(store.removeSet(exerciseID: exercise.id, setID: set.id))
        XCTAssertEqual(store.activeSession?.totalSets, 19)
        XCTAssertNil(store.persistenceError)
    }

    func testWeightUnitConversionAndEntryOrdering() throws {
        let store = WorkoutStore(fileURL: fileURL)
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = older.addingTimeInterval(86_400)
        XCTAssertEqual(WeightUnit.lb.value(fromKilograms: 100), 220.46226218487757, accuracy: 0.000_000_001)
        XCTAssertEqual(WeightUnit.lb.kilograms(from: 220.46226218487757), 100, accuracy: 0.000_000_001)
        XCTAssertEqual(WeightUnit.kg.kilograms(from: 72.4), 72.4)
        XCTAssertTrue(store.addWeight(kilograms: 72, date: newer))
        XCTAssertTrue(store.addWeight(kilograms: 73, date: older))
        XCTAssertEqual(store.weights.map(\.kilograms), [72, 73])
        store.setUnit(.lb)
        XCTAssertEqual(store.weights.map(\.kilograms), [72, 73], "Changing units never changes stored physical values.")
        XCTAssertTrue(store.deleteWeight(id: store.weights[0].id))
        XCTAssertEqual(WorkoutStore(fileURL: fileURL).weights.map(\.kilograms), [73])
    }

    func testRejectsInvalidWeightRoutineAndGoal() throws {
        let store = WorkoutStore(fileURL: fileURL)
        for invalid in [0, -5, Double.nan, Double.infinity, 1_001] {
            XCTAssertFalse(store.addWeight(kilograms: invalid))
        }
        XCTAssertTrue(store.weights.isEmpty)
        XCTAssertFalse(store.addRoutine(Routine(name: "Empty", exercises: [])))
        var routine = makeRoutine()
        routine.name = "  \n "
        XCTAssertFalse(store.addRoutine(routine))
        routine = makeRoutine(sets: 0)
        XCTAssertFalse(store.addRoutine(routine))
        routine = makeRoutine()
        routine.exercises.append(routine.exercises[0])
        XCTAssertFalse(store.addRoutine(routine), "Repeated identifiers cannot be addressed safely by set editors.")
        routine = makeRoutine()
        routine.name = "  My plan  "
        XCTAssertTrue(store.addRoutine(routine))
        XCTAssertEqual(store.routines.last?.name, "My plan")
        XCTAssertFalse(store.addRoutine(routine))
        XCTAssertFalse(store.setWeeklyGoal(0))
        XCTAssertFalse(store.setWeeklyGoal(8))
        XCTAssertEqual(store.weeklyGoal, 3)
        XCTAssertNil(store.persistenceError)
    }

    func testWeeklyStatisticsRespectCalendarBoundaryAndUniqueDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
        var currentDate = monday.addingTimeInterval(-600)
        let store = WorkoutStore(fileURL: fileURL, calendar: calendar, now: { currentDate })
        func logWorkout() throws {
            XCTAssertTrue(store.startWorkout(makeRoutine(sets: 1)))
            let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
            XCTAssertTrue(store.updateSet(exerciseID: exercise.id, setID: exercise.sets[0].id, reps: 10, weightKG: 20))
            XCTAssertTrue(store.toggleSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
            XCTAssertNotNil(store.finishWorkout())
        }
        try logWorkout() // Previous Sunday.
        currentDate = monday
        try logWorkout() // Inclusive start boundary.
        currentDate = monday.addingTimeInterval(3_600)
        try logWorkout() // Same day, second session.
        currentDate = monday.addingTimeInterval(86_400)
        try logWorkout() // Tuesday.
        XCTAssertEqual(store.sessionsThisWeek.count, 3)
        XCTAssertEqual(store.weeklyCompletedDays, [monday, monday.addingTimeInterval(86_400)])
        XCTAssertEqual(store.totalVolumeKG, 800)
        currentDate = monday.addingTimeInterval(7 * 86_400)
        XCTAssertTrue(store.sessionsThisWeek.isEmpty, "Previous week's entries fall outside the next week's half-open interval.")
    }

    func testRestDeadlinePersistsAndDiscardClearsIt() throws {
        let currentDate = Date(timeIntervalSince1970: 1_788_800_400)
        let store = WorkoutStore(fileURL: fileURL, now: { currentDate })
        XCTAssertFalse(store.beginRest(seconds: 90))
        XCTAssertTrue(store.startWorkout(makeRoutine()))
        XCTAssertFalse(store.beginRest(seconds: -1))
        XCTAssertTrue(store.beginRest(seconds: 120))
        XCTAssertEqual(WorkoutStore(fileURL: fileURL).restEndsAt, currentDate.addingTimeInterval(120))
        store.clearRest()
        XCTAssertNil(WorkoutStore(fileURL: fileURL).restEndsAt)
        XCTAssertTrue(store.beginRest(seconds: 60))
        store.discardWorkout()
        let restored = WorkoutStore(fileURL: fileURL)
        XCTAssertNil(restored.activeSession)
        XCTAssertNil(restored.restEndsAt)
        XCTAssertTrue(restored.sessions.isEmpty)
    }

    func testCorruptFileIsBackedUpBeforeFreshDataCanBeSaved() throws {
        let original = Data("this is not workout JSON".utf8)
        try original.write(to: fileURL)
        let store = WorkoutStore(fileURL: fileURL)
        XCTAssertNotNil(store.persistenceError)
        XCTAssertTrue(store.persistenceError?.contains("backup") == true)
        let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first { $0.lastPathComponent.contains("recovered-") })
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "Recovery does not silently write over the failed file.")
        XCTAssertTrue(store.addWeight(kilograms: 70))
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertEqual(WorkoutStore(fileURL: fileURL).weights.count, 1)
    }

    func testNewerDataVersionIsNeverOverwritten() throws {
        let originalStore = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(originalStore.addWeight(kilograms: 80))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        json["schemaVersion"] = 99
        let newerData = try JSONSerialization.data(withJSONObject: json)
        try newerData.write(to: fileURL)
        let store = WorkoutStore(fileURL: fileURL)
        XCTAssertTrue(store.persistenceError?.contains("newer") == true)
        XCTAssertFalse(store.save())
        XCTAssertEqual(try Data(contentsOf: fileURL), newerData)
    }

    func testWriteFailureIsReportedAndKeepsCurrentProgressInMemory() throws {
        let blockedParent = directory.appendingPathComponent("not-a-directory")
        try Data("occupied".utf8).write(to: blockedParent)
        let store = WorkoutStore(fileURL: blockedParent.appendingPathComponent("workouts.json"))
        XCTAssertNotNil(store.persistenceError)
        XCTAssertTrue(store.startWorkout(makeRoutine()))
        XCTAssertNotNil(store.activeSession)
        XCTAssertFalse(store.save())
        XCTAssertEqual(try String(contentsOf: blockedParent, encoding: .utf8), "occupied")
    }

    private func makeRoutine(sets: Int = 3) -> Routine {
        Routine(name: "My session", exercises: [ExerciseTemplate(name: "Bench press", category: "Chest", sets: sets, reps: 10)])
    }
}
