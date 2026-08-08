import Charts
import SwiftData
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Bindable var exercise: Exercise
    @State private var showingEditor = false

    private var formatter: UnitFormatter { settings.unitFormatter }

    /// Every finished performance of this movement, oldest first.
    private var performances: [SessionExercise] {
        let slug = exercise.slug
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { $0.exercise?.slug == slug && $0.session?.finishedAt != nil }
        )
        return ((try? context.fetch(descriptor)) ?? [])
            .sorted { ($0.session?.finishedAt ?? .distantPast) < ($1.session?.finishedAt ?? .distantPast) }
    }

    private struct Point: Identifiable {
        var id: Date { date }
        var date: Date
        var oneRepMax: Double
        var heaviest: Double
        var volume: Double
    }

    private func points() -> [Point] {
        performances.compactMap { entry in
            guard let date = entry.session?.finishedAt else { return nil }
            let scoring = entry.orderedSets.filter { $0.isCompleted && $0.setType.canSetRecord }
            guard !scoring.isEmpty else { return nil }
            let best = scoring.map {
                OneRepMax.estimate(weight: $0.weightKg, reps: $0.reps, formula: settings.oneRepMaxFormula)
            }.max() ?? 0
            return Point(
                date: date,
                oneRepMax: best,
                heaviest: scoring.map(\.weightKg).max() ?? 0,
                volume: entry.volumeKg
            )
        }
    }

    private var records: [RecordKind: PersonalRecord] { RecordService.records(for: exercise) }

    var body: some View {
        List {
            summarySection

            let series = points()
            if series.count >= 2 {
                strengthSection(series)
                volumeSection(series)
            }

            if !records.isEmpty { recordsSection }
            if exercise.trackingMode.supportsOneRepMax, let top = records[.bestOneRepMax]?.value, top > 0 {
                targetLoadSection(oneRepMax: top)
            }
            if exercise.usesPlateCalculator { plateSection }
            if !performances.isEmpty { recentSection }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exercise.isFavourite.toggle()
                    try? context.save()
                } label: {
                    Label("Favourite", systemImage: exercise.isFavourite ? "star.fill" : "star")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            CustomExerciseEditor(exercise: exercise)
        }
    }

    // MARK: Sections

    private var summarySection: some View {
        Section {
            LabeledContent("Primary", value: exercise.primaryMuscle.displayName)
            if !exercise.secondaryMuscles.isEmpty {
                LabeledContent(
                    "Secondary",
                    value: exercise.secondaryMuscles.map(\.displayName).joined(separator: ", ")
                )
            }
            LabeledContent("Equipment", value: exercise.equipment.displayName)
            LabeledContent("Mechanic", value: exercise.mechanic.displayName)
            LabeledContent("Tracking", value: exercise.trackingMode.displayName)
            LabeledContent("Default rest", value: "\(exercise.defaultRestSeconds)s")
            if !exercise.notes.isEmpty {
                Text(exercise.notes).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func strengthSection(_ series: [Point]) -> some View {
        Section("Strength") {
            Chart {
                ForEach(series) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Estimated 1RM", point.oneRepMax),
                        series: .value("Series", "1RM")
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Heaviest set", point.heaviest),
                        series: .value("Series", "Heaviest")
                    )
                    .foregroundStyle(Color.secondary)
                    .interpolationMethod(.monotone)
                }
            }
            .chartYAxisLabel(formatter.abbreviation)
            .frame(height: 180)

            HStack(spacing: 14) {
                legend(colour: Color.accentColor, label: "Est. 1RM")
                legend(colour: Color.secondary, label: "Heaviest set")
            }
            .font(.caption)
        }
    }

    private func volumeSection(_ series: [Point]) -> some View {
        Section("Volume per session") {
            Chart(series) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(Color.accentColor.opacity(0.75))
            }
            .frame(height: 140)
        }
    }

    private func legend(colour: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(colour).frame(width: 14, height: 3)
            Text(label).foregroundStyle(.secondary)
        }
    }

    private var recordsSection: some View {
        Section("Records") {
            ForEach(RecordKind.allCases) { kind in
                if let record = records[kind] {
                    HStack {
                        Label(kind.shortName, systemImage: kind.symbolName)
                            .font(.subheadline)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(record.formattedValue(formatter))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            if let context = record.contextText(formatter) {
                                Text(context)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    /// What to load for a given rep count, inverted from the best estimate.
    private func targetLoadSection(oneRepMax: Double) -> some View {
        Section {
            ForEach([1, 3, 5, 8, 10, 12], id: \.self) { reps in
                let load = OneRepMax.load(
                    forReps: reps,
                    oneRepMax: oneRepMax,
                    formula: settings.oneRepMaxFormula
                )
                LabeledContent("\(reps) reps", value: formatter.string(kg: load))
                    .monospacedDigit()
            }
        } header: {
            Text("Target load")
        } footer: {
            Text("Estimated from your best \(settings.oneRepMaxFormula.displayName) 1RM.")
        }
    }

    private var plateSection: some View {
        Section("Plate calculator") {
            PlateCalculatorView(
                startingTargetKg: records[.heaviestWeight]?.value ?? settings.barWeightKg
            )
        }
    }

    private var recentSection: some View {
        Section("Recent sessions") {
            ForEach(performances.reversed().prefix(8), id: \.persistentModelID) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.session?.title ?? "Session")
                            .font(.subheadline)
                        Spacer()
                        Text((entry.session?.finishedAt ?? .now)
                            .formatted(.dateTime.day().month(.abbreviated)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(entry.completedSets.count) sets · \(formatter.volumeString(kg: entry.volumeKg))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
