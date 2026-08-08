import SwiftData
import SwiftUI

/// Creates a custom exercise, or edits an existing one.
///
/// Built-ins expose only rest and notes. Everything else about them is owned by the
/// catalogue, and re-seeding overwrites it — letting the user edit those fields would
/// silently discard their work on the next catalogue bump.
struct CustomExerciseEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise?

    @State private var name = ""
    @State private var primaryMuscle: MuscleGroup = .chest
    @State private var secondaryMuscles: Set<MuscleGroup> = []
    @State private var equipment: Equipment = .barbell
    @State private var mechanic: Mechanic = .compound
    @State private var trackingMode: TrackingMode = .weightAndReps
    @State private var restSeconds = 120
    @State private var notes = ""
    @State private var showingDeleteConfirmation = false

    private var isEditingBuiltIn: Bool { exercise?.isCustom == false }
    private var isNew: Bool { exercise == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Exercise name", text: $name)
                        .disabled(isEditingBuiltIn)
                }

                Section {
                    Picker("Primary muscle", selection: $primaryMuscle) {
                        ForEach(MuscleGroup.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Mechanic", selection: $mechanic) {
                        ForEach(Mechanic.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Tracking", selection: $trackingMode) {
                        ForEach(TrackingMode.allCases) { Text($0.displayName).tag($0) }
                    }
                } header: {
                    Text("Classification")
                } footer: {
                    if isEditingBuiltIn {
                        Text("Built-in exercises only allow rest and notes to be changed, so updating the catalogue cannot overwrite your edits.")
                    }
                }
                .disabled(isEditingBuiltIn)

                if !isEditingBuiltIn {
                    Section("Secondary muscles") {
                        ForEach(MuscleGroup.allCases) { muscle in
                            Toggle(muscle.displayName, isOn: Binding(
                                get: { secondaryMuscles.contains(muscle) },
                                set: { isOn in
                                    if isOn { secondaryMuscles.insert(muscle) }
                                    else { secondaryMuscles.remove(muscle) }
                                }
                            ))
                        }
                    }
                }

                Section("Rest") {
                    Stepper("\(restSeconds)s", value: $restSeconds, in: 15...600, step: 15)
                }

                Section("Notes") {
                    TextField("Cues, setup, anything", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let exercise, exercise.isCustom {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete exercise", systemImage: "trash")
                        }
                    } footer: {
                        Text("Sessions where you performed it keep their record of having done so.")
                    }
                }
            }
            .navigationTitle(isNew ? "New exercise" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete exercise?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The exercise is removed from the library. Sessions that used it keep their sets.")
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let exercise else { return }
        name = exercise.name
        primaryMuscle = exercise.primaryMuscle
        secondaryMuscles = Set(exercise.secondaryMuscles)
        equipment = exercise.equipment
        mechanic = exercise.mechanic
        trackingMode = exercise.trackingMode
        restSeconds = exercise.defaultRestSeconds
        notes = exercise.notes
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if let exercise {
            // Built-ins accept rest and notes only.
            exercise.defaultRestSeconds = restSeconds
            exercise.notes = notes
            if exercise.isCustom {
                exercise.name = trimmed
                exercise.primaryMuscle = primaryMuscle
                exercise.secondaryMuscles = Array(secondaryMuscles)
                exercise.equipment = equipment
                exercise.mechanic = mechanic
                exercise.trackingMode = trackingMode
            }
        } else {
            let created = Exercise(
                slug: "custom-\(UUID().uuidString.lowercased())",
                name: trimmed,
                primaryMuscle: primaryMuscle,
                secondaryMuscles: Array(secondaryMuscles),
                equipment: equipment,
                mechanic: mechanic,
                trackingMode: trackingMode,
                defaultRestSeconds: restSeconds,
                notes: notes,
                isCustom: true
            )
            context.insert(created)
        }
        try? context.save()
        dismiss()
    }

    /// The exercise goes; the history of having performed it stays, because the session
    /// rows snapshot the name and the relationship nullifies rather than cascading.
    private func delete() {
        guard let exercise else { return }
        context.delete(exercise)
        try? context.save()
        dismiss()
    }
}
