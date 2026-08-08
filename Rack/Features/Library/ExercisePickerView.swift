import SwiftData
import SwiftUI

/// Picks one exercise from the library. Used to add an exercise mid-session and to
/// build splits.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Exercise> { $0.isRetired == false },
        sort: [SortDescriptor(\Exercise.name)]
    )
    private var exercises: [Exercise]

    @State private var searchText = ""
    let onSelect: (Exercise) -> Void

    private var matches: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.searchHaystack.contains(query) }
    }

    private var favourites: [Exercise] {
        searchText.isEmpty ? exercises.filter(\.isFavourite) : []
    }

    var body: some View {
        NavigationStack {
            List {
                if !favourites.isEmpty {
                    Section("Favourites") {
                        ForEach(favourites, id: \.persistentModelID) { row($0) }
                    }
                }
                Section(searchText.isEmpty ? "All exercises" : "Results") {
                    if matches.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(matches, id: \.persistentModelID) { row($0) }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Name, muscle or equipment")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .foregroundStyle(.primary)
                Text("\(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
