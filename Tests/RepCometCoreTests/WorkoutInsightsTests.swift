import Foundation
import XCTest
@testable import RepCometCore

final class WorkoutInsightsTests: XCTestCase {
    func testSuggestionRotatesAfterFinishingButNotDiscardingAndSurvivesRename() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var time = Date(timeIntervalSince1970: 1_788_800_400)
        let store = WorkoutStore(fileURL: directory.appendingPathComponent("test.json"), now: { time })
        let routines = store.routines
        XCTAssertEqual(store.suggestedRoutine?.id, routines[0].id)
        store.startWorkout(routines[0])
        store.discardWorkout()
        XCTAssertEqual(store.suggestedRoutine?.id, routines[0].id)
        for index in 0..<3 {
            store.startWorkout(routines[index])
            let exercise = try XCTUnwrap(store.activeSession?.exercises.first)
            store.toggleSet(exerciseID: exercise.id, setID: exercise.sets[0].id)
            XCTAssertNotNil(store.finishWorkout())
            time = time.addingTimeInterval(600)
        }
        var renamed = routines[0]
        renamed.name = "My renamed routine"
        XCTAssertTrue(store.updateRoutine(renamed))
        XCTAssertEqual(store.suggestedRoutine?.id, renamed.id)
        XCTAssertEqual(store.momentum.completedWorkouts, 3)
        for routine in store.routines { store.deleteRoutine(id: routine.id) }
        XCTAssertNil(store.suggestedRoutine)
        XCTAssertEqual(store.momentum.completedWorkouts, 3, "Removing a routine must not remove earned progress.")
    }

    func testMilestonesCelebrateActualCompletionAndDoNotInventProgress() {
        let empty = WorkoutMomentum(completedWorkouts: 0)
        XCTAssertEqual(empty.target, 1)
        XCTAssertEqual(empty.fraction, 0)
        XCTAssertFalse(empty.isEarned)
        XCTAssertTrue(WorkoutMomentum(completedWorkouts: 1).isEarned)
        let working = WorkoutMomentum(completedWorkouts: 4)
        XCTAssertEqual(working.target, 5)
        XCTAssertEqual(working.remaining, 1)
        XCTAssertFalse(working.isEarned)
        XCTAssertEqual(WorkoutMomentum(completedWorkouts: 5).title, "The high-five club")
        XCTAssertEqual(WorkoutMomentum(completedWorkouts: 6).target, 10)
        XCTAssertEqual(WorkoutMomentum(completedWorkouts: 1_001).target, 2_000)
    }
}
