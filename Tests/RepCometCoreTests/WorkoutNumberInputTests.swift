import Foundation
import XCTest
@testable import RepCometCore

final class WorkoutNumberInputTests: XCTestCase {
    func testDecimalInputUsesLocaleSeparatorAndNativeDigits() throws {
        XCTAssertEqual(WorkoutNumberInput.decimal(" 12.5 ", locale: Locale(identifier: "en_US")), 12.5)
        XCTAssertEqual(WorkoutNumberInput.decimal("12,5", locale: Locale(identifier: "de_DE")), 12.5)
        XCTAssertEqual(WorkoutNumberInput.decimal("١٢٫٥", locale: Locale(identifier: "ar_EG")), 12.5)
        XCTAssertEqual(WorkoutNumberInput.decimal("۱۲٫۵", locale: Locale(identifier: "fa_IR")), 12.5)
        XCTAssertEqual(WorkoutNumberInput.integer("१२"), 12)
        XCTAssertEqual(WorkoutNumberInput.integer("١٢"), 12)
        for identifier in ["en_US", "de_DE", "fr_FR", "ar_EG", "fa_IR", "bn_BD"] {
            let locale = Locale(identifier: identifier)
            let formatted = WorkoutNumberInput.format(72.25, locale: locale)
            XCTAssertEqual(WorkoutNumberInput.decimal(formatted, locale: locale), 72.25, identifier)
        }
    }

    func testRejectsMalformedOrAmbiguousNumbersWithoutPartialParsing() {
        for text in ["", " ", ".", "1..2", "1,500", "12kg", "1e3", "NaN", "infinity", "-1", "+1", "1 2", "²", "三"] {
            XCTAssertNil(WorkoutNumberInput.decimal(text, locale: Locale(identifier: "en_US")), text)
        }
        XCTAssertNil(WorkoutNumberInput.decimal("1.500", locale: Locale(identifier: "de_DE")))
        XCTAssertNil(WorkoutNumberInput.decimal("1.234,5", locale: Locale(identifier: "de_DE")))
        XCTAssertNil(WorkoutNumberInput.integer("1.0"))
        XCTAssertNil(WorkoutNumberInput.integer("1 2"))
        XCTAssertNil(WorkoutNumberInput.integer(String(repeating: "9", count: 100)))
    }

    func testUneditedRoundedDisplayNeverChangesStoredKilograms() throws {
        let original = 31.752931147891
        for unit in WeightUnit.allCases {
            var draft = WorkoutWeightDraft(kilograms: original, unit: unit, locale: Locale(identifier: "en_US"))
            for _ in 0..<100 {
                let saved = try XCTUnwrap(draft.kilograms(unit: unit, locale: Locale(identifier: "en_US")))
                XCTAssertEqual(saved, original, "Reps and completion changes must retain exact weight")
                draft.accept(kilograms: saved)
            }
        }
    }

    func testEditedWeightConvertsOnceAndInvalidDraftCanRecover() throws {
        let locale = Locale(identifier: "de_DE")
        var draft = WorkoutWeightDraft(kilograms: 31.752931147891, unit: .lb, locale: locale)
        draft.text = "72,5"
        let kilograms = try XCTUnwrap(draft.kilograms(unit: .lb, locale: locale))
        XCTAssertEqual(kilograms, WeightUnit.lb.kilograms(from: 72.5))
        draft.accept(kilograms: kilograms)
        draft.text = ""
        XCTAssertNil(draft.kilograms(unit: .lb, locale: locale))
        draft.text = "72,5"
        XCTAssertEqual(draft.kilograms(unit: .lb, locale: locale), kilograms)
        draft.text = "9999"
        XCTAssertNil(draft.kilograms(unit: .lb, locale: locale))
        draft.text = "0"
        XCTAssertEqual(draft.kilograms(unit: .lb, locale: locale), 0)
    }
}
