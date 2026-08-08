import SwiftData
import SwiftUI

/// Session Complete.
struct FinishSummaryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let outcome: FinishOutcome

    private var formatter: UnitFormatter { settings.unitFormatter }
    private var session: Session? { outcome.session }

    var body: some View {
        NavigationStack {
            List {
                if let session {
                    Section { totals(session).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)

                    if !outcome.records.isEmpty {
                        Section("New records") {
                            ForEach(Array(outcome.records.enumerated()), id: \.offset) { _, record in
                                recordRow(record)
                            }
                        }
                    }

                    Section("Exercises") {
                        ForEach(session.orderedExercises, id: \.persistentModelID) { entry in
                            breakdown(entry)
                        }
                    }

                    if outcome.droppedSetCount > 0 {
                        Section {
                            Text(droppedText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ContentUnavailableView("Session finished", systemImage: "checkmark.circle")
                }
            }
            .navigationTitle("Session complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Totals

    private func totals(_ session: Session) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 14) {
            GridRow {
                stat(DurationFormatting.compact(session.duration), "Duration")
                stat(formatter.volumeString(kg: session.volumeKg), "Volume")
            }
            GridRow {
                stat("\(session.workingSetCount)", "Working sets")
                stat("\(session.totalReps)", "Reps")
            }
        }
        .padding(.vertical, 16)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Records

    private func recordRow(_ record: RecordCandidate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind.symbolName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.subheadline.weight(.semibold))
                Text(record.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(record.formattedValue(formatter))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(record.improvementText(formatter))
                    .font(.caption)
                    .foregroundStyle(record.isFirstTime ? .secondary : Color.accentColor)
            }
        }
    }

    // MARK: Breakdown

    private func breakdown(_ entry: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatter.volumeString(kg: entry.volumeKg))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Warm-ups are labelled so the listed sets reconcile with the volume beside
            // them — otherwise the arithmetic looks wrong.
            ForEach(Array(entry.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                HStack(spacing: 8) {
                    Text(set.setType == .warmup ? "Warm-up" : "\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(set.setType == .warmup ? Color.orange : Color.secondary)
                        .frame(width: 58, alignment: .leading)
                    Text(setDescription(set, mode: entry.trackingMode))
                        .font(.caption.monospacedDigit())
                    Spacer()
                    if set.setType != .warmup, set.setType != .working {
                        Text(set.setType.displayName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func setDescription(_ set: SetEntry, mode: TrackingMode) -> String {
        switch mode {
        case .weightAndReps, .bodyweightPlusAdded:
            "\(formatter.string(kg: set.weightKg, includeUnit: false)) \(formatter.abbreviation) × \(set.reps)"
        case .bodyweightReps, .repsOnly:
            "\(set.reps) reps"
        case .timed:
            "\(set.durationSeconds)s"
        }
    }

    private var droppedText: String {
        var text = "\(outcome.droppedSetCount) unchecked "
        text += outcome.droppedSetCount == 1 ? "set was" : "sets were"
        text += " discarded."
        if outcome.droppedExerciseCount > 0 {
            let count = outcome.droppedExerciseCount
            text += " \(count) \(count == 1 ? "exercise" : "exercises") with no completed sets "
            text += count == 1 ? "was removed." : "were removed."
        }
        return text
    }
}
