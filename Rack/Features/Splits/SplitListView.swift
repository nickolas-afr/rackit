import SwiftData
import SwiftUI

struct SplitListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Split.order)]) private var splits: [Split]

    var body: some View {
        NavigationStack {
            List {
                if splits.isEmpty {
                    ContentUnavailableView(
                        "No splits",
                        systemImage: "square.stack.3d.up",
                        description: Text("A split is one training day you can start in a tap.")
                    )
                } else {
                    ForEach(splits, id: \.persistentModelID) { split in
                        NavigationLink {
                            SplitEditorView(split: split)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(split.name)
                                Text("\(split.exerciseCount) exercises · \(split.totalTargetSets) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteSplits)
                    .onMove(perform: moveSplits)
                }
            }
            .navigationTitle("Splits")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addSplit() } label: {
                        Label("New split", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }

    private func addSplit() {
        let split = Split(name: "New split", order: (splits.map(\.order).max() ?? -1) + 1)
        context.insert(split)
        try? context.save()
    }

    /// Deleting a split never affects sessions performed under it — the relationship
    /// nullifies rather than cascading.
    private func deleteSplits(at offsets: IndexSet) {
        for index in offsets { context.delete(splits[index]) }
        try? context.save()
    }

    private func moveSplits(from source: IndexSet, to destination: Int) {
        var reordered = splits
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, split) in reordered.enumerated() { split.order = index }
        try? context.save()
    }
}

struct SplitEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var split: Split

    @State private var showingPicker = false

    var body: some View {
        List {
            Section("Name") {
                TextField("Split name", text: $split.name)
            }

            Section("Exercises") {
                ForEach(split.orderedItems, id: \.persistentModelID) { item in
                    itemRow(item)
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)

                Button {
                    showingPicker = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
            }

            Section("Rest") {
                Toggle("Override exercise rest", isOn: Binding(
                    get: { split.restOverrideSeconds != nil },
                    set: { split.restOverrideSeconds = $0 ? 120 : nil }
                ))
                if let seconds = split.restOverrideSeconds {
                    Stepper(
                        "Rest \(seconds)s",
                        value: Binding(
                            get: { split.restOverrideSeconds ?? 120 },
                            set: { split.restOverrideSeconds = $0 }
                        ),
                        in: 15...600,
                        step: 15
                    )
                }
            }
        }
        .navigationTitle(split.name.isEmpty ? "Split" : split.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { exercise in
                let item = SplitItem(
                    order: (split.items.map(\.order).max() ?? -1) + 1,
                    exercise: exercise
                )
                item.split = split
                split.items.append(item)
                try? context.save()
            }
        }
        .onDisappear { try? context.save() }
    }

    @ViewBuilder
    private func itemRow(_ item: SplitItem) -> some View {
        // An exercise deleted from the library leaves the line orphaned rather than
        // gutting the split, so it is shown as such.
        VStack(alignment: .leading, spacing: 6) {
            Text(item.exercise?.name ?? "Removed exercise")
                .foregroundStyle(item.exercise == nil ? .secondary : .primary)
            HStack(spacing: 14) {
                Stepper("\(item.targetSets) sets",
                        value: Binding(get: { item.targetSets }, set: { item.targetSets = $0 }),
                        in: 1...12)
                    .font(.caption)
                Stepper("\(item.targetReps) reps",
                        value: Binding(get: { item.targetReps }, set: { item.targetReps = $0 }),
                        in: 1...50)
                    .font(.caption)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let ordered = split.orderedItems
        for index in offsets {
            let item = ordered[index]
            split.items.removeAll { $0 === item }
            context.delete(item)
        }
        for (index, item) in split.orderedItems.enumerated() { item.order = index }
        try? context.save()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = split.orderedItems
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() { item.order = index }
        try? context.save()
    }
}
