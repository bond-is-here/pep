import XCTest

/// These tests drive the shipped SwiftUI app. Every case owns a fresh on-disk
/// store; relaunching within a case deliberately keeps that store intact.
@MainActor
final class PepUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 {
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

    func testLargestTextAllowsEditingAndCompletingAWorkoutSet() {
        let app = launchApp(reduceMotion: true, largeText: true)
        tap(app.buttons["today.start-workout"], in: app)
        let weight = app.textFields["workout.set.weight.0.0"]
        let reps = app.textFields["workout.set.reps.0.0"]
        let complete = app.buttons["workout.set.complete.0.0"]
        reveal(weight, in: app)
        enter("20", into: weight)
        reveal(reps, in: app)
        enter("12", into: reps)
        tap(complete, in: app)
        XCTAssertEqual(weight.value as? String, "20")
        XCTAssertEqual(reps.value as? String, "12")
        XCTAssertEqual(complete.label, "Mark set 1 incomplete")
        reveal(complete, in: app)
        capture("Largest text completed workout set")
    }

    func testGermanWeightCheckInUsesCommaDecimalInputAndHistory() {
        let app = launchApp(locale: "de_DE")
        tap(app.buttons["Log your body weight, optional"], in: app)
        let weight = app.textFields["Body weight in kg"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(weight.placeholderValue, "70,0", "The example must match the device's decimal separator.")
        enter("70.0", into: weight)
        XCTAssertTrue(app.staticTexts["weight.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["weight.save"].isEnabled, "A mismatched decimal separator must not save a different weight.")
        enter("70,5", into: weight)
        XCTAssertFalse(app.staticTexts["weight.error"].exists)
        tap(app.buttons["weight.save"], in: app)
        tap(app.buttons["navigation.progress"], in: app)
        tap(app.buttons["View check-ins"], in: app)
        XCTAssertTrue(app.staticTexts["70,5 kg"].waitForExistence(timeout: 5), "A comma decimal must save as 70.5 kg, preserving its fractional value.")
        capture("German decimal weight check-in")
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

    func testBackupPresentsNativeSavePicker() {
        let app = launchApp()
        tap(app.buttons["settings.open"], in: app)
        tap(app.buttons["settings.backup"], in: app)
        tap(app.buttons["backup.export"], in: app)
        assertNativeDocumentPicker(in: app, covering: app.buttons["backup.export"])
        capture("Native backup save picker")

        // iOS 26's Save UI exposes a non-actionable accessibility node labelled
        // "Cancel" and has no user-visible dismissal control in its hierarchy.
        // Let this test case end with the picker presented; XCTest tears down
        // the host app before the separate open-picker case starts.
        app.terminate()
    }

    func testBackupPresentsNativeOpenPicker() {
        let app = launchApp()
        tap(app.buttons["settings.open"], in: app)
        tap(app.buttons["settings.backup"], in: app)
        tap(app.buttons["backup.import"], in: app)
        assertNativeDocumentPicker(in: app, covering: app.buttons["backup.import"])
        capture("Native backup open picker")
        app.terminate()
    }

    private func launchApp(reduceMotion: Bool = false, largeText: Bool = false, locale: String = "en_US") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--pep-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", locale]
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

    private func assertNativeDocumentPicker(in app: XCUIApplication, covering sourceButton: XCUIElement) {
        // The system Files picker remembers its last location. Require a
        // Files-specific landmark; Pep's Backup view contains neither, and its
        // own button alone cannot satisfy this check. The system's Save UI on
        // iOS 26 reports a non-actionable "Cancel" node, so presentation is
        // verified without depending on a system dismissal control.
        let browserLandmark = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@ OR label IN %@",
            ["Browse View (Picker)", "DOCPicker.filenameTextField"],
            ["Browse", "Recents", "Locations", "On My iPhone", "On My iPhone is Empty", "iCloud Drive", "Save as"]
        )).firstMatch
        XCTAssertTrue(browserLandmark.waitForExistence(timeout: 10), "The native Files browser must be presented.")
        XCTAssertFalse(sourceButton.exists && sourceButton.isHittable, "The native picker must cover Pep's backup action.")
    }

    private func enter(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // Right edge puts the insertion point after existing short numeric values.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let previous = field.value as? String ?? ""
        // A real default (such as 8 reps) can equal its placeholder. Clear it
        // either way; delete on an empty field leaves its placeholder intact.
        if !previous.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text, "The field must contain the requested input before testing its behavior.")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 2)
        dismissKnownKeyboard(in: app, file: file, line: line)
        // XCUITest can report offscreen SwiftUI buttons as hittable, including
        // content covered by Pep's custom bottom navigation. Check the actual
        // tap point, then scroll its own foreground container into that region.
        for attempt in 0..<28 {
            let visibleArea = visibleTapArea(for: element, in: app)
            if element.exists && element.isHittable && visibleArea.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                return
            }
            guard let scroll = foregroundScrollView(containing: element, in: app) else {
                XCTFail("No foreground scroll view can reveal \(element)", file: file, line: line)
                return
            }
            let viewport = scroll.frame.intersection(visibleArea).insetBy(dx: 12, dy: 12)
            guard !viewport.isNull && viewport.height > 60 && viewport.width > 40 else {
                XCTFail("No visible content area is available for scrolling", file: file, line: line)
                return
            }
            let scrollUp: Bool
            if element.exists && element.frame.midY < viewport.minY {
                scrollUp = false
            } else if element.exists && element.frame.midY > viewport.maxY {
                scrollUp = true
            } else {
                scrollUp = attempt < 14
            }
            // Gesture coordinates stay inside foreground content, never the
            // keyboard prediction strip or the covered screen behind a sheet.
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let startY = viewport.minY + viewport.height * (scrollUp ? 0.78 : 0.22)
            let endY = viewport.minY + viewport.height * (scrollUp ? 0.22 : 0.78)
            let start = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX, dy: startY - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX, dy: endY - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Could not reach \(element)", file: file, line: line)
    }

