import SwiftUI

/// The rest countdown while resting.
///
/// The label is recomputed from the absolute end date on every tick rather than
/// decremented, so returning to the app after a suspension shows the right number
/// immediately.
struct RestTimerBar: View {
    @Environment(AppSettings.self) private var settings
    let timer: RestTimerController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let now = context.date
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timer.exerciseName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(timer.formattedRemaining(at: now))
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())
                }

                ProgressView(value: timer.progress(at: now))
                    .tint(Color.accentColor)

                HStack(spacing: 8) {
                    adjustButton(-15, label: "−15s")
                    adjustButton(15, label: "+15s")
                    Button("Skip") { timer.skip() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.glassProminent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
            .onChange(of: now) { _, newValue in
                timer.checkCompletion(settings: settings, now: newValue)
            }
        }
    }

    private func adjustButton(_ seconds: Int, label: String) -> some View {
        Button(label) {
            timer.adjust(by: seconds, settings: settings)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.glass)
        .monospacedDigit()
    }
}
