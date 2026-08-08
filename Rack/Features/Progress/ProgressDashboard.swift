import Charts
import SwiftData
import SwiftUI

struct ProgressDashboard: View {
    @Environment(AppSettings.self) private var settings

    @Query(
        filter: #Predicate<Session> { $0.finishedAt != nil },
        sort: [SortDescriptor(\Session.finishedAt, order: .reverse)]
    )
    private var sessions: [Session]

    @Query(sort: [SortDescriptor(\PersonalRecord.achievedAt, order: .reverse)])
    private var records: [PersonalRecord]

    private var formatter: UnitFormatter { settings.unitFormatter }

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Nothing logged yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Finish a session and your progress shows up here.")
                    )
                } else {
                    totalsSection
                    tonnageSection
                    sessionsPerWeekSection
                    regionSection
                }

                Section {
                    NavigationLink {
                        MuscleHeatmapView()
                    } label: {
                        Label("Muscle heatmap", systemImage: "figure.stand")
                    }
                }

                recordsSection
            }
            .navigationTitle("Progress")
        }
    }

    // MARK: All-time

    private var totalsSection: some View {
        Section("All time") {
            LabeledContent("Sessions", value: "\(sessions.count)")
            LabeledContent("Volume", value: formatter.volumeString(kg: sessions.reduce(0) { $0 + $1.volumeKg }))
            LabeledContent("Working sets", value: "\(sessions.reduce(0) { $0 + $1.workingSetCount })")
            LabeledContent("Reps", value: "\(sessions.reduce(0) { $0 + $1.totalReps })")
            LabeledContent("Records", value: "\(records.count)")
        }
    }

    // MARK: Weekly buckets

    private struct Week: Identifiable {
        var id: Date { start }
        var start: Date
        var volume: Double
        var sessions: Int
    }

    /// Twelve weeks, including the ones with nothing in them.
    ///
    /// A week is charted as zero rather than omitted — a training gap is information,
    /// and dropping it would quietly redraw a month off as continuous progress.
    private func weeks(count: Int = 12) -> [Week] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }

        return (0..<count).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)
            else { return nil }

            let inWeek = sessions.filter {
                let date = $0.finishedAt ?? $0.startedAt
                return date >= start && date < end
            }
            return Week(
                start: start,
                volume: inWeek.reduce(0) { $0 + $1.volumeKg },
                sessions: inWeek.count
            )
        }
    }

    private var tonnageSection: some View {
        Section("Weekly tonnage") {
            Chart(weeks()) { week in
                BarMark(
                    x: .value("Week", week.start, unit: .weekOfYear),
                    y: .value("Volume", week.volume)
                )
                .foregroundStyle(Color.accentColor)
            }
            .chartYAxisLabel(formatter.abbreviation)
            .frame(height: 160)
        }
    }

    private var sessionsPerWeekSection: some View {
        Section("Sessions per week") {
            Chart(weeks()) { week in
                BarMark(
                    x: .value("Week", week.start, unit: .weekOfYear),
                    y: .value("Sessions", week.sessions)
                )
                .foregroundStyle(Color.accentColor.opacity(0.7))
            }
            .frame(height: 120)
        }
    }

    // MARK: Regions

    private var regionSection: some View {
        let since = Calendar.current.date(byAdding: .day, value: -7, to: .now)
        let contributions = MuscleContributionBuilder.contributions(from: sessions, since: since)
        let perRegion = MuscleLoadCalculator.setsPerRegion(contributions: contributions)

        return Section("Sets by region · last 7 days") {
            ForEach(MuscleRegion.allCases) { region in
                let sets = perRegion[region] ?? 0
                HStack {
                    Text(region.displayName)
                        .frame(width: 90, alignment: .leading)
                    GeometryReader { proxy in
                        let peak = max(perRegion.values.max() ?? 1, 1)
                        Capsule()
                            .fill(sets > 0 ? Color.accentColor : Color.secondary.opacity(0.18))
                            .frame(width: max(4, proxy.size.width * sets / peak), height: 10)
                            .frame(height: proxy.size.height, alignment: .center)
                    }
                    .frame(height: 18)
                    Text(sets == sets.rounded() ? "\(Int(sets))" : String(format: "%.1f", sets))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }

    // MARK: Records

    private var recordsSection: some View {
        Section("Personal records") {
            if records.isEmpty {
                Text("No records yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records, id: \.persistentModelID) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.exercise?.name ?? "Removed exercise")
                                .font(.subheadline)
                            Text(record.kind.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(record.formattedValue(formatter))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text(record.achievedAt.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
