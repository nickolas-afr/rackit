import SwiftUI

/// Loads one side of the bar for a target weight, and says plainly when the target
/// cannot be made.
struct PlateCalculatorView: View {
    @Environment(AppSettings.self) private var settings

    let startingTargetKg: Double
    @State private var targetDisplay: Double = 0
    @State private var hasSeeded = false

    private var formatter: UnitFormatter { settings.unitFormatter }

    private var solution: PlateSolution {
        PlateCalculator.solve(
            targetKg: formatter.kilograms(fromDisplay: targetDisplay),
            barKg: settings.barWeightKg
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Target")
                Spacer()
                Text("\(formatter.string(displayValue: targetDisplay)) \(formatter.abbreviation)")
                    .font(.headline.monospacedDigit())
            }

            Stepper(
                "Target",
                value: $targetDisplay,
                in: 0...formatter.displayValue(kg: 500),
                step: formatter.weightIncrements.first ?? 1.25
            )
            .labelsHidden()

            let result = solution
            if result.isBelowBar {
                Label(
                    "Lighter than the bar (\(formatter.string(kg: result.barKg))).",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            } else if result.perSide.isEmpty && result.shortfallKg == 0 {
                Text("Empty bar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(result.perSide) { stack in
                        Text("\(formatter.string(kg: stack.plateKg, includeUnit: false))×\(stack.count)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.16), in: .capsule)
                    }
                }
                Text("Per side, plus the \(formatter.string(kg: result.barKg)) bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // The shortfall is reported rather than rounded away, so the user is never
            // silently handed a different weight than the one they asked for.
            if result.shortfallKg > 0 {
                Label(
                    "\(formatter.string(kg: result.shortfallKg)) short — closest is \(formatter.string(kg: result.achievedKg)).",
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
        .onAppear {
            guard !hasSeeded else { return }
            hasSeeded = true
            targetDisplay = formatter.displayValue(
                kg: max(startingTargetKg, settings.barWeightKg)
            ).rounded()
        }
    }
}
