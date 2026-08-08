import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\BodyWeightEntry.date, order: .reverse)])
    private var weighIns: [BodyWeightEntry]

    @State private var showingRebuildConfirmation = false
    @State private var rebuildResult: Int?
    @State private var newWeightDisplay: Double = 0
    @State private var hasSeededWeight = false

    private var formatter: UnitFormatter { settings.unitFormatter }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section {
                    Picker("Weight unit", selection: $settings.weightUnit) {
                        ForEach(WeightUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Display only. Every weight is stored in kilograms, so switching units never changes a logged value.")
                }

                oneRepMaxSection
                restSection

                Section("Feedback") {
                    Toggle("Haptics", isOn: $settings.restHapticsEnabled)
                    Toggle("Sound", isOn: $settings.restSoundEnabled)
                }

                Section {
                    Toggle("Keep screen awake during a session", isOn: $settings.keepScreenAwake)
                }

                bodyWeightSection

                Section {
                    Stepper(
                        "Bar \(formatter.string(kg: settings.barWeightKg))",
                        value: $settings.barWeightKg,
                        in: 5...40,
                        step: 2.5
                    )
                } header: {
                    Text("Plate calculator")
                } footer: {
                    Text("The empty bar the calculator loads plates onto.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: 1RM

    private var oneRepMaxSection: some View {
        @Bindable var settings = settings

        return Section {
            Picker("Formula", selection: $settings.oneRepMaxFormula) {
                ForEach(OneRepMaxFormula.allCases) { formula in
                    Text(formula.displayName).tag(formula)
                }
            }
            Text(settings.oneRepMaxFormula.expression)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            Button("Recalculate all records") { showingRebuildConfirmation = true }

            if let rebuildResult {
                Text("\(rebuildResult) records rebuilt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Estimated 1RM")
        } footer: {
            Text("Reps are capped at 12 for estimation. Stored 1RM records depend on the formula, so changing it is worth a rebuild.")
        }
        .alert("Recalculate every record?", isPresented: $showingRebuildConfirmation) {
            Button("Recalculate") { rebuild() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Records are rebuilt from your full history using the \(settings.oneRepMaxFormula.displayName) formula. No session is modified.")
        }
    }

    private func rebuild() {
        rebuildResult = try? RecordService.rebuildAll(
            context: context,
            formula: settings.oneRepMaxFormula
        )
    }

    // MARK: Rest

    private var restSection: some View {
        @Bindable var settings = settings

        return Section {
            Toggle("Start rest automatically", isOn: $settings.autoStartRestTimer)
            Stepper(
                "Default rest \(settings.fallbackRestSeconds)s",
                value: $settings.fallbackRestSeconds,
                in: 15...600,
                step: 15
            )
        } header: {
            Text("Rest timer")
        } footer: {
            Text("Used when neither the exercise nor the split says otherwise. Warm-up sets never start the timer.")
        }
    }

    // MARK: Body weight

    private var bodyWeightSection: some View {
        @Bindable var settings = settings

        return Section {
            Toggle("Log body weight", isOn: $settings.bodyWeightLoggingEnabled)

            if settings.bodyWeightLoggingEnabled {
                HStack {
                    Text("Today")
                    Spacer()
                    Text("\(formatter.string(displayValue: newWeightDisplay)) \(formatter.abbreviation)")
                        .monospacedDigit()
                }
                Stepper("Weight", value: $newWeightDisplay,
                        in: 0...formatter.displayValue(kg: 300), step: 0.5)
                    .labelsHidden()

                Button("Save weigh-in") { saveWeighIn() }
                    .disabled(newWeightDisplay <= 0)

                if let latest = weighIns.first {
                    LabeledContent(
                        "Latest",
                        value: "\(formatter.string(kg: latest.weightKg)) · \(latest.date.formatted(.dateTime.day().month(.abbreviated)))"
                    )
                }
            }
        } header: {
            Text("Body weight")
        } footer: {
            Text("Bodyweight movements use your latest weigh-in for volume. With none on record they assume \(formatter.string(kg: VolumeCalculator.assumedBodyWeightKg)).")
        }
        .onAppear {
            guard !hasSeededWeight else { return }
            hasSeededWeight = true
            newWeightDisplay = formatter.displayValue(
                kg: weighIns.first?.weightKg ?? VolumeCalculator.assumedBodyWeightKg
            )
        }
    }

    private func saveWeighIn() {
        let kg = formatter.kilograms(fromDisplay: newWeightDisplay)
        guard kg > 0 else { return }
        context.insert(BodyWeightEntry(date: .now, weightKg: kg))
        try? context.save()
    }
}
