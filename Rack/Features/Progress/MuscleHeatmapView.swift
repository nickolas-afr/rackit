import SwiftData
import SwiftUI

struct MuscleHeatmapView: View {
    @Environment(AppSettings.self) private var settings

    @Query(
        filter: #Predicate<Session> { $0.finishedAt != nil },
        sort: [SortDescriptor(\Session.finishedAt, order: .reverse)]
    )
    private var sessions: [Session]

    @State private var windowDays = 7
    @State private var selected: MuscleGroup?

    private var formatter: UnitFormatter { settings.unitFormatter }

    private var summaries: [MuscleSummary] {
        let since = Calendar.current.date(byAdding: .day, value: -windowDays, to: .now)
        let contributions = MuscleContributionBuilder.contributions(from: sessions, since: since)
        return MuscleLoadCalculator.summaries(contributions: contributions)
    }

    private var byMuscle: [MuscleGroup: MuscleSummary] {
        Dictionary(uniqueKeysWithValues: summaries.map { ($0.muscle, $0) })
    }

    private var untrained: [MuscleSummary] {
        summaries.filter { $0.sets == 0 }.sorted { $0.muscle.displayName < $1.muscle.displayName }
    }

    var body: some View {
        List {
            Section {
                Picker("Window", selection: $windowDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
            }

            Section {
                HStack(spacing: 8) {
                    ForEach(BodySide.allCases) { side in
                        VStack(spacing: 6) {
                            BodyDiagramView(
                                side: side,
                                loads: byMuscle.mapValues(\.load),
                                selected: selected,
                                onTap: { selected = ($0 == selected) ? nil : $0 }
                            )
                            Text(side.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)

                scale
            }

            if let selected, let summary = byMuscle[selected] {
                Section(selected.displayName) {
                    LabeledContent("Sets", value: setsText(summary.sets))
                    LabeledContent("Volume", value: formatter.volumeString(kg: summary.volumeKg))
                    LabeledContent("Last trained", value: lastTrainedText(summary))
                }
            } else {
                Section {
                    Text("Tap a muscle to see its sets, volume and how long since it was trained.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // An untrained muscle is information, so it is listed rather than omitted.
            Section {
                if untrained.isEmpty {
                    Text("Everything has had work in the last \(windowDays) days.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(untrained, id: \.muscle) { summary in
                        HStack {
                            Text(summary.muscle.displayName)
                            Spacer()
                            Text(lastTrainedText(summary))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Not trained in this window")
            }
        }
        .navigationTitle("Muscle heatmap")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scale: some View {
        VStack(alignment: .leading, spacing: 4) {
            LinearGradient(
                colors: stride(from: 0.0, through: 1.0, by: 0.1).map { HeatRamp.colour(for: $0) },
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(.capsule)

            HStack {
                Text("Untrained").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Hardest hit").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func setsText(_ sets: Double) -> String {
        sets == sets.rounded() ? "\(Int(sets))" : String(format: "%.1f", sets)
    }

    private func lastTrainedText(_ summary: MuscleSummary) -> String {
        guard let days = summary.daysSinceLastTrained() else { return "never" }
        return switch days {
        case 0: "today"
        case 1: "yesterday"
        default: "\(days) days ago"
        }
    }
}

/// The colour ramp.
///
/// The cold end is a desaturated blue, deliberately far from the app's orange accent:
/// a warm cold-end would make the least-trained muscles read as the most emphasised
/// thing on the screen, which is exactly backwards.
nonisolated enum HeatRamp {
    static func colour(for load: Double) -> Color {
        let t = min(1, max(0, load))
        let hue = 0.58 - 0.55 * t          // blue -> orange/red
        let saturation = 0.22 + 0.65 * t
        let brightness = 0.55 + 0.35 * t
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

/// One body diagram, drawn from vector shapes.
struct BodyDiagramView: View {
    let side: BodySide
    let loads: [MuscleGroup: Double]
    let selected: MuscleGroup?
    let onTap: (MuscleGroup) -> Void

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / BodyDiagram.designSize.width,
                proxy.size.height / BodyDiagram.designSize.height
            )
            let offsetX = (proxy.size.width - BodyDiagram.designSize.width * scale) / 2

            ZStack(alignment: .topLeading) {
                ForEach(Array(BodyDiagram.outlineRects(for: side).enumerated()), id: \.offset) { _, rect in
                    RoundedRectangle(cornerRadius: 4 * scale)
                        .fill(Color.secondary.opacity(0.16))
                        .frame(width: rect.width * scale, height: rect.height * scale)
                        .offset(x: rect.minX * scale + offsetX, y: rect.minY * scale)
                }

                ForEach(BodyDiagram.shapes(for: side)) { shape in
                    let load = loads[shape.muscle] ?? 0
                    region(shape, scale: scale, offsetX: offsetX, load: load)
                }
            }
        }
        .aspectRatio(BodyDiagram.designSize.width / BodyDiagram.designSize.height, contentMode: .fit)
        .frame(maxHeight: 320)
    }

    @ViewBuilder
    private func region(
        _ shape: MuscleRegionShape,
        scale: CGFloat,
        offsetX: CGFloat,
        load: Double
    ) -> some View {
        let isSelected = shape.muscle == selected
        let fill = HeatRamp.colour(for: load)

        Group {
            if shape.isEllipse {
                Ellipse().fill(fill)
                    .overlay(Ellipse().stroke(Color.primary.opacity(isSelected ? 0.9 : 0.12),
                                              lineWidth: isSelected ? 2 : 0.5))
            } else {
                RoundedRectangle(cornerRadius: max(1, shape.cornerRadius * scale)).fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: max(1, shape.cornerRadius * scale))
                            .stroke(Color.primary.opacity(isSelected ? 0.9 : 0.12),
                                    lineWidth: isSelected ? 2 : 0.5)
                    )
            }
        }
        .frame(width: shape.rect.width * scale, height: shape.rect.height * scale)
        .offset(x: shape.rect.minX * scale + offsetX, y: shape.rect.minY * scale)
        .onTapGesture { onTap(shape.muscle) }
        .accessibilityLabel(shape.muscle.displayName)
        .accessibilityValue("\(Int((load * 100).rounded())) percent of the hardest-hit muscle")
    }
}
