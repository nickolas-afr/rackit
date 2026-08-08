import Foundation

/// One muscle's share of one performed exercise.
nonisolated struct MuscleContribution: Sendable, Equatable {
    var muscle: MuscleGroup
    var date: Date
    /// Secondary movers earn half credit.
    var isPrimary: Bool
    /// Working sets performed (warm-ups already excluded by the caller).
    var sets: Double
    var volumeKg: Double

    var creditedSets: Double { isPrimary ? sets : sets / 2 }
    var creditedVolumeKg: Double { isPrimary ? volumeKg : volumeKg / 2 }
}

nonisolated struct MuscleSummary: Sendable, Equatable {
    var muscle: MuscleGroup
    /// 0...1, normalised against the hardest-hit muscle in the window.
    var load: Double
    var sets: Double
    var volumeKg: Double
    var lastTrained: Date?

    var hasBeenTrained: Bool { lastTrained != nil }

    func daysSinceLastTrained(now: Date = .now) -> Int? {
        guard let lastTrained else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: lastTrained, to: now).day ?? 0)
    }
}

nonisolated enum MuscleLoadCalculator {

    /// A week. Old work fades rather than dropping off a cliff, which is what makes
    /// forty sets of chest three weeks ago read as neglected rather than hot.
    static let halfLifeDays: Double = 7

    static func decayFactor(daysAgo: Double, halfLifeDays: Double = halfLifeDays) -> Double {
        guard halfLifeDays > 0 else { return daysAgo <= 0 ? 1 : 0 }
        return pow(0.5, max(0, daysAgo) / halfLifeDays)
    }

    static func daysBetween(_ date: Date, and now: Date) -> Double {
        max(0, now.timeIntervalSince(date) / 86_400)
    }

    /// Decayed, half-credited, then normalised against the hardest-hit muscle so the
    /// scale is always 0...1 regardless of how hard the user trains.
    static func normalisedLoads(
        contributions: [MuscleContribution],
        now: Date = .now
    ) -> [MuscleGroup: Double] {
        var raw: [MuscleGroup: Double] = [:]
        for contribution in contributions {
            let decay = decayFactor(daysAgo: daysBetween(contribution.date, and: now))
            raw[contribution.muscle, default: 0] += contribution.creditedSets * decay
        }
        guard let peak = raw.values.max(), peak > 0 else {
            return raw.mapValues { _ in 0 }
        }
        return raw.mapValues { $0 / peak }
    }

    /// A row per muscle in the taxonomy, including muscles with no work at all — an
    /// untrained muscle is information and must be listed explicitly, not omitted.
    static func summaries(
        contributions: [MuscleContribution],
        now: Date = .now
    ) -> [MuscleSummary] {
        let loads = normalisedLoads(contributions: contributions, now: now)

        var sets: [MuscleGroup: Double] = [:]
        var volume: [MuscleGroup: Double] = [:]
        var lastTrained: [MuscleGroup: Date] = [:]
        for contribution in contributions {
            sets[contribution.muscle, default: 0] += contribution.creditedSets
            volume[contribution.muscle, default: 0] += contribution.creditedVolumeKg
            let existing = lastTrained[contribution.muscle]
            if existing == nil || contribution.date > existing! {
                lastTrained[contribution.muscle] = contribution.date
            }
        }

        return MuscleGroup.allCases.map { muscle in
            MuscleSummary(
                muscle: muscle,
                load: loads[muscle] ?? 0,
                sets: sets[muscle] ?? 0,
                volumeKg: volume[muscle] ?? 0,
                lastTrained: lastTrained[muscle]
            )
        }
    }

    /// Weekly set counts: primary counts full, secondary counts half. No decay — this
    /// is a straight tally over a window, not a recency measure.
    static func setsPerMuscle(contributions: [MuscleContribution]) -> [MuscleGroup: Double] {
        var totals: [MuscleGroup: Double] = [:]
        for contribution in contributions {
            totals[contribution.muscle, default: 0] += contribution.creditedSets
        }
        return totals
    }

    static func setsPerRegion(contributions: [MuscleContribution]) -> [MuscleRegion: Double] {
        var totals: [MuscleRegion: Double] = [:]
        for contribution in contributions {
            totals[contribution.muscle.region, default: 0] += contribution.creditedSets
        }
        return totals
    }
}
