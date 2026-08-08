import Foundation
import SwiftData

/// Seeds the store on launch.
///
/// The three seeds are independent and each carries its own guard, so a store that
/// already has one of them still gets the other two.
enum Seeder {

    struct Report: Sendable, Equatable {
        var exercisesInserted = 0
        var exercisesUpdated = 0
        var splitsCreated = 0
        var sessionsCreated = 0
    }

    @discardableResult
    static func runAll(context: ModelContext, settings: AppSettings) throws -> Report {
        var report = Report()

        let catalogue = try seedExerciseCatalogue(context: context, settings: settings)
        report.exercisesInserted = catalogue.inserted
        report.exercisesUpdated = catalogue.updated

        report.splitsCreated = try seedSplitsIfNeeded(context: context)
        report.sessionsCreated = try seedStartingHistoryIfNeeded(context: context, settings: settings)

        if report.sessionsCreated > 0 {
            try RecordService.rebuildAll(context: context, formula: settings.oneRepMaxFormula)
        }
        return report
    }

    // MARK: 1. Exercise library — versioned, upserted by slug

    /// Upserts the catalogue by stable slug.
    ///
    /// Rest and notes are the two fields a built-in exercise lets the user edit, so an
    /// upsert deliberately leaves them — along with favourites — alone. Retired entries
    /// are never deleted, because logged history must not orphan.
    @discardableResult
    static func seedExerciseCatalogue(
        context: ModelContext,
        settings: AppSettings
    ) throws -> (inserted: Int, updated: Int) {
        let existing = try context.fetch(FetchDescriptor<Exercise>())

        // Re-run when the catalogue has grown, and also when the store is empty even
        // though the version flag says otherwise — a deleted store must re-seed.
        guard existing.isEmpty || settings.seededCatalogueVersion < ExerciseCatalogue.version else {
            return (0, 0)
        }

        var bySlug = Dictionary(existing.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        var inserted = 0
        var updated = 0

        for seed in ExerciseCatalogue.all {
            if let current = bySlug[seed.slug] {
                current.name = seed.name
                current.primaryMuscle = seed.primary
                current.secondaryMuscles = seed.secondary
                current.equipment = seed.equipment
                current.mechanic = seed.mechanic
                current.trackingMode = seed.mode
                current.catalogueVersion = ExerciseCatalogue.version
                updated += 1
            } else {
                let exercise = Exercise(
                    slug: seed.slug,
                    name: seed.name,
                    primaryMuscle: seed.primary,
                    secondaryMuscles: seed.secondary,
                    equipment: seed.equipment,
                    mechanic: seed.mechanic,
                    trackingMode: seed.mode,
                    defaultRestSeconds: seed.rest,
                    catalogueVersion: ExerciseCatalogue.version
                )
                context.insert(exercise)
                bySlug[seed.slug] = exercise
                inserted += 1
            }
        }

        try context.save()
        settings.seededCatalogueVersion = ExerciseCatalogue.version
        return (inserted, updated)
    }

    // MARK: 2. Splits — created whenever none exist

    @discardableResult
    static func seedSplitsIfNeeded(context: ModelContext) throws -> Int {
        guard try context.fetch(FetchDescriptor<Split>()).isEmpty else { return 0 }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let bySlug = Dictionary(exercises.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })

        var created = 0
        for (index, seed) in SplitCatalogue.all.enumerated() {
            let split = Split(name: seed.name, order: index)
            split.items = seed.items.enumerated().compactMap { itemIndex, item in
                guard let exercise = bySlug[item.slug] else { return nil }
                return SplitItem(order: itemIndex, exercise: exercise,
                                 targetSets: item.sets, targetReps: item.reps)
            }
            context.insert(split)
            created += 1
        }

        try context.save()
        return created
    }

    // MARK: 3. Starting history — once, and never on top of real training

