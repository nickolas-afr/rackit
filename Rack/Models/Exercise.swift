import Foundation
import SwiftData

/// A movement. Built-in exercises arrive from the seeded catalogue and are matched
/// on `slug`, which is why re-seeding can add movements without duplicating rows or
/// discarding the user's favourites, notes and custom entries.
@Model
final class Exercise {
    /// Stable identifier used to upsert the catalogue. Never changes for a given movement.
    @Attribute(.unique) var slug: String
    var name: String
    var primaryMuscleRaw: String
    var secondaryMusclesRaw: [String]
    var equipmentRaw: String
    var mechanicRaw: String
    var trackingModeRaw: String
    var defaultRestSeconds: Int
    var notes: String
    var isFavourite: Bool
    /// User-created exercises are fully editable; built-ins are restricted to rest and notes
    /// so that re-seeding cannot overwrite user edits.
    var isCustom: Bool
    /// Retired catalogue entries are hidden from search but never deleted, so logged
    /// history cannot orphan.
    var isRetired: Bool
    var catalogueVersion: Int
    var createdAt: Date

    /// Split lines pointing at this movement. Nullify: deleting an exercise must not
    /// silently gut a split — the orphaned line is filtered out instead.
    @Relationship(deleteRule: .nullify, inverse: \SplitItem.exercise)
    var splitItems: [SplitItem]

    /// Sessions in which this movement was performed. Nullify: deleting a custom
    /// exercise preserves the history of having performed it (the name is snapshotted).
    @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
    var sessionEntries: [SessionExercise]

    /// Records are derived from this exercise and mean nothing without it, so they go
    /// with it.
    @Relationship(deleteRule: .cascade, inverse: \PersonalRecord.exercise)
    var records: [PersonalRecord]

    init(
        slug: String,
        name: String,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        equipment: Equipment,
        mechanic: Mechanic,
        trackingMode: TrackingMode = .weightAndReps,
        defaultRestSeconds: Int = 120,
        notes: String = "",
        isFavourite: Bool = false,
        isCustom: Bool = false,
        isRetired: Bool = false,
        catalogueVersion: Int = 0,
        createdAt: Date = .now
    ) {
        self.slug = slug
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMusclesRaw = secondaryMuscles.map(\.rawValue)
        self.equipmentRaw = equipment.rawValue
        self.mechanicRaw = mechanic.rawValue
        self.trackingModeRaw = trackingMode.rawValue
        self.defaultRestSeconds = defaultRestSeconds
        self.notes = notes
        self.isFavourite = isFavourite
        self.isCustom = isCustom
        self.isRetired = isRetired
        self.catalogueVersion = catalogueVersion
        self.createdAt = createdAt
        self.splitItems = []
        self.sessionEntries = []
        self.records = []
    }
}

// Enums are persisted as raw strings rather than as Codable enum properties: a raw
// string cannot fail to decode if a case is ever renamed, so old rows stay readable.
extension Exercise {
    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .chest }
        set { primaryMuscleRaw = newValue.rawValue }
    }

    var secondaryMuscles: [MuscleGroup] {
        get { secondaryMusclesRaw.compactMap { MuscleGroup(rawValue: $0) } }
        set { secondaryMusclesRaw = newValue.map(\.rawValue) }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }

    var mechanic: Mechanic {
        get { Mechanic(rawValue: mechanicRaw) ?? .compound }
        set { mechanicRaw = newValue.rawValue }
    }

    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRaw) ?? .weightAndReps }
        set { trackingModeRaw = newValue.rawValue }
    }

    /// Every muscle the movement touches, primary first.
    var allMuscles: [MuscleGroup] { [primaryMuscle] + secondaryMuscles }

    var usesPlateCalculator: Bool { equipment.usesLoadableBar }

    /// Free-text haystack for the library search field.
    var searchHaystack: String {
        ([name, primaryMuscle.displayName, equipment.displayName, mechanic.displayName]
            + secondaryMuscles.map(\.displayName))
            .joined(separator: " ")
            .lowercased()
    }
}
