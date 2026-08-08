import SwiftData
import SwiftUI

/// One set: `[type] [last time] [weight] [reps] [✓]`.
///
/// The property is `setEntry` rather than `set` because a computed property whose body
/// begins `set.` parses as a setter accessor.
///
/// Every field is a button rather than a text field, which is what keeps the system
/// keyboard from ever appearing.
struct SetRowView: View {
    @Environment(SessionController.self) private var controller
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    let setEntry: SetEntry
    let index: Int
    let reference: LastSetReference?
    let onCompletionToggled: (Bool) -> Void

    private var formatter: UnitFormatter { settings.unitFormatter }
    private var mode: TrackingMode { setEntry.trackingMode }

    var body: some View {
        HStack(spacing: 8) {
            typeChip
            lastTimeText
            Spacer(minLength: 0)
            fields
            checkButton
        }
        .padding(.vertical, 2)
        .animation(.snappy(duration: 0.18), value: setEntry.isCompleted)
    }

    // MARK: Type

    private var typeChip: some View {
        Button {
            controller.cycleType(setEntry, context: context)
        } label: {
            Text(setEntry.setType == .working ? "\(index + 1)" : setEntry.setType.badge)
                .font(.footnote.weight(.bold).monospacedDigit())
                .frame(width: 28, height: 28)
                .background(typeColour.opacity(0.18), in: .circle)
                .foregroundStyle(typeColour)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set type: \(setEntry.setType.displayName)")
        .accessibilityHint("Double tap to change set type")
    }

    private var typeColour: Color {
        switch setEntry.setType {
        case .working: .secondary
        case .warmup: .orange
        case .dropSet: .purple
        case .toFailure: .red
        case .amrap: .blue
        }
    }

    // MARK: Last time

    private var lastTimeText: some View {
        Text(referenceText)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .frame(width: 74, alignment: .leading)
            .accessibilityLabel(referenceText == "—" ? "No previous set" : "Last time \(referenceText)")
    }

    private var referenceText: String {
        guard let reference else { return "—" }
        switch mode {
        case .weightAndReps, .bodyweightPlusAdded:
            return "\(formatter.string(kg: reference.weightKg, includeUnit: false))×\(reference.reps)"
        case .bodyweightReps, .repsOnly:
            return "\(reference.reps) reps"
        case .timed:
            return "\(reference.durationSeconds)s"
        }
    }

    // MARK: Editable fields

    @ViewBuilder
    private var fields: some View {
        if mode.showsWeightField {
            valueButton(field: .weight, width: 76, suffix: formatter.abbreviation)
        }
        if mode.showsRepsField {
            valueButton(field: .reps, width: 56, suffix: "reps")
        }
        if mode.showsDurationField {
            valueButton(field: .duration, width: 66, suffix: "sec")
        }
    }

    private func valueButton(field: KeypadField, width: CGFloat, suffix: String) -> some View {
        let isFocused = controller.keypadTarget == KeypadTarget(setUID: setEntry.uid, field: field)
        return Button {
            controller.focus(KeypadTarget(setUID: setEntry.uid, field: field))
        } label: {
            VStack(spacing: 0) {
                Text(controller.keypadDisplayText(for: setEntry, field: field, formatter: formatter))
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(suffix)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: width, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isFocused ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.accentColor, lineWidth: isFocused ? 1.5 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fieldLabel(field))
        .accessibilityValue(controller.storedText(for: setEntry, field: field, formatter: formatter))
    }

    private func fieldLabel(_ field: KeypadField) -> String {
        switch field {
        case .weight: "Weight"
        case .reps: "Reps"
        case .duration: "Duration in seconds"
        }
    }

    // MARK: Completion

    private var checkButton: some View {
        Button {
            let shouldRest = controller.toggleCompleted(setEntry, context: context, settings: settings)
            onCompletionToggled(shouldRest)
        } label: {
            Image(systemName: setEntry.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(setEntry.isCompleted ? Color.accentColor : Color.secondary.opacity(0.5))
                .frame(width: 40, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(setEntry.isCompleted ? "Completed" : "Mark set complete")
    }
}
