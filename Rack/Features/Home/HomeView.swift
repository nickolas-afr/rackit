import SwiftData
import SwiftUI

/// Answers "what am I training, and can I start now?"
///
/// The thing done every single time — starting a split — is the largest target on the
/// screen and never more than one tap. Ad-hoc actions live in the overflow menu.
struct HomeView: View {
    @Environment(SessionController.self) private var controller
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Split.order)]) private var splits: [Split]
    @Query(
        filter: #Predicate<Session> { $0.finishedAt != nil },
        sort: [SortDescriptor(\Session.finishedAt, order: .reverse)]
    )
    private var finishedSessions: [Session]
    @Query private var records: [PersonalRecord]

    @State private var showingSplitEditor = false
    @State private var showingExercisePicker = false

    private var formatter: UnitFormatter { settings.unitFormatter }

    /// The least recently trained split. No schedule to configure, and it self-corrects:
    /// training something moves it to the back of the queue.
    private var suggested: Split? {
        splits.min { $0.rotationSortKey < $1.rotationSortKey }
    }

    private var otherSplits: [Split] {
        splits.filter { $0.persistentModelID != suggested?.persistentModelID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    if !otherSplits.isEmpty { splitRail }
                    weekStrip
                    if let last = finishedSessions.first { lastSession(last) }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle(dateTitle)
            .navigationSubtitle("Week \(weekNumber)")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingSplitEditor) { SplitListView() }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    controller.startEmpty(context: context, settings: settings)
                    controller.addExercise(exercise, context: context)
                }
            }
        }
    }

    private var dateTitle: String {
        Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var weekNumber: Int {
        Calendar.current.component(.weekOfYear, from: .now)
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        if let session = controller.session {
            heroCard(
                eyebrow: "In progress",
                title: session.title,
                detail: "\(session.completedSetCount) sets · \(formatter.volumeString(kg: session.volumeKg))",
                action: "Continue"
            ) {
                controller.isPresented = true
            }
        } else if let suggested {
            heroCard(
                eyebrow: "Least recently trained",
                title: suggested.name,
                detail: subtitle(for: suggested),
                action: "Start"
            ) {
                controller.start(split: suggested, context: context, settings: settings)
            }
        } else {
            ContentUnavailableView(
                "No splits yet",
                systemImage: "square.stack.3d.up",
                description: Text("Create a training day to start logging.")
            )
            .frame(height: 200)
        }
    }

    private func heroCard(
        eyebrow: String,
        title: String,
        detail: String,
        action: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .textCase(.uppercase)

                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Label(action, systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: .capsule)
                        .foregroundStyle(.white)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.10), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: Split rail

    private var splitRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All splits")
                .font(.headline)
                .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(otherSplits, id: \.persistentModelID) { split in
                        // One tap starts it. A card that merely re-selects the headline
                        // would read as a dead tap.
                        Button {
                            controller.start(split: split, context: context, settings: settings)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(split.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(lastTrainedText(split))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                                Label("Start", systemImage: "play.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(14)
                            .frame(width: 150, height: 120, alignment: .leading)
                            .background(Color.secondary.opacity(0.10), in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(controller.isActive)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func subtitle(for split: Split) -> String {
        "\(split.exerciseCount) exercises · \(lastTrainedText(split))"
    }

    private func lastTrainedText(_ split: Split) -> String {
        guard let last = split.lastTrainedAt else { return "never trained" }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: last),
            to: Calendar.current.startOfDay(for: .now)
        ).day ?? 0
        return switch days {
        case 0: "trained today"
        case 1: "yesterday"
        default: "\(days) days ago"
        }
    }

    // MARK: This week

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(.headline)
                .padding(.horizontal, 16)

            let days = weekDays()
            let peak = max(days.map(\.volume).max() ?? 0, 1)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: 6) {
                        // Empty days still occupy their slot — a gap is information.
                        Capsule()
                            .fill(day.volume > 0 ? Color.accentColor : Color.secondary.opacity(0.18))
                            .frame(height: max(4, 70 * day.volume / peak))
                        Text(day.label)
                            .font(.caption2)
                            .foregroundStyle(day.isToday ? Color.accentColor : .secondary)
                            .fontWeight(day.isToday ? .bold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 92, alignment: .bottom)
            .padding(.horizontal, 16)

            let stats = weekStats()
            HStack(spacing: 0) {
                weekStat("\(stats.sessions)", "Sessions")
                weekStat(formatter.volumeString(kg: stats.volume), "Volume")
                weekStat("\(stats.sets)", "Sets")
                weekStat("\(stats.records)", "Records")
            }
            .padding(.horizontal, 16)
        }
    }

    private func weekStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private struct DayVolume {
        var date: Date
        var label: String
        var volume: Double
        var isToday: Bool
    }

    private func weekDays() -> [DayVolume] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let volume = finishedSessions
                .filter { calendar.isDate($0.finishedAt ?? $0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.volumeKg }
            return DayVolume(
                date: day,
                label: day.formatted(.dateTime.weekday(.narrow)),
                volume: volume,
                isToday: calendar.isDateInToday(day)
            )
        }
    }

    private func weekStats() -> (sessions: Int, volume: Double, sets: Int, records: Int) {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else {
            return (0, 0, 0, 0)
        }
        let thisWeek = finishedSessions.filter { ($0.finishedAt ?? $0.startedAt) >= weekStart }
        return (
            sessions: thisWeek.count,
            volume: thisWeek.reduce(0) { $0 + $1.volumeKg },
            sets: thisWeek.reduce(0) { $0 + $1.workingSetCount },
            records: records.filter { $0.achievedAt >= weekStart }.count
        )
    }

    // MARK: Last session

    private func lastSession(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last session")
                .font(.headline)
                .padding(.horizontal, 16)

            NavigationLink {
                SessionDetailView(session: session)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(sessionSubtitle(session))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.secondary.opacity(0.10), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    private func sessionSubtitle(_ session: Session) -> String {
        let when = (session.finishedAt ?? session.startedAt).formatted(.relative(presentation: .named))
        return "\(when) · \(session.workingSetCount) sets · \(formatter.volumeString(kg: session.volumeKg))"
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    controller.startEmpty(context: context, settings: settings)
                } label: {
                    Label("Empty session", systemImage: "square.dashed")
                }
                Button {
                    controller.repeatLast(context: context, settings: settings)
                } label: {
                    Label("Repeat last session", systemImage: "arrow.counterclockwise")
                }
                .disabled(finishedSessions.isEmpty)
                Divider()
                Button {
                    showingSplitEditor = true
                } label: {
                    Label("Edit splits", systemImage: "slider.horizontal.3")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .disabled(controller.isActive && splits.isEmpty)
        }
    }
}
