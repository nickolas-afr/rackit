import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @State private var controller = SessionController()
    @State private var restTimer = RestTimerController()
    @State private var finishOutcome: FinishOutcome?

    var body: some View {
        @Bindable var controller = controller

        TabView {
            Tab("Today", systemImage: "figure.strengthtraining.traditional") {
                HomeView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryListView()
            }
            Tab("Library", systemImage: "books.vertical") {
                ExerciseListView()
            }
            Tab("Progress", systemImage: "chart.xyaxis.line") {
                ProgressDashboard()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .environment(controller)
        .safeAreaInset(edge: .bottom) { minimisedBar }
        .fullScreenCover(isPresented: $controller.isPresented) {
            if let session = controller.session {
                ActiveSessionView(session: session, restTimer: restTimer) { outcome in
                    restTimer.clear()
                    if !outcome.records.isEmpty {
                        HapticEngine.recordAwarded(haptics: settings.restHapticsEnabled)
                    }
                    finishOutcome = outcome
                } onRestRequested: { entry in
                    startRest(for: entry, in: session)
                }
                .environment(controller)
            }
        }
        .sheet(item: $finishOutcome) { outcome in
            FinishSummaryView(outcome: outcome)
        }
        .task {
            controller.resumeInProgressSession(context: context)
        }
    }

    /// Rest length: the split's override wins, then the exercise's own default, then the
    /// global fallback.
    private func startRest(for entry: SessionExercise, in session: Session) {
        let seconds = entry.restOverrideSeconds
            ?? entry.exercise?.defaultRestSeconds
            ?? settings.fallbackRestSeconds
        restTimer.start(
            seconds: seconds,
            exerciseName: entry.displayName,
            sessionTitle: session.title,
            settings: settings
        )
    }

    /// Keeps a minimised session one tap away while the rest of the app stays usable.
    @ViewBuilder
    private var minimisedBar: some View {
        if let session = controller.session, !controller.isPresented {
            Button {
                controller.isPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.title)
                            .font(.subheadline.weight(.semibold))
                        Text("\(session.completedSetCount) sets logged · in progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Resume")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
            .buttonStyle(.plain)
        }
    }
}
