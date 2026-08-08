import SwiftData
import SwiftUI

/// Finished sessions, newest first, grouped by month.
struct HistoryListView: View {
    @Environment(AppSettings.self) private var settings

    @Query(
        filter: #Predicate<Session> { $0.finishedAt != nil },
        sort: [SortDescriptor(\Session.finishedAt, order: .reverse)]
    )
    private var sessions: [Session]

    @State private var searchText = ""

    private var formatter: UnitFormatter { settings.unitFormatter }

    private var matches: [Session] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return sessions }
        return sessions.filter { session in
            session.title.lowercased().contains(query)
                || session.orderedExercises.contains { $0.displayName.lowercased().contains(query) }
        }
    }

    private var months: [(key: Date, sessions: [Session])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: matches) { session in
            calendar.date(from: calendar.dateComponents(
                [.year, .month],
                from: session.finishedAt ?? session.startedAt
            )) ?? .distantPast
        }
        return grouped.sorted { $0.key > $1.key }.map { (key: $0.key, sessions: $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                if matches.isEmpty {
                    if sessions.isEmpty {
                        ContentUnavailableView(
                            "No sessions yet",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("Finished sessions appear here.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    ForEach(months, id: \.key) { month in
                        Section(month.key.formatted(.dateTime.month(.wide).year())) {
                            ForEach(month.sessions, id: \.persistentModelID) { session in
                                NavigationLink {
                                    SessionDetailView(session: session)
                                } label: {
                                    row(session)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Session or exercise")
            .navigationTitle("History")
        }
    }

    private func row(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text((session.finishedAt ?? session.startedAt).formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(session.workingSetCount) sets · \(formatter.volumeString(kg: session.volumeKg)) · \(DurationFormatting.compact(session.duration))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
