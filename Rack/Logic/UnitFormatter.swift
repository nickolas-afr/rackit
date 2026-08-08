import Foundation

/// Display-only unit handling.
///
/// Every weight in the store is kilograms. Nothing here ever writes back: converting
/// for display and converting a typed value back to kilograms are separate, exact
/// operations, so switching the display unit cannot introduce rounding drift into
/// stored data.
nonisolated struct UnitFormatter: Sendable, Equatable {
    static let poundsPerKilogram = 2.2046226218487757

    var unit: WeightUnit
    var locale: Locale

    init(unit: WeightUnit, locale: Locale = .autoupdatingCurrent) {
        self.unit = unit
        self.locale = locale
    }

    // MARK: Conversion

    /// Kilograms in, display units out. Unrounded — rounding belongs to formatting.
    func displayValue(kg: Double) -> Double {
        switch unit {
        case .kilograms: kg
        case .pounds: kg * Self.poundsPerKilogram
        }
    }

    /// Display units in, kilograms out. The exact inverse of `displayValue(kg:)`.
    func kilograms(fromDisplay value: Double) -> Double {
        switch unit {
        case .kilograms: value
        case .pounds: value / Self.poundsPerKilogram
        }
    }

    // MARK: Formatting

    /// The separator the numeric keypad types.
    ///
    /// Read back out of the same format style that produces every number on screen,
    /// rather than from `locale.decimalSeparator`. The two can disagree — notably for
    /// `Locale.autoupdatingCurrent` — and when they do, the keypad puts one glyph on its
    /// key while the row beside it shows another.
    var decimalSeparator: String {
        let sample = numberString(1.1, maximumFractionDigits: 1)
        let between = sample.dropFirst().dropLast()
        return between.isEmpty ? (locale.decimalSeparator ?? ".") : String(between)
    }

    var abbreviation: String { unit.abbreviation }

    /// A weight for display, with trailing zeros trimmed — "100", "102.5", "17.25".
    func string(kg: Double, includeUnit: Bool = true, maximumFractionDigits: Int = 2) -> String {
        let text = numberString(displayValue(kg: kg), maximumFractionDigits: maximumFractionDigits)
        return includeUnit ? "\(text) \(abbreviation)" : text
    }

    /// A raw display-unit number (already converted) for display.
    func string(displayValue value: Double, includeUnit: Bool = false, maximumFractionDigits: Int = 2) -> String {
        let text = numberString(value, maximumFractionDigits: maximumFractionDigits)
        return includeUnit ? "\(text) \(abbreviation)" : text
    }

    private func numberString(_ value: Double, maximumFractionDigits: Int) -> String {
        var style = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(0...maximumFractionDigits))
            .grouping(.never)
        style.locale = locale
        return value.formatted(style)
    }

    /// Parses text produced by the numeric keypad. Accepts the locale's separator and
    /// a plain dot, because the two are indistinguishable to someone typing quickly.
    func parseDisplayValue(_ text: String) -> Double? {
        let normalised = text
            .replacingOccurrences(of: decimalSeparator, with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !normalised.isEmpty else { return nil }
        return Double(normalised)
    }

    // MARK: Tonnage

    /// Session and weekly volume, which reaches numbers where every kilogram is noise.
    func volumeString(kg: Double) -> String {
        let value = displayValue(kg: kg)
        if value >= 100_000 {
            return "\(numberString(value / 1000, maximumFractionDigits: 0))k \(abbreviation)"
        }
        if value >= 10_000 {
            return "\(numberString(value / 1000, maximumFractionDigits: 1))k \(abbreviation)"
        }
        return "\(numberString(value, maximumFractionDigits: 0)) \(abbreviation)"
    }

    // MARK: Increments

    /// The step buttons that lead the numeric panel.
    ///
    /// Steps are expressed in the *display* unit: in kilograms these are the plate-pair
    /// jumps the spec calls for, and in pounds they are the equivalent plate jumps.
    /// Holding kilogram steps in a pounds-facing app would put 2.76 lb on a button.
    var weightIncrements: [Double] {
        switch unit {
        case .kilograms: [1.25, 2.5, 5]
        case .pounds: [2.5, 5, 10]
        }
    }

    /// A step converted to kilograms, for applying to stored values.
    func incrementInKilograms(_ displayIncrement: Double) -> Double {
        kilograms(fromDisplay: displayIncrement)
    }
}
