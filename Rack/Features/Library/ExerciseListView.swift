import SwiftData
import SwiftUI

struct ExerciseListView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<Exercise> { $0.isRetired == false },
        sort: [SortDescriptor(\Exercise.name)]
    )
    private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var region: MuscleRegion?
    @State private var equipment: Equipment?
    @State private var favouritesOnly = false
    @State private var showingNewExercise = false

    private var matches: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return exercises.filter { exercise in
            if favouritesOnly, !exercise.isFavourite { return false }
            if let region, exercise.primaryMuscle.region != region { return false }
            if let equipment, exercise.equipment != equipment { return false }
            if !query.isEmpty, !exercise.searchHaystack.contains(query) { return false }
            return true
        }
    }

    private var grouped: [(key: MuscleRegion, exercises: [Exercise])] {
        Dictionary(grouping: matches) { $0.primaryMuscle.region }
            .sorted { $0.key.displayName < $1.key.displayName }
            .map { (key: $0.key, exercises: $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                if matches.isEmpty {
                    ContentUnavailableView(
                        "Nothing matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different name, muscle or equipment.")
                    )
                } else {
                    ForEach(grouped, id: \.key) { group in
                        Section(group.key.displayName) {
                            ForEach(group.exercises, id: \.persistentModelID) { exercise in
                                NavigationLink {
                                    ExerciseDetailView(exercise: exercise)
                                } label: {
                                    row(exercise)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Name, muscle or equipment")
            .navigationTitle("Library")
            .safeAreaInset(edge: .top) { filterBar }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewExercise = true } label: {
                        Label("New exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewExercise) {
                CustomExerciseEditor(exercise: nil)
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                Text("\(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if exercise.isFavourite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Toggle(isOn: $favouritesOnly) {
                    Label("Favourites", systemImage: "star")
                }
                .toggleStyle(.button)
                .buttonStyle(.glass)

                Menu {
                    Button("All regions") { region = nil }
                    ForEach(MuscleRegion.allCases) { option in
                        Button(option.displayName) { region = option }
                    }
                } label: {
                    filterLabel(region?.displayName ?? "Region", isActive: region != nil)
                }

                Menu {
                    Button("All equipment") { equipment = nil }
                    ForEach(Equipment.allCases) { option in
                        Button(option.displayName) { equipment = option }
                    }
                } label: {
                    filterLabel(equipment?.displayName ?? "Equipment", isActive: equipment != nil)
                }

                if region != nil || equipment != nil || favouritesOnly {
                    Button("Clear") {
                        region = nil
                        equipment = nil
                        favouritesOnly = false
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
    }

    private func filterLabel(_ text: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.14),
            in: .capsule
        )
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
    }
}