    private func dismissKnownKeyboard(in app: XCUIApplication, file: StaticString, line: UInt) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let candidates = [
            app.buttons["workout.keyboard-done"],
            app.buttons["weight.keyboard-done"],
            app.keyboards.buttons.matching(identifier: "Done").firstMatch
        ]
        guard let done = candidates.first(where: { $0.exists && $0.isHittable }) else { return }
        done.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: keyboard)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed, "The keyboard must dismiss before scrolling.", file: file, line: line)
    }

    private func visibleTapArea(for element: XCUIElement, in app: XCUIApplication) -> CGRect {
        let window = app.windows.firstMatch.frame
        var bottom = window.maxY - 8
        let identifier = element.exists ? element.identifier : ""
        if !identifier.hasPrefix("navigation.") && identifier != "settings.open" {
            let navigation = ["navigation.today", "navigation.routines", "navigation.progress"]
                .map { app.buttons[$0] }.filter { $0.exists && $0.isHittable }
            if let top = navigation.map({ $0.frame.minY }).min() { bottom = min(bottom, top - 8) }
        }
        if app.keyboards.firstMatch.exists { bottom = min(bottom, app.keyboards.firstMatch.frame.minY - 8) }
        return CGRect(x: window.minX + 8, y: window.minY + 8, width: window.width - 16, height: max(0, bottom - window.minY - 8))
    }

    private func foregroundScrollView(containing element: XCUIElement, in app: XCUIApplication) -> XCUIElement? {
        if element.exists {
            let key = element.identifier.isEmpty ? "label" : "identifier"
            let value = element.identifier.isEmpty ? element.label : element.identifier
            let containers = app.scrollViews.containing(NSPredicate(format: "%K == %@", key, value)).allElementsBoundByIndex
            if let container = containers.last(where: { $0.exists && $0.frame.height > 100 }) { return container }
        }
        // Lazy rows may not exist until scrolled into view. The last visible
        // full-height container belongs to the presented sheet, not its parent.
        return app.scrollViews.allElementsBoundByIndex.last(where: { $0.exists && $0.isHittable && $0.frame.height > 100 })
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
