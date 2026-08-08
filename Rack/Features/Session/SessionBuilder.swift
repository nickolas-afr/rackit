import Foundation
import SwiftData

/// What an exercise looked like the last time it was performed. Shown beside each row
/// as reference text, and used to pre-fill.
nonisolated struct LastSetReference: Sendable, Equatable {
    var weightKg: Double
    var reps: Int
    var durationSeconds: Int
    var setType: SetType
}

/// Builds the set rows a session opens with.
enum SessionBuilder {

    /// The most recent finished session containing `exercise`.
    static func lastPerformance(
        of exercise: Exercise,
        excluding excludedSessionUID: UUID? = nil,
        context: ModelContext
    ) -> SessionExercise? {
        let slug = exercise.slug
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { entry in
                entry.exercise?.slug == slug && entry.session?.finishedAt != nil
            }
        )
        guard let entries = try? context.fetch(descriptor) else { return nil }
        return entries
            .filter { $0.session?.uid != excludedSessionUID }
            .filter { $0.sets.isEmpty == false }
            .max { lhs, rhs in
                (lhs.session?.finishedAt ?? .distantPast) < (rhs.session?.finishedAt ?? .distantPast)
            }
    }

    static func reference(from performance: SessionExercise?) -> [LastSetReference] {
        guard let performance else { return [] }
        return performance.orderedSets.map {
            LastSetReference(
                weightKg: $0.weightKg,
                reps: $0.reps,
                durationSeconds: $0.durationSeconds,
                setType: $0.setType
            )
        }
    }

    /// Pre-fills the rows for one exercise.
    ///
    /// With history, the rows mirror the last session exactly — same count, same loads,
    /// same set types — so "same as last time" costs one tap per row and nothing else.
    /// Reproducing the shape matters as much as the numbers: someone who always opens
    /// with a warm-up gets that warm-up back rather than having to add it.
    ///
    /// Without history, the split's targets supply the row count and reps, at zero load.
    static func makeSessionExercise(
        order: Int,
        exercise: Exercise,
        targetSets: Int,
        targetReps: Int,
        restOverrideSeconds: Int?,
        reference: [LastSetReference]
    ) -> SessionExercise {
        let sessionExercise = SessionExercise(
            order: order,
            exercise: exercise,
            restOverrideSeconds: restOverrideSeconds
        )

        if reference.isEmpty {
            sessionExercise.sets = (0..<max(1, targetSets)).map { index in
                SetEntry(order: index, weightKg: 0, reps: targetReps, setType: .working)
            }
        } else {
            sessionExercise.sets = reference.enumerated().map { index, last in
                SetEntry(
                    order: index,
                    weightKg: last.weightKg,
                    reps: last.reps,
                    durationSeconds: last.durationSeconds,
                    setType: last.setType
                )
            }
        }
        return sessionExercise
    }
}
