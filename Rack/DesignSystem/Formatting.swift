import Foundation

nonisolated enum DurationFormatting {
    /// "48m" / "1h 12m" — session lengths, where seconds are noise.
    static func compact(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    /// "1:05" — the rest timer and the elapsed clock, where seconds matter.
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

nonisolated extension RecordKind {
    /// Weight-shaped records read in the display unit; volume-shaped ones as tonnage.
    func format(value: Double, formatter: UnitFormatter) -> String {
        switch self {
        case .heaviestWeight, .bestOneRepMax:
            formatter.string(kg: value)
        case .bestSetVolume, .bestSessionVolume:
            formatter.volumeString(kg: value)
        }
    }
}

nonisolated extension RecordCandidate {
    func formattedValue(_ formatter: UnitFormatter) -> String {
        kind.format(value: value, formatter: formatter)
    }

    /// "First time", or how much this beat the previous mark by.
    func improvementText(_ formatter: UnitFormatter) -> String {
        guard let improvement, let previousValue else { return "First time" }
        let delta = kind.format(value: improvement, formatter: formatter)
        let old = kind.format(value: previousValue, formatter: formatter)
        return "+\(delta) on \(old)"
    }
}

extension PersonalRecord {
    func formattedValue(_ formatter: UnitFormatter) -> String {
        kind.format(value: value, formatter: formatter)
    }

    /// The set behind the mark, where there is one worth showing.
    func contextText(_ formatter: UnitFormatter) -> String? {
        switch kind {
        case .heaviestWeight, .bestOneRepMax:
            guard reps > 0 else { return nil }
            return "\(formatter.string(kg: weightKg, includeUnit: false))×\(reps)"
        case .bestSetVolume:
            guard reps > 0, weightKg > 0 else { return nil }
            return "\(formatter.string(kg: weightKg, includeUnit: false))×\(reps)"
        case .bestSessionVolume:
            return reps > 0 ? "\(reps) reps" : nil
        }
    }
}
