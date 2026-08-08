import ActivityKit
import SwiftUI
import WidgetKit

/// The rest timer on the lock screen and in the Dynamic Island.
///
/// Every countdown here is a `Text(timerInterval:)` over the absolute end date. The
/// system ticks those itself, which is why the remaining time stays right with the
/// screen locked and the app suspended — nothing has to push an update.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context, font: .title2.weight(.semibold))
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                        ProgressView(
                            timerInterval: context.state.startDate...context.state.endDate,
                            countsDown: true,
                            label: { EmptyView() },
                            currentValueLabel: { EmptyView() }
                        )
                        .tint(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context, font: .caption2.weight(.semibold))
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func lockScreenView(_ context: ActivityViewContext<RestActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Rest", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(context.attributes.sessionTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(context.attributes.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                countdown(context, font: .title.weight(.semibold))
                    .frame(maxWidth: 120, alignment: .trailing)
            }

            ProgressView(
                timerInterval: context.state.startDate...context.state.endDate,
                countsDown: true,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .tint(.orange)
        }
        .padding()
    }

    private func countdown(
        _ context: ActivityViewContext<RestActivityAttributes>,
        font: Font
    ) -> some View {
        Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
            .font(font.monospacedDigit())
            .multilineTextAlignment(.trailing)
    }
}
