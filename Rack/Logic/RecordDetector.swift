import Foundation

nonisolated struct RecordSetInput: Sendable, Equatable {
    var uid: UUID
    var weightKg: Double
    var reps: Int
    var setType: SetType
    var isCompleted: Bool

    init(
        uid: UUID = UUID(),
        weightKg: Double,
        reps: Int,
        setType: SetType = .working,
        isCompleted: Bool = true
    ) {
        self.uid = uid
        self.weightKg = weightKg
        self.reps = reps
        self.setType = setType
        self.isCompleted = isCompleted
    }
}

/// One exercise as performed in one session — the unit records are computed over.
nonisolated struct ExercisePerformance: Sendable, Equatable {
    var sessionUID: UUID
    var date: Date
    var exerciseSlug: String
    var exerciseName: String
    var trackingMode: TrackingMode
    var bodyWeightKg: Double?
    var sets: [RecordSetInput]

    init(
        sessionUID: UUID = UUID(),
        date: Date,
        exerciseSlug: String,
        exerciseName: String = "",
        trackingMode: TrackingMode = .weightAndReps,
        bodyWeightKg: Double? = nil,
        sets: [RecordSetInput]
    ) {
        self.sessionUID = sessionUID
        self.date = date
        self.exerciseSlug = exerciseSlug
        self.exerciseName = exerciseName
        self.trackingMode = trackingMode
        self.bodyWeightKg = bodyWeightKg
        self.sets = sets
    }

    /// Warm-ups and unchecked rows can never set a record.
    var eligibleSets: [RecordSetInput] {
        sets.filter { $0.isCompleted && $0.setType.canSetRecord }
    }
}

nonisolated struct BestMark: Sendable, Equatable {
    var value: Double
    var weightKg: Double
    var reps: Int
    var date: Date
    var sessionUID: UUID?
    var setUID: UUID?
}

nonisolated enum RecordDetector {

    /// The best of each kind achieved within a single performance.
    static func marks(
        for performance: ExercisePerformance,
        formula: OneRepMaxFormula
    ) -> [RecordKind: BestMark] {
        let sets = performance.eligibleSets
        guard !sets.isEmpty else { return [:] }

        let mode = performance.trackingMode
        var result: [RecordKind: BestMark] = [:]

        func consider(_ kind: RecordKind, _ mark: BestMark) {
            guard mark.value > 0 else { return }
            if let existing = result[kind], existing.value >= mark.value { return }
            result[kind] = mark
        }

        for set in sets {
            if mode.showsWeightField {
                consider(.heaviestWeight, BestMark(
                    value: set.weightKg,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    date: performance.date,
                    sessionUID: performance.sessionUID,
                    setUID: set.uid
                ))
            }

            if mode.supportsOneRepMax {
                let estimate = OneRepMax.estimate(weight: set.weightKg, reps: set.reps, formula: formula)
                consider(.bestOneRepMax, BestMark(
                    value: estimate,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    date: performance.date,
                    sessionUID: performance.sessionUID,
                    setUID: set.uid
                ))
            }

            let setVolume = VolumeCalculator.volume(
                for: SetSnapshot(
                    weightKg: set.weightKg,
                    reps: set.reps,
                    setType: set.setType,
                    trackingMode: mode,
                    isCompleted: true
                ),
                bodyWeightKg: performance.bodyWeightKg
            )
            consider(.bestSetVolume, BestMark(
                value: setVolume,
                weightKg: set.weightKg,
                reps: set.reps,
                date: performance.date,
                sessionUID: performance.sessionUID,
                setUID: set.uid
            ))
        }

        let sessionVolume = VolumeCalculator.volume(
            for: sets.map {
                SetSnapshot(
                    weightKg: $0.weightKg,
                    reps: $0.reps,
                    setType: $0.setType,
                    trackingMode: mode,
                    isCompleted: true
                )
            },
            bodyWeightKg: performance.bodyWeightKg
        )
        consider(.bestSessionVolume, BestMark(
            value: sessionVolume,
            weightKg: 0,
            reps: sets.reduce(0) { $0 + $1.reps },
            date: performance.date,
            sessionUID: performance.sessionUID,
            setUID: nil
        ))

        return result
    }

    /// The standing bests across a set of performances.
    static func bests(
        across performances: [ExercisePerformance],
        formula: OneRepMaxFormula
    ) -> [RecordKind: BestMark] {
        var result: [RecordKind: BestMark] = [:]
        for performance in performances {
            for (kind, mark) in marks(for: performance, formula: formula) {
                if let existing = result[kind], existing.value >= mark.value { continue }
                result[kind] = mark
            }
        }
        return result
    }

    /// Records set by `performance`, given what stood before it.
    ///
    /// The comparison is strictly greater than. Equalling a previous best is not a
    /// record — repeating a number is not progress, and celebrating it devalues the badge.
    static func detect(
        in performance: ExercisePerformance,
        priorBests: [RecordKind: BestMark],
        formula: OneRepMaxFormula
    ) -> [RecordCandidate] {
        let candidates = marks(for: performance, formula: formula)

        return RecordKind.allCases.compactMap { kind -> RecordCandidate? in
            guard let mark = candidates[kind], mark.value > 0 else { return nil }
            let previous = priorBests[kind]
            if let previous, mark.value <= previous.value { return nil }

            return RecordCandidate(
                kind: kind,
                exerciseSlug: performance.exerciseSlug,
                exerciseName: performance.exerciseName,
                value: mark.value,
                previousValue: previous?.value,
                weightKg: mark.weightKg,
                reps: mark.reps,
                achievedAt: performance.date,
                sessionUID: performance.sessionUID,
                setUID: mark.setUID
            )
        }
    }

    /// Rebuilds every record from full history, replaying performances oldest-first so
    /// each record carries the date and set that actually established it.
    ///
    /// This is what a session deletion and a formula change both run, and it is why a
    /// record can never outlive the session that produced it.
    static func rebuild(
        from performances: [ExercisePerformance],
        formula: OneRepMaxFormula
    ) -> [String: [RecordKind: RecordCandidate]] {
        var bySlug: [String: [RecordKind: RecordCandidate]] = [:]
        var standing: [String: [RecordKind: BestMark]] = [:]

        for performance in performances.sorted(by: { $0.date < $1.date }) {
            let slug = performance.exerciseSlug
            let prior = standing[slug] ?? [:]
            let newRecords = detect(in: performance, priorBests: prior, formula: formula)

            var updated = prior
            for record in newRecords {
                bySlug[slug, default: [:]][record.kind] = record
                updated[record.kind] = BestMark(
                    value: record.value,
                    weightKg: record.weightKg,
                    reps: record.reps,
                    date: record.achievedAt,
                    sessionUID: record.sessionUID,
                    setUID: record.setUID
                )
            }
            standing[slug] = updated
        }

        return bySlug
    }
}
