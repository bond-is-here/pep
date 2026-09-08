import Foundation

/// Input fields accept decimal digits and the current locale's decimal separator.
/// Grouping, signs and partially parsed suffixes are deliberately rejected.
public enum WorkoutNumberInput {
    public static func decimal(_ text: String, locale: Locale = .current) -> Double? {
        let separator = locale.decimalSeparator ?? "."
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var normalized = ""
        var foundSeparator = false
        var digitCount = 0
        for character in trimmed {
            if String(character) == separator {
                guard !foundSeparator else { return nil }
                foundSeparator = true
                normalized.append(".")
            } else {
                guard character.unicodeScalars.count == 1,
                      character.unicodeScalars.first?.properties.generalCategory == .decimalNumber,
                      let digit = character.wholeNumberValue, (0...9).contains(digit) else { return nil }
                normalized.append(String(digit))
                digitCount += 1
            }
        }
        guard digitCount > 0, let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    public static func integer(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var normalized = ""
        for character in trimmed {
            guard character.unicodeScalars.count == 1,
                  character.unicodeScalars.first?.properties.generalCategory == .decimalNumber,
                  let digit = character.wholeNumberValue, (0...9).contains(digit) else { return nil }
            normalized.append(String(digit))
        }
        return Int(normalized)
    }

    public static func format(_ value: Double, maximumFractionDigits: Int = 2, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

/// Keeps display rounding separate from the actual weight recorded by the user.
/// Rechecking a set or editing its reps must not round-trip rounded pounds to kg.
public struct WorkoutWeightDraft {
    public var text: String
    private var savedText: String
    private var savedKilograms: Double

    public init(kilograms: Double, unit: WeightUnit, locale: Locale = .current) {
        text = WorkoutNumberInput.format(unit.value(fromKilograms: kilograms), locale: locale)
        savedText = text
        savedKilograms = kilograms
    }

    public func kilograms(unit: WeightUnit, locale: Locale = .current) -> Double? {
        let kilograms: Double
        if text == savedText {
            kilograms = savedKilograms
        } else {
            guard let value = WorkoutNumberInput.decimal(text, locale: locale) else { return nil }
            kilograms = unit.kilograms(from: value)
        }
        guard kilograms.isFinite, (0...1_500).contains(kilograms) else { return nil }
        return kilograms
    }

    public mutating func accept(kilograms: Double) {
        savedText = text
        savedKilograms = kilograms
    }
}
