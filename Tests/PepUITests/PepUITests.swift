import XCTest

/// These tests drive the shipped SwiftUI app. Every case owns a fresh on-disk
/// store; relaunching within a case deliberately keeps that store intact.
@MainActor
final class PepUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false {
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Native UI failure"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: XCUIApplication().debugDescription)
            hierarchy.name = "Native accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
    }

    func testStarterWorkoutSavesCompletedSetsToHistory() {
        let app = launchApp()
        tap(app.buttons["today.start-workout"], in: app)
        enter("20", into: app.textFields["workout.set.weight.0.0"])
        enter("8", into: app.textFields["workout.set.reps.0.0"])
        tap(app.buttons["workout.set.complete.0.0"], in: app)
        XCTAssertEqual(app.buttons["workout.set.complete.0.0"].label, "Mark set 1 incomplete")
        if app.buttons["Skip rest timer"].exists { app.buttons["Skip rest timer"].tap() }

        tap(app.buttons["workout.finish"], in: app)
        tap(app.buttons["Save completed sets"], in: app)
        XCTAssertTrue(app.staticTexts["workout.completed"].waitForExistence(timeout: 5))
        tap(app.buttons["workout.done"], in: app)
        tap(app.buttons["navigation.progress"], in: app)
        let session = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Upper body", "1 sets")).firstMatch
        tap(session, in: app)
        XCTAssertTrue(app.staticTexts["A LITTLE WIN, SAVED"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bench press"].exists)
        XCTAssertTrue(app.staticTexts["20 kg"].exists)
        XCTAssertTrue(app.staticTexts["160"].exists, "Saved volume must be 20 kg × 8 reps.")
        capture("Completed workout history")
    }

    func testActiveWorkoutSurvivesTerminationWithEnteredValues() {
        let app = launchApp()
        tap(app.buttons["today.start-workout"], in: app)
        enter("32.5", into: app.textFields["workout.set.weight.0.0"])
        enter("10", into: app.textFields["workout.set.reps.0.0"])
        tap(app.buttons["workout.set.complete.0.0"], in: app)
        XCTAssertEqual(app.buttons["workout.set.complete.0.0"].label, "Mark set 1 incomplete")

        app.terminate()
        app.launch()
        tap(app.buttons["today.resume-workout"], in: app)
        XCTAssertEqual(app.textFields["workout.set.weight.0.0"].value as? String, "32.5")
        XCTAssertEqual(app.textFields["workout.set.reps.0.0"].value as? String, "10")
        XCTAssertEqual(app.buttons["workout.set.complete.0.0"].label, "Mark set 1 incomplete")
        capture("Recovered active workout")
    }

    func testInvalidSetCannotBeCompleted() {
        let app = launchApp()
        tap(app.buttons["today.start-workout"], in: app)
        enter("0", into: app.textFields["workout.set.reps.0.0"])
        tap(app.buttons["workout.set.complete.0.0"], in: app)
        XCTAssertEqual(app.buttons["workout.set.complete.0.0"].label, "Complete set 1")
        XCTAssertTrue(app.staticTexts["workout.set.error.0.0"].exists)
        enter("8", into: app.textFields["workout.set.reps.0.0"])
        tap(app.buttons["workout.set.complete.0.0"], in: app)
        XCTAssertEqual(app.buttons["workout.set.complete.0.0"].label, "Mark set 1 incomplete")
        capture("Set validation and correction")
    }

    func testWeightCheckInConvertsBetweenKilogramsAndPounds() {
        let app = launchApp()
        tap(app.buttons["Log your body weight, optional"], in: app)
        enter("70", into: app.textFields["Body weight in kg"])
        tap(app.buttons["Save check-in"], in: app)
        tap(app.buttons["settings.open"], in: app)
        tap(app.buttons["settings.unit.lb"], in: app)
        tap(app.navigationBars.buttons["Done"], in: app)

        tap(app.buttons["Log your body weight, optional"], in: app)
        XCTAssertTrue(app.textFields["Body weight in lb"].waitForExistence(timeout: 5))
        enter("160", into: app.textFields["Body weight in lb"])
        tap(app.buttons["Save check-in"], in: app)
        tap(app.buttons["navigation.progress"], in: app)
        tap(app.buttons["View check-ins"], in: app)
        XCTAssertTrue(app.staticTexts["160 lb"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["154.32 lb"].exists, "The earlier 70 kg check-in must convert without changing its stored value.")
        tap(app.navigationBars.buttons["Done"], in: app)
        tap(app.buttons["settings.open"], in: app)
        tap(app.buttons["settings.unit.kg"], in: app)
        tap(app.navigationBars.buttons["Done"], in: app)
        tap(app.buttons["View check-ins"], in: app)
        XCTAssertTrue(app.staticTexts["70 kg"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["72.57 kg"].exists)
        capture("Converted weight history")
    }

    func testRoutineCreationRejectsDuplicateNamesAndRemainsNavigable() {
        let app = launchApp()
        tap(app.buttons["navigation.routines"], in: app)
        openRoutineEditor(named: "Upper body", in: app)
        tap(app.buttons["routine.save"], in: app)
        XCTAssertTrue(app.staticTexts["routine.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["routine.error"].label.contains("already"))
        tap(app.navigationBars.buttons["Cancel"], in: app)
        tap(app.buttons["Discard changes"], in: app)

        openRoutineEditor(named: "Happy little lift", in: app)
        tap(app.buttons["routine.save"], in: app)
        tap(app.buttons["Start Happy little lift"], in: app)
        XCTAssertTrue(app.textFields["workout.set.weight.0.0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Happy little lift"].exists)
        tap(app.buttons["workout.minimize"], in: app)
        tap(app.buttons["navigation.today"], in: app)
        XCTAssertTrue(app.buttons["today.resume-workout"].waitForExistence(timeout: 5))
        capture("Custom routine ready to resume")
    }

    func testThemeAndMotionPreferencesPersistWithReduceMotion() {
        let app = launchApp(reduceMotion: true)
        tap(app.buttons["settings.open"], in: app)
        tap(app.buttons["appearance.theme.punch"], in: app)
        XCTAssertTrue(app.buttons["appearance.theme.punch"].isSelected)
        let motion = app.switches["appearance.motion"]
        reveal(motion, in: app)
        XCTAssertEqual(motion.value as? String, "1")
        XCTAssertTrue(app.staticTexts["appearance.reduce-motion"].exists)
        motion.tap()
        XCTAssertEqual(motion.value as? String, "0")
        tap(app.navigationBars.buttons["Done"], in: app)

        app.terminate()
        app.launch()
        tap(app.buttons["settings.open"], in: app)
        XCTAssertTrue(app.buttons["appearance.theme.punch"].isSelected)
        reveal(app.switches["appearance.motion"], in: app)
        XCTAssertEqual(app.switches["appearance.motion"].value as? String, "0")
        XCTAssertTrue(app.staticTexts["appearance.reduce-motion"].exists)
        capture("Persisted theme with Reduce Motion")
    }

    func testLargestTextKeepsNavigationAndBackupActionsReachable() {
        let app = launchApp(reduceMotion: true, largeText: true)
        tap(app.buttons["navigation.routines"], in: app)
        reveal(app.buttons["Make a new routine"], in: app)
        XCTAssertTrue(app.buttons["Make a new routine"].isEnabled)
        capture("Largest text routines")
        tap(app.buttons["navigation.today"], in: app)
        reveal(app.buttons["today.start-workout"], in: app)
        XCTAssertTrue(app.buttons["today.start-workout"].isEnabled)
        capture("Largest text Today")
        tap(app.buttons["settings.open"], in: app)
        tap(app.buttons["settings.backup"], in: app)
        reveal(app.buttons["backup.export"], in: app)
        XCTAssertTrue(app.buttons["backup.export"].isEnabled)
        reveal(app.buttons["backup.import"], in: app)
        XCTAssertTrue(app.buttons["backup.import"].isEnabled)
        capture("Largest text backup actions")
    }

    func testBackupPreservesAnActiveWorkoutFromAccidentalRestore() {
        let app = launchApp()
        tap(app.buttons["today.start-workout"], in: app)
        tap(app.buttons["workout.minimize"], in: app)
        tap(app.buttons["settings.open"], in: app)
        tap(app.buttons["settings.backup"], in: app)
        reveal(app.buttons["backup.export"], in: app)
        XCTAssertTrue(app.buttons["backup.export"].isEnabled)
        reveal(app.buttons["backup.import"], in: app)
        XCTAssertFalse(app.buttons["backup.import"].isEnabled)
        XCTAssertTrue(app.staticTexts["Finish or discard your current workout before restoring."].exists)
        capture("Backup protects the active workout")
    }

    private func launchApp(reduceMotion: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--pep-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["PEP_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PEP_UI_TEST_REDUCE_MOTION"] = reduceMotion ? "1" : "0"
        app.launchEnvironment["PEP_UI_TEST_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.buttons["navigation.today"].waitForExistence(timeout: 15))
        return app
    }

    private func openRoutineEditor(named name: String, in app: XCUIApplication) {
        tap(app.buttons["Make a new routine"], in: app)
        enter(name, into: app.textFields["routine.name"])
        tap(app.buttons["routine.add-exercises"], in: app)
        tap(app.buttons["library.exercise.Bench press"], in: app)
        tap(app.buttons["library.add-selected"], in: app)
    }

    private func enter(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // Right edge puts the insertion point after existing short numeric values.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let previous = field.value as? String ?? ""
        if !previous.isEmpty && previous != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(text)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 2)
        if app.keyboards.firstMatch.exists && app.buttons["workout.keyboard-done"].isHittable {
            app.buttons["workout.keyboard-done"].tap()
        }
        let scroll = app.scrollViews.firstMatch
        // Existing elements expose a frame even when outside the viewport.
        // For lazy elements, scan down and back up so retained scroll position
        // after a sheet dismisses cannot make an earlier card unreachable.
        for attempt in 0..<28 {
            if element.exists && element.isHittable { return }
            if element.exists && element.frame.maxY < scroll.frame.minY + 30 {
                scroll.swipeDown()
            } else if element.exists && element.frame.minY > scroll.frame.maxY - 30 {
                scroll.swipeUp()
            } else if attempt < 14 {
                scroll.swipeUp()
            } else {
                scroll.swipeDown()
            }
        }
        XCTFail("Could not reach \(element)", file: file, line: line)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, in: app, file: file, line: line)
        element.tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
