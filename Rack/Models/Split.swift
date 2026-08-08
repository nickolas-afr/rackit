import Foundation
import SwiftData

/// One training day — an ordered list of exercises with target sets and reps.
/// Reusable: performing it does not consume it. This is the object the user taps
/// to begin training.
@Model
final class Split {
    var name: String
    var order: Int
    var notes: String
    /// Overrides each exercise's own default rest for this training day.
    var restOverrideSeconds: Int?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SplitItem.split)
    var items: [SplitItem]

    /// Sessions performed under this split. Nullify, declared here on the parent side:
    /// deleting a split must detach its sessions, never delete them.
    @Relationship(deleteRule: .nullify, inverse: \Session.split)
    var sessions: [Session]

    init(
        name: String,
        order: Int = 0,
        notes: String = "",
        restOverrideSeconds: Int? = nil,
        createdAt: Date = .now,
        items: [SplitItem] = []
    ) {
        self.name = name
        self.order = order
        self.notes = notes
        self.restOverrideSeconds = restOverrideSeconds
        self.createdAt = createdAt
        self.items = items
        self.sessions = []
    }
}

extension Split {
    var orderedItems: [SplitItem] { items.sorted { $0.order < $1.order } }

    /// Derived from the most recent finished session rather than stored, so the rotation
    /// is correct from first launch instead of reporting "never trained" for a split
    /// that plainly has history behind it.
    var lastTrainedAt: Date? {
        sessions.compactMap(\.finishedAt).max()
    }

    /// Sorts the rotation. A split never trained goes to the front of the queue.
    var rotationSortKey: Date { lastTrainedAt ?? .distantPast }

    var exerciseCount: Int { items.count }

    var totalTargetSets: Int { items.reduce(0) { $0 + $1.targetSets } }
}

/// One line of a split: an exercise with its target sets and reps.
@Model
final class SplitItem {
    var order: Int
    var targetSets: Int
    var targetReps: Int
    /// Inverses are declared on the parent side (Exercise, Split); these are the plain
    /// child ends of those relationships.
    var exercise: Exercise?
    var split: Split?

    init(order: Int, exercise: Exercise?, targetSets: Int = 3, targetReps: Int = 8) {
        self.order = order
        self.exercise = exercise
        self.targetSets = targetSets
        self.targetReps = targetReps
    }
}
