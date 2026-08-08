import Foundation
import SwiftData

/// Bridges the persisted model graph to the pure record logic.
enum PerformanceMapper {

    /// One `ExercisePerformance` per exercise per finished session.
    ///
    /// Sessions still in progress are skipped: records are awarded on finish, because
    /// until then a set can still be edited or deleted.
    static func performances(from sessions: [Session]) -> [ExercisePerformance] {
        sessions.compactMap { session -> [ExercisePerformance]? in
            guard session.isFinished else { return nil }
            return session.orderedExercises.compactMap { sessionExercise in
                // An exercise deleted from the library leaves its history readable but
                // can no longer own records.
                guard let exercise = sessionExercise.exercise else { return nil }
                let sets = sessionExercise.orderedSets.map {
                    RecordSetInput(
                        uid: $0.uid,
                        weightKg: $0.weightKg,
                        reps: $0.reps,
                        setType: $0.setType,
                        isCompleted: $0.isCompleted
                    )
                }
                guard !sets.isEmpty else { return nil }
                return ExercisePerformance(
                    sessionUID: session.uid,
                    date: session.finishedAt ?? session.startedAt,
                    exerciseSlug: exercise.slug,
                    exerciseName: exercise.name,
                    trackingMode: exercise.trackingMode,
                    bodyWeightKg: session.bodyWeightKg,
                    sets: sets
                )
            }
        }
        .flatMap { $0 }
    }
}

enum RecordService {

    /// The standing bests for one exercise, as stored.
    static func records(for exercise: Exercise) -> [RecordKind: PersonalRecord] {
        var result: [RecordKind: PersonalRecord] = [:]
        for record in exercise.records {
            if let existing = result[record.kind], existing.value >= record.value { continue }
            result[record.kind] = record
        }
        return result
    }

    /// Detects the records a just-finished session set, without persisting them.
    ///
    /// Run on finish rather than while logging, because until the session is finished a
    /// set can still be edited or deleted.
    static func detectRecords(
        for session: Session,
        context: ModelContext,
        formula: OneRepMaxFormula
    ) throws -> [RecordCandidate] {
        let priorSessions = try context.fetch(
            FetchDescriptor<Session>(predicate: #Predicate { $0.finishedAt != nil })
        ).filter { $0.uid != session.uid }

        let priorPerformances = PerformanceMapper.performances(from: priorSessions)
        var bestsBySlug: [String: [RecordKind: BestMark]] = [:]
        for slug in Set(priorPerformances.map(\.exerciseSlug)) {
            let forSlug = priorPerformances.filter { $0.exerciseSlug == slug }
            bestsBySlug[slug] = RecordDetector.bests(across: forSlug, formula: formula)
        }

        return PerformanceMapper.performances(from: [session]).flatMap { performance in
            RecordDetector.detect(
                in: performance,
                priorBests: bestsBySlug[performance.exerciseSlug] ?? [:],
                formula: formula
            )
        }
    }

    /// Rebuilds every record from full history.
    ///
    /// This is what a session deletion and a 1RM formula change both run. It replaces
    /// the record table wholesale and touches no session, so a record can never outlive
    /// the session that produced it.
    @discardableResult
    static func rebuildAll(context: ModelContext, formula: OneRepMaxFormula) throws -> Int {
        let sessions = try context.fetch(
            FetchDescriptor<Session>(predicate: #Predicate { $0.finishedAt != nil })
        )
        let performances = PerformanceMapper.performances(from: sessions)
        let rebuilt = RecordDetector.rebuild(from: performances, formula: formula)

        for existing in try context.fetch(FetchDescriptor<PersonalRecord>()) {
            context.delete(existing)
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let bySlug = Dictionary(uniqueKeysWithValues: exercises.map { ($0.slug, $0) })

        var inserted = 0
        for (slug, byKind) in rebuilt {
            guard let exercise = bySlug[slug] else { continue }
            for (_, candidate) in byKind {
                context.insert(makeRecord(from: candidate, exercise: exercise))
                inserted += 1
            }
        }
        try context.save()
        return inserted
    }

    /// Persists records detected for a just-finished session.
    static func apply(_ candidates: [RecordCandidate], context: ModelContext) throws {
        guard !candidates.isEmpty else { return }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let bySlug = Dictionary(uniqueKeysWithValues: exercises.map { ($0.slug, $0) })

        for candidate in candidates {
            guard let exercise = bySlug[candidate.exerciseSlug] else { continue }
            // A record of this kind is superseded, not accumulated.
            for stale in exercise.records where stale.kind == candidate.kind {
                context.delete(stale)
            }
            context.insert(makeRecord(from: candidate, exercise: exercise))
        }
        try context.save()
    }

    private static func makeRecord(from candidate: RecordCandidate, exercise: Exercise) -> PersonalRecord {
        PersonalRecord(
            kind: candidate.kind,
            exercise: exercise,
            value: candidate.value,
            previousValue: candidate.previousValue,
            weightKg: candidate.weightKg,
            reps: candidate.reps,
            achievedAt: candidate.achievedAt,
            sessionUID: candidate.sessionUID,
            setUID: candidate.setUID
        )
    }
}