    @discardableResult
    static func seedStartingHistoryIfNeeded(
        context: ModelContext,
        settings: AppSettings,
        now: Date = .now
    ) throws -> Int {
        guard !settings.didSeedStartingHistory else { return 0 }

        // Skip entirely if any session exists, so this can never land on top of real
        // training. The flag is still set, so it does not reconsider on every launch.
        guard try context.fetch(FetchDescriptor<Session>()).isEmpty else {
            settings.didSeedStartingHistory = true
            return 0
        }

        let splits = try context.fetch(FetchDescriptor<Split>()).sorted { $0.order < $1.order }
        guard !splits.isEmpty else { return 0 }

        var random = SeededGenerator(seed: 20_260_808)
        let calendar = Calendar.current
        var created = 0

        // 21 sessions, one every other day, rotating through the splits.
        for index in stride(from: 20, through: 0, by: -1) {
            let split = splits[index % splits.count]
            guard let day = calendar.date(byAdding: .day, value: -index * 2, to: now),
                  let startedAt = calendar.date(bySettingHour: 18, minute: 15, second: 0, of: day)
            else { continue }

            let weeksAgo = index / 7
            let session = Session(
                title: split.name,
                startedAt: startedAt,
                finishedAt: startedAt.addingTimeInterval(Double(2_700 + random.next(upTo: 1_500))),
                bodyWeightKg: 80.5 - Double(weeksAgo) * 0.2,
                split: split
            )

            session.exercises = split.orderedItems.enumerated().compactMap { position, item in
                guard let exercise = item.exercise else { return nil }
                return makeSessionExercise(
                    order: position,
                    item: item,
                    exercise: exercise,
                    weeksElapsed: 3 - weeksAgo,
                    random: &random
                )
            }

            context.insert(session)
            created += 1
        }

        // A weigh-in every week, so bodyweight movements have real numbers behind them.
        for week in 0...6 {
            guard let date = calendar.date(byAdding: .day, value: -week * 7, to: now) else { continue }
            context.insert(BodyWeightEntry(date: date, weightKg: 80.5 - Double(week) * 0.2))
        }

        try context.save()
        settings.didSeedStartingHistory = true
        return created
    }

    private static func makeSessionExercise(
        order: Int,
        item: SplitItem,
        exercise: Exercise,
        weeksElapsed: Int,
        random: inout SeededGenerator
    ) -> SessionExercise {
        let sessionExercise = SessionExercise(order: order, exercise: exercise)
        let base = startingLoadKg(for: exercise)
        let step = base >= 40 ? 2.5 : 1.25
        let working = base + Double(max(0, weeksElapsed)) * step

        var sets: [SetEntry] = []
        var setOrder = 0

        // A warm-up on the first compound of the day, so the seeded history exercises
        // the rule that warm-ups are excluded from volume and records.
        if order == 0, exercise.mechanic == .compound, exercise.trackingMode.showsWeightField, working > 20 {
            sets.append(SetEntry(order: setOrder, weightKg: (working * 0.5).roundedToNearest(2.5),
                                 reps: 10, setType: .warmup, isCompleted: true,
                                 completedAt: .now))
            setOrder += 1
        }

        for _ in 0..<item.targetSets {
            let repJitter = Int(random.next(upTo: 3)) - 1
            let reps = max(1, item.targetReps + repJitter)
            let weight: Double = switch exercise.trackingMode {
            case .weightAndReps: working
            case .bodyweightPlusAdded: max(0, working - base)
            case .bodyweightReps, .repsOnly, .timed: 0
            }
            sets.append(SetEntry(order: setOrder, weightKg: weight, reps: reps,
                                 setType: .working, isCompleted: true, completedAt: .now))
            setOrder += 1
        }

        sessionExercise.sets = sets
        return sessionExercise
    }

    /// Plausible starting loads for the movements in the seeded splits. Anything not
    /// listed falls back to a load derived from its equipment.
    private static func startingLoadKg(for exercise: Exercise) -> Double {
        let table: [String: Double] = [
            "barbell-bench-press": 80, "incline-dumbbell-bench-press": 28,
            "chest-dip": 0, "cable-fly": 15, "push-up": 0,
            "deadlift": 120, "pull-up": 0, "barbell-row": 70,
            "seated-cable-row": 60, "face-pull": 25,
            "back-squat": 100, "romanian-deadlift": 90, "leg-press": 160,
            "lying-leg-curl": 45, "standing-calf-raise": 80,
            "overhead-press": 50, "seated-dumbbell-shoulder-press": 22,
            "lateral-raise": 10, "rear-delt-fly": 10, "barbell-shrug": 90,
            "barbell-curl": 35, "close-grip-bench-press": 65, "hammer-curl": 14,
            "rope-pushdown": 30, "preacher-curl": 25,
        ]
        if let known = table[exercise.slug] { return known }

        guard exercise.trackingMode.showsWeightField else { return 0 }
        return switch exercise.equipment {
        case .barbell, .trapBar, .smithMachine: exercise.mechanic == .compound ? 60 : 30
        case .machine, .cable: 40
        case .dumbbell, .kettlebell: 16
        default: 10
        }
    }
}

/// A small deterministic generator, so seeded history is identical on every install
/// rather than differing run to run.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 2_862_933_555_777_941_757 &+ 3_037_000_493 }

    mutating func next(upTo bound: UInt64) -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return bound == 0 ? 0 : (state >> 33) % bound
    }
}

private extension Double {
    func roundedToNearest(_ increment: Double) -> Double {
        guard increment > 0 else { return self }
        return (self / increment).rounded() * increment
    }
}
