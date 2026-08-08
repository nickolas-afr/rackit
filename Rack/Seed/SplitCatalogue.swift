import Foundation

nonisolated struct SeedSplitItem: Sendable {
    let slug: String
    let sets: Int
    let reps: Int

    init(_ slug: String, _ sets: Int, _ reps: Int) {
        self.slug = slug
        self.sets = sets
        self.reps = reps
    }
}

nonisolated struct SeedSplit: Sendable {
    let name: String
    let items: [SeedSplitItem]
}

/// The starting training days. Created whenever no split exists, so an install that
/// already has history still picks them up.
nonisolated enum SplitCatalogue {
    static let all: [SeedSplit] = [
        SeedSplit(name: "Chest", items: [
            SeedSplitItem("barbell-bench-press", 4, 6),
            SeedSplitItem("incline-dumbbell-bench-press", 3, 10),
            SeedSplitItem("chest-dip", 3, 10),
            SeedSplitItem("cable-fly", 3, 12),
            SeedSplitItem("push-up", 2, 15),
        ]),
        SeedSplit(name: "Back", items: [
            SeedSplitItem("deadlift", 3, 5),
            SeedSplitItem("pull-up", 4, 8),
            SeedSplitItem("barbell-row", 3, 8),
            SeedSplitItem("seated-cable-row", 3, 12),
            SeedSplitItem("face-pull", 3, 15),
        ]),
        SeedSplit(name: "Legs", items: [
            SeedSplitItem("back-squat", 4, 5),
            SeedSplitItem("romanian-deadlift", 3, 8),
            SeedSplitItem("leg-press", 3, 12),
            SeedSplitItem("lying-leg-curl", 3, 12),
            SeedSplitItem("standing-calf-raise", 4, 15),
        ]),
        SeedSplit(name: "Shoulders", items: [
            SeedSplitItem("overhead-press", 4, 6),
            SeedSplitItem("seated-dumbbell-shoulder-press", 3, 10),
            SeedSplitItem("lateral-raise", 4, 15),
            SeedSplitItem("rear-delt-fly", 3, 15),
            SeedSplitItem("barbell-shrug", 3, 12),
        ]),
        SeedSplit(name: "Arms", items: [
            SeedSplitItem("barbell-curl", 3, 10),
            SeedSplitItem("close-grip-bench-press", 3, 8),
            SeedSplitItem("hammer-curl", 3, 12),
            SeedSplitItem("rope-pushdown", 3, 12),
            SeedSplitItem("preacher-curl", 3, 12),
        ]),
    ]
}
