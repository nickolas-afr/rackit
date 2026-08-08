import Foundation
import SwiftData

/// Derived, never entered. Records are computed when a session is finished and are
/// rebuilt wholesale whenever history changes, so a record can never outlive the
/// session that produced it.
@Model
final class PersonalRecord {
    var kindRaw: String
    /// Value in the record's own unit: kilograms for weight and 1RM, kilogram-reps
    /// for the two volume kinds.
    var value: Double
    /// The mark this beat, for showing the improvement. Nil means "first time".
    var previousValue: Double?
    /// Context for the display line, e.g. "100 kg x 5".
    var weightKg: Double
    var reps: Int
    var achievedAt: Date
    /// Which session and set produced it, so history can mark record-setting sets.
    var sessionUID: UUID?
    var setUID: UUID?

    /// Child end; the cascade is declared on Exercise.
    var exercise: Exercise?

    init(
        kind: RecordKind,
        exercise: Exercise?,
        value: Double,
        previousValue: Double? = nil,
        weightKg: Double = 0,
        reps: Int = 0,
        achievedAt: Date = .now,
        sessionUID: UUID? = nil,
        setUID: UUID? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.exercise = exercise
        self.value = value
        self.previousValue = previousValue
        self.weightKg = weightKg
        self.reps = reps
        self.achievedAt = achievedAt
        self.sessionUID = sessionUID
        self.setUID = setUID
    }
}

extension PersonalRecord {
    var kind: RecordKind {
        get { RecordKind(rawValue: kindRaw) ?? .heaviestWeight }
        set { kindRaw = newValue.rawValue }
    }

    /// How much this beat the previous mark by. Nil when it is the first of its kind.
    var improvement: Double? {
        guard let previousValue else { return nil }
        return value - previousValue
    }

    var isFirstTime: Bool { previousValue == nil }
}

/// A record as detected during a finish, before it is persisted. Kept separate from
/// the model so detection stays a pure function over history.
nonisolated struct RecordCandidate: Sendable, Equatable {
    var kind: RecordKind
    var exerciseSlug: String
    var exerciseName: String
    var value: Double
    var previousValue: Double?
    var weightKg: Double
    var reps: Int
    var achievedAt: Date
    var sessionUID: UUID?
    var setUID: UUID?

    var improvement: Double? {
        guard let previousValue else { return nil }
        return value - previousValue
    }

    var isFirstTime: Bool { previousValue == nil }
}
