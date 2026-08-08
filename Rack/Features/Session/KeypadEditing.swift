import Foundation
import SwiftData

/// How the numeric panel edits a value.
///
/// Typed digits accumulate in a buffer and are committed on every keystroke, so the row
/// always shows what the panel shows. Step buttons act on the stored value instead and
/// clear the buffer — mid-workout the intent is "same as last set, plus 2.5", not
/// "retype the number".
extension SessionController {

    func keypadDisplayText(for set: SetEntry, field: KeypadField, formatter: UnitFormatter) -> String {
        if keypadTarget?.setUID == set.uid, keypadTarget?.field == field, !keypadBuffer.isEmpty {
            return keypadBuffer
        }
        return storedText(for: set, field: field, formatter: formatter)
    }

    func storedText(for set: SetEntry, field: KeypadField, formatter: UnitFormatter) -> String {
        switch field {
        case .weight:
            formatter.string(kg: set.weightKg, includeUnit: false)
        case .reps:
            "\(set.reps)"
        case .duration:
            "\(set.durationSeconds)"
        }
    }

    func appendDigit(
        _ digit: String,
        to set: SetEntry,
        field: KeypadField,
        formatter: UnitFormatter,
        context: ModelContext
    ) {
        let isSeparator = digit == formatter.decimalSeparator
        if isSeparator {
            // Only the weight field is fractional, and only one separator is meaningful.
            guard field == .weight, !keypadBuffer.contains(formatter.decimalSeparator) else { return }
            if keypadBuffer.isEmpty { keypadBuffer = "0" }
        }
        guard keypadBuffer.count < 7 else { return }

        keypadBuffer += digit
        commitBuffer(to: set, field: field, formatter: formatter, context: context)
    }

    func backspace(
        on set: SetEntry,
        field: KeypadField,
        formatter: UnitFormatter,
        context: ModelContext
    ) {
        if keypadBuffer.isEmpty {
            keypadBuffer = storedText(for: set, field: field, formatter: formatter)
        }
        guard !keypadBuffer.isEmpty else { return }
        keypadBuffer.removeLast()
        commitBuffer(to: set, field: field, formatter: formatter, context: context)
    }

    func clearField(
        on set: SetEntry,
        field: KeypadField,
        formatter: UnitFormatter,
        context: ModelContext
    ) {
        keypadBuffer = ""
        write(0, to: set, field: field, formatter: formatter)
        try? context.save()
    }

    /// `amount` is in display units for weight and in whole reps or seconds otherwise.
    func increment(
        _ amount: Double,
        on set: SetEntry,
        field: KeypadField,
        formatter: UnitFormatter,
        context: ModelContext
    ) {
        keypadBuffer = ""
        switch field {
        case .weight:
            // Step in the display unit, then convert, so a pounds user gets pound-sized
            // jumps and the stored kilograms stay exact.
            let current = formatter.displayValue(kg: set.weightKg)
            let stepped = max(0, current + amount)
            set.weightKg = formatter.kilograms(fromDisplay: stepped)
        case .reps:
            set.reps = max(0, set.reps + Int(amount))
        case .duration:
            set.durationSeconds = max(0, set.durationSeconds + Int(amount))
        }
        try? context.save()
    }

    private func commitBuffer(
        to set: SetEntry,
        field: KeypadField,
        formatter: UnitFormatter,
        context: ModelContext
    ) {
        let value = formatter.parseDisplayValue(keypadBuffer) ?? 0
        write(value, to: set, field: field, formatter: formatter)
        try? context.save()
    }

    private func write(_ displayValue: Double, to set: SetEntry, field: KeypadField, formatter: UnitFormatter) {
        switch field {
        case .weight: set.weightKg = formatter.kilograms(fromDisplay: max(0, displayValue))
        case .reps: set.reps = max(0, Int(displayValue))
        case .duration: set.durationSeconds = max(0, Int(displayValue))
        }
    }
}
