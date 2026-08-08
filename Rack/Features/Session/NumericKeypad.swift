import SwiftUI

/// The numeric panel that replaces the system keyboard.
///
/// It leads with step buttons rather than digits because mid-workout the intent is
/// almost never "type 102.5" — it is "same as last set, plus 2.5". The digit grid is
/// there for the times it really is a new number.
struct NumericKeypad: View {
    let title: String
    let displayText: String
    let unitLabel: String
    let field: KeypadField
    let decimalSeparator: String
    let weightIncrements: [Double]

    let onIncrement: (Double) -> Void
    let onDigit: (String) -> Void
    let onBackspace: () -> Void
    let onClear: () -> Void
    let onNext: () -> Void
    let onHide: () -> Void

    private var increments: [Double] {
        switch field {
        case .weight: weightIncrements
        case .reps: [1, 5]
        case .duration: [5, 15, 30]
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            stepRow
            digitGrid
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(displayText.isEmpty ? "0" : displayText)
                .font(.title2.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())

            if !unitLabel.isEmpty {
                Text(unitLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            // Tapping a value field is easy to do by accident with a phone in one hand,
            // so the panel always offers a way straight back out.
            Button {
                onHide()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Hide keypad")
        }
    }

    // MARK: Steps

    /// Two rows of three rather than one row of six: six targets across a phone leaves
    /// each one too narrow to hit one-handed, and narrow enough to wrap "−1.25".
    private var stepRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(increments, id: \.self) { stepButton(-$0) }
            }
            HStack(spacing: 6) {
                ForEach(increments, id: \.self) { stepButton($0) }
            }
        }
    }

    private func stepButton(_ amount: Double) -> some View {
        Button {
            onIncrement(amount)
        } label: {
            // Height comes from the button style's own padding rather than a minHeight:
            // the glass styles pad outside the label, so reserving a height here makes
            // the row taller than the layout allows for and it bleeds into the next one.
            Text(stepLabel(amount))
                .font(.callout.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(amount < 0 ? Color.secondary.opacity(0.22) : Color.accentColor)
        .foregroundStyle(amount < 0 ? Color.primary : Color.white)
    }

    private func stepLabel(_ amount: Double) -> String {
        let magnitude = abs(amount)
        let text = magnitude == magnitude.rounded()
            ? String(Int(magnitude))
            : String(format: "%g", magnitude)
        return (amount < 0 ? "−" : "+") + text
    }

    // MARK: Digits

    private var digitGrid: some View {
        HStack(spacing: 6) {
            VStack(spacing: 6) {
                ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]], id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { digit in
                            digitButton(digit)
                        }
                    }
                }
                HStack(spacing: 6) {
                    if field == .weight {
                        digitButton(decimalSeparator)
                    } else {
                        Button(action: onClear) {
                            Text("C")
                                .font(.title3.weight(.medium))
                                .padding(.vertical, 11)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                    digitButton("0")
                    Button(action: onBackspace) {
                        Image(systemName: "delete.backward")
                            .font(.title3)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Delete")
                }
            }

            Button(action: onNext) {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.title3)
                    Text("Next")
                        .font(.callout.weight(.semibold))
                }
                .frame(width: 78)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.glassProminent)
            .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func digitButton(_ digit: String) -> some View {
        Button {
            onDigit(digit)
        } label: {
            Text(digit)
                .font(.title3.weight(.medium).monospacedDigit())
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }
}

#Preview {
    VStack {
        Spacer()
        NumericKeypad(
            title: "Weight",
            displayText: "102.5",
            unitLabel: "kg",
            field: .weight,
            decimalSeparator: ".",
            weightIncrements: [1.25, 2.5, 5],
            onIncrement: { _ in },
            onDigit: { _ in },
            onBackspace: {},
            onClear: {},
            onNext: {},
            onHide: {}
        )
    }
}
