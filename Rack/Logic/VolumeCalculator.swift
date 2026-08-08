import Foundation

/// A set reduced to the fields volume depends on, so the rules can be tested without
/// standing up a persistent store.
nonisolated struct SetSnapshot: Sendable, Equatable {
    var weightKg: Double
    var reps: Int
    var setType: SetType
    var trackingMode: TrackingMode
    var isCompleted: Bool

    init(
        weightKg: Double = 0,
        reps: Int = 0,
        setType: SetType = .working,
        trackingMode: TrackingMode = .weightAndReps,
        isCompleted: Bool = true
    ) {
        self.weightKg = weightKg
        self.reps = reps
        self.setType = setType
        self.trackingMode = trackingMode
        self.isCompleted = isCompleted
    }
}

nonisolated enum VolumeCalculator {

    /// Used when a bodyweight movement is logged and no weigh-in is on record.
    /// Counting those sets as zero would report a session of pull-ups as no work at all.
    static let assumedBodyWeightKg: Double = 75

    static func effectiveBodyWeight(_ recorded: Double?) -> Double {
        guard let recorded, recorded > 0 else { return assumedBodyWeightKg }
        return recorded
    }

    /// Volume for a single set, in kilogram-reps.
    ///
    /// Returns zero for anything not performed, for warm-ups, and for modes that move
    /// no load at all.
    static func volume(for set: SetSnapshot, bodyWeightKg: Double?) -> Double {
        guard set.isCompleted else { return 0 }
        guard set.setType.countsTowardVolume else { return 0 }
        guard set.trackingMode.producesVolume else { return 0 }
        guard set.reps > 0 else { return 0 }

        let bodyWeight = effectiveBodyWeight(bodyWeightKg)
        let load: Double = switch set.trackingMode {
        case .weightAndReps: set.weightKg
        case .bodyweightReps: bodyWeight
        case .bodyweightPlusAdded: bodyWeight + set.weightKg
        case .repsOnly, .timed: 0
        }
        guard load > 0 else { return 0 }
        return load * Double(set.reps)
    }

    static func volume(for sets: [SetSnapshot], bodyWeightKg: Double?) -> Double {
        sets.reduce(0) { $0 + volume(for: $1, bodyWeightKg: bodyWeightKg) }
    }
}

// MARK: - Model conveniences

extension SetEntry {
    var snapshot: SetSnapshot {
        SetSnapshot(
            weightKg: weightKg,
            reps: reps,
            setType: setType,
            trackingMode: trackingMode,
            isCompleted: isCompleted
        )
    }

    func volumeKg(bodyWeightKg: Double?) -> Double {
        VolumeCalculator.volume(for: snapshot, bodyWeightKg: bodyWeightKg)
    }
}

extension SessionExercise {
    var volumeKg: Double {
        VolumeCalculator.volume(for: orderedSets.map(\.snapshot), bodyWeightKg: session?.bodyWeightKg)
    }
}

extension Session {
    var volumeKg: Double {
        orderedExercises.reduce(0) { $0 + $1.volumeKg }
    }
}
