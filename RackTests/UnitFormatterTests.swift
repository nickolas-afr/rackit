import Foundation
import Testing
@testable import Rack

@Suite("Unit formatting")
struct UnitFormatterTests {

    private let uk = Locale(identifier: "en_GB")
    private let germany = Locale(identifier: "de_DE")

    @Test("Kilograms display unchanged")
    func kilogramsPassThrough() {
        let formatter = UnitFormatter(unit: .kilograms, locale: uk)
        #expect(formatter.displayValue(kg: 102.5) == 102.5)
        #expect(formatter.kilograms(fromDisplay: 102.5) == 102.5)
        #expect(formatter.string(kg: 102.5) == "102.5 kg")
        #expect(formatter.string(kg: 100) == "100 kg")
    }

    @Test("Pounds convert for display only")
    func poundsConvert() {
        let formatter = UnitFormatter(unit: .pounds, locale: uk)
        #expect(abs(formatter.displayValue(kg: 100) - 220.4622) < 0.001)
        #expect(formatter.string(kg: 100) == "220.46 lb")
    }

    @Test("Switching the display unit round-trips without drift")
    func unitRoundTripIsLossless() {
        let kilos = UnitFormatter(unit: .kilograms, locale: uk)
        let pounds = UnitFormatter(unit: .pounds, locale: uk)

        for stored in [0.0, 1.25, 2.5, 20, 60, 102.5, 142.5, 227.5, 1000] {
            // Display in pounds and convert straight back: no stored value changes.
            let asPounds = pounds.displayValue(kg: stored)
            #expect(abs(pounds.kilograms(fromDisplay: asPounds) - stored) < 1e-9)
            // Kilograms are the identity.
            #expect(kilos.kilograms(fromDisplay: kilos.displayValue(kg: stored)) == stored)
        }
    }

    @Test("Repeatedly toggling units never accumulates drift")
    func togglingUnitsDoesNotDrift() {
        let pounds = UnitFormatter(unit: .pounds, locale: uk)
        var stored = 102.5
        for _ in 0..<100 {
            stored = pounds.kilograms(fromDisplay: pounds.displayValue(kg: stored))
        }
        #expect(abs(stored - 102.5) < 1e-9)
    }

    @Test("Formatted decimals use the same separator the keypad types")
    func separatorMatchesKeypad() {
        let formatter = UnitFormatter(unit: .kilograms, locale: germany)
        #expect(formatter.decimalSeparator == ",")
        #expect(formatter.string(kg: 102.5, includeUnit: false) == "102,5")
    }

    @Test("The separator the keypad types is the one formatted values use",
          arguments: ["en_US", "en_GB", "de_DE", "fr_FR", "ru_RU", "tr_TR", "es_ES", "ja_JP"])
    func keypadSeparatorMatchesFormattedOutput(_ identifier: String) {
        let formatter = UnitFormatter(unit: .kilograms, locale: Locale(identifier: identifier))
        let formatted = formatter.string(kg: 102.5, includeUnit: false)

        // Whatever glyph the panel puts on its separator key must be the glyph that
        // appears in the row beside it, or the two disagree on screen.
        #expect(formatted.contains(formatter.decimalSeparator))
        #expect(formatter.parseDisplayValue(formatted) == 102.5)
    }

    @Test("The current locale is self-consistent too")
    func currentLocaleIsConsistent() {
        let formatter = UnitFormatter(unit: .kilograms, locale: .autoupdatingCurrent)
        let formatted = formatter.string(kg: 102.5, includeUnit: false)
        #expect(formatted.contains(formatter.decimalSeparator))
        #expect(formatter.parseDisplayValue(formatted) == 102.5)
    }

    @Test("A value typed with the locale separator parses back")
    func parsesLocaleSeparator() {
        let formatter = UnitFormatter(unit: .kilograms, locale: germany)
        #expect(formatter.parseDisplayValue("102,5") == 102.5)
        // A dot is accepted too — the two are indistinguishable to someone typing fast.
        #expect(formatter.parseDisplayValue("102.5") == 102.5)
        #expect(formatter.parseDisplayValue("") == nil)
        #expect(formatter.parseDisplayValue("abc") == nil)
    }

    @Test("Trailing zeros are trimmed so the keypad and the label agree")
    func trailingZerosTrimmed() {
        let formatter = UnitFormatter(unit: .kilograms, locale: uk)
        #expect(formatter.string(kg: 100.0, includeUnit: false) == "100")
        #expect(formatter.string(kg: 100.50, includeUnit: false) == "100.5")
        #expect(formatter.string(kg: 1.25, includeUnit: false) == "1.25")
    }

    @Test("Tonnage abbreviates once every kilogram is noise")
    func volumeAbbreviates() {
        let formatter = UnitFormatter(unit: .kilograms, locale: uk)
        #expect(formatter.volumeString(kg: 8_450) == "8450 kg")
        #expect(formatter.volumeString(kg: 12_400) == "12.4k kg")
        #expect(formatter.volumeString(kg: 250_000) == "250k kg")
    }

    @Test("Step buttons are plate-sized in whichever unit is on screen")
    func incrementsMatchTheDisplayUnit() {
        #expect(UnitFormatter(unit: .kilograms, locale: uk).weightIncrements == [1.25, 2.5, 5])
        #expect(UnitFormatter(unit: .pounds, locale: uk).weightIncrements == [2.5, 5, 10])
    }

    @Test("A step converts to kilograms before it touches a stored value")
    func incrementConvertsToKilograms() {
        let pounds = UnitFormatter(unit: .pounds, locale: uk)
        #expect(abs(pounds.incrementInKilograms(5) - 2.26796) < 0.0001)
        let kilos = UnitFormatter(unit: .kilograms, locale: uk)
        #expect(kilos.incrementInKilograms(2.5) == 2.5)
    }
}
