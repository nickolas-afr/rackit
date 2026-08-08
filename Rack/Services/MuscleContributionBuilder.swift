import Foundation

/// Turns finished sessions into the per-muscle contributions the load and set-count
/// maths runs over.
enum MuscleContributionBuilder {

    /// One contribution per muscle per performed exercise. Warm-ups and unchecked rows
    /// are excluded before anything is counted.
    static func contributions(from sessions: [Session], since: Date? = nil) -> [MuscleContribution] {
        var result: [MuscleContribution] = []

        for session in sessions {
            guard let date = session.finishedAt else { continue }
            if let since, date < since { continue }

            for entry in session.orderedExercises {
                guard let exercise = entry.exercise else { continue }
                let scoring = entry.orderedSets.filter {
                    $0.isCompleted && $0.setType.countsTowardVolume
                }
                guard !scoring.isEmpty else { continue }

                let sets = Double(scoring.count)
                let volume = scoring.reduce(0) { $0 + $1.volumeKg(bodyWeightKg: session.bodyWeightKg) }

                result.append(MuscleContribution(
                    muscle: exercise.primaryMuscle,
                    date: date,
                    isPrimary: true,
                    sets: sets,
                    volumeKg: volume
                ))
                for muscle in exercise.secondaryMuscles {
                    result.append(MuscleContribution(
                        muscle: muscle,
                        date: date,
                        isPrimary: false,
                        sets: sets,
                        volumeKg: volume
                    ))
                }
            }
        }
        return result
    }
}
