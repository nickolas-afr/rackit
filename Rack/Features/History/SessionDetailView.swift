import SwiftData
import SwiftUI

/// One finished session, set by set.
struct SessionDetailView: View {
    @Environment(SessionController.self) private var controller
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: Session

    @Query private var allRecords: [PersonalRecord]
    @State private var showingDeleteConfirmation = false

    private var formatter: UnitFormatter { settings.unitFormatter }

    /// Sets that established a standing record, so history can mark them.
    private var recordSetUIDs: Set<UUID> {
        Set(allRecords.compactMap(\.setUID))
    }

    var body: some View {
        List {
            Section { totals.listRowInsets(EdgeInsets()) }
                .listRowBackground(Color.clear)

            ForEach(session.orderedExercises, id: \.persistentModelID) { entry in
                Section {
                    ForEach(Array(entry.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                        setRow(set, index: index, mode: entry.trackingMode)
                    }
                } header: {
                    HStack {
                        Text(entry.displayName)
                        Spacer()
                        Text(formatter.volumeString(kg: entry.volumeKg))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section {
                Button {
                    controller.repeatSession(session, context: context, settings: settings)
                    dismiss()
                } label: {
                    Label("Repeat this session", systemImage: "arrow.counterclockwise")
                }
                .disabled(controller.isActive)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete session", systemImage: "trash")
                }
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete session?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This session and its sets will be removed, and any record that depended on it will be recalculated. This cannot be undone.")
        }
    }

    private var totals: some View {
        HStack(spacing: 0) {
            stat(DurationFormatting.compact(session.duration), "Duration")
            stat(formatter.volumeString(kg: session.volumeKg), "Volume")
            stat("\(session.workingSetCount)", "Sets")
            stat("\(session.totalReps)", "Reps")
        }
        .padding(.vertical, 14)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func setRow(_ set: SetEntry, index: Int, mode: TrackingMode) -> some View {
        HStack(spacing: 10) {
            Text(set.setType == .warmup ? "W" : "\(index + 1)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(set.setType == .warmup ? Color.orange : Color.secondary)
                .frame(width: 24)

            Text(description(of: set, mode: mode))
                .font(.subheadline.monospacedDigit())

            if recordSetUIDs.contains(set.uid) {
                Image(systemName: "trophy.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }

            Spacer()

            if mode.supportsOneRepMax, set.weightKg > 0, set.reps > 0 {
                let estimate = OneRepMax.estimate(
                    weight: set.weightKg,
                    reps: set.reps,
                    formula: settings.oneRepMaxFormula
                )
                Text("1RM \(formatter.string(kg: estimate))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func description(of set: SetEntry, mode: TrackingMode) -> String {
        switch mode {
        case .weightAndReps, .bodyweightPlusAdded:
            "\(formatter.string(kg: set.weightKg, includeUnit: false)) \(formatter.abbreviation) × \(set.reps)"
        case .bodyweightReps, .repsOnly:
            "\(set.reps) reps"
        case .timed:
            "\(set.durationSeconds)s"
        }
    }

    /// Deleting rebuilds the record table from what is left, so a record can never
    /// outlive the session that produced it.
    private func delete() {
        context.delete(session)
        try? context.save()
        try? RecordService.rebuildAll(context: context, formula: settings.oneRepMaxFormula)
        dismiss()
    }
}
