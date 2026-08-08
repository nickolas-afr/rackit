import Foundation
import SwiftData

/// The record of having trained. Never created directly by the user — it is produced
/// by starting a split, and appears in history once finished.
///
/// A session is persisted the moment it starts, with `finishedAt` nil, which is what
/// lets an in-progress session survive a force-quit and be offered for resume.
@Model
final class Session {
    var uid: UUID
    var title: String
    var startedAt: Date
    var finishedAt: Date?
    var notes: String
    /// The body weight in effect when this session was trained, captured at start so
    /// that later weigh-ins never retroactively rewrite historic bodyweight volume.
    var bodyWeightKg: Double?
    /// Child end; the nullify rule is declared on Split, so deleting a split never
    /// affects sessions performed under it.
    var split: Split?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]

    init(
        uid: UUID = UUID(),
        title: String,
        startedAt: Date = .now,
        finishedAt: Date? = nil,
        notes: String = "",
        bodyWeightKg: Double? = nil,
        split: Split? = nil,
        exercises: [SessionExercise] = []
    ) {
        self.uid = uid
        self.title = title
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.notes = notes
        self.bodyWeightKg = bodyWeightKg
        self.split = split
        self.exercises = exercises
    }
}

extension Session {
    var isFinished: Bool { finishedAt != nil }

    var orderedExercises: [SessionExercise] { exercises.sorted { $0.order < $1.order } }

    var duration: TimeInterval { (finishedAt ?? .now).timeIntervalSince(startedAt) }

    /// Every set the user actually checked off, in order.
    var completedSets: [SetEntry] {
        orderedExercises.flatMap { $0.orderedSets.filter(\.isCompleted) }
    }

    /// Sets that were pre-filled but never performed. These are dropped on finish.
    var uncheckedSets: [SetEntry] {
        orderedExercises.flatMap { $0.orderedSets.filter { !$0.isCompleted } }
    }

    var completedSetCount: Int { completedSets.count }

    /// Warm-ups are excluded — they are not the work.
    var workingSetCount: Int { completedSets.filter { $0.setType.countsTowardVolume }.count }

    var totalReps: Int {
        completedSets.filter { $0.setType.countsTowardVolume }.reduce(0) { $0 + $1.reps }
    }
}

/// One exercise as performed within a session, with its own set list.
@Model
final class SessionExercise {
    var order: Int
    /// Child end; the nullify rule is declared on Exercise.
    var exercise: Exercise?
    /// Snapshot of the name so history stays readable even if the exercise is deleted.
    var exerciseNameSnapshot: String
    var restOverrideSeconds: Int?
    var session: Session?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    var sets: [SetEntry]

    init(
        order: Int,
        exercise: Exercise?,
        exerciseNameSnapshot: String? = nil,
        restOverrideSeconds: Int? = nil,
        sets: [SetEntry] = []
    ) {
        self.order = order
        self.exercise = exercise
        self.exerciseNameSnapshot = exerciseNameSnapshot ?? exercise?.name ?? "Exercise"
        self.restOverrideSeconds = restOverrideSeconds
        self.sets = sets
    }
}

extension SessionExercise {
    var orderedSets: [SetEntry] { sets.sorted { $0.order < $1.order } }

    var displayName: String { exercise?.name ?? exerciseNameSnapshot }

    var trackingMode: TrackingMode { exercise?.trackingMode ?? .weightAndReps }

    var completedSets: [SetEntry] { orderedSets.filter(\.isCompleted) }

    var hasCompletedSets: Bool { sets.contains(where: \.isCompleted) }

    /// Rest to use after a set here: the split's override wins, then the exercise default.
    var effectiveRestSeconds: Int {
        restOverrideSeconds ?? exercise?.defaultRestSeconds ?? 120
    }
}

/// One entry in a session: weight, reps, set type.
@Model
final class SetEntry {
    var uid: UUID
    var order: Int
    /// Always kilograms. Display conversion happens at the edge so switching units
    /// never introduces rounding drift into stored data.
    var weightKg: Double
    var reps: Int
    var durationSeconds: Int
    var setTypeRaw: String
    var isCompleted: Bool
    var completedAt: Date?
    var sessionExercise: SessionExercise?

    init(
        uid: UUID = UUID(),
        order: Int,
        weightKg: Double = 0,
        reps: Int = 0,
        durationSeconds: Int = 0,
        setType: SetType = .working,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.uid = uid
        self.order = order
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.setTypeRaw = setType.rawValue
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

extension SetEntry {
    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }

    var trackingMode: TrackingMode { sessionExercise?.trackingMode ?? .weightAndReps }

    var session: Session? { sessionExercise?.session }
}
