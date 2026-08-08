import Foundation
import SwiftData
import Testing
@testable import Rack

@Suite("Seeding")
struct SeedTests {

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelStore.makeInMemoryContainer())
    }

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    // MARK: Catalogue integrity

    @Test("The catalogue holds roughly 170 movements")
    func catalogueSize() {
        #expect(ExerciseCatalogue.all.count >= 160)
        #expect(ExerciseCatalogue.all.count <= 185)
    }

    @Test("Every catalogue slug is unique")
    func slugsAreUnique() {
        let slugs = ExerciseCatalogue.all.map(\.slug)
        #expect(Set(slugs).count == slugs.count)
    }

    @Test("Every catalogue entry has a name and a slug in kebab case")
    func slugsAreWellFormed() {
        for entry in ExerciseCatalogue.all {
            #expect(entry.name.isEmpty == false)
            #expect(entry.slug.isEmpty == false)
            #expect(entry.slug == entry.slug.lowercased())
            #expect(entry.slug.contains(" ") == false)
            #expect(entry.rest > 0)
        }
    }

    @Test("Bodyweight-only movements are not tracked as weight and reps")
    func bodyweightMovementsUseABodyweightMode() {
        for entry in ExerciseCatalogue.all where entry.equipment == .bodyweight {
            #expect(entry.mode != .weightAndReps)
        }
    }

    @Test("Every split-catalogue slug resolves to a real catalogue entry")
    func splitSlugsResolve() {
        let known = Set(ExerciseCatalogue.all.map(\.slug))
        for split in SplitCatalogue.all {
            for item in split.items {
                #expect(known.contains(item.slug), "\(split.name) references unknown slug \(item.slug)")
            }
        }
    }

    // MARK: Exercise library seed

    @Test("Seeding populates the library")
    func seedsLibrary() throws {
        let context = try makeContext()
        let settings = makeSettings()
        let result = try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        #expect(result.inserted == ExerciseCatalogue.all.count)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == ExerciseCatalogue.all.count)
        #expect(settings.seededCatalogueVersion == ExerciseCatalogue.version)
    }

    @Test("Re-seeding the same version is a no-op")
    func reseedSameVersionDoesNothing() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        let second = try Seeder.seedExerciseCatalogue(context: context, settings: settings)
        #expect(second.inserted == 0)
        #expect(second.updated == 0)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == ExerciseCatalogue.all.count)
    }

    @Test("A newer catalogue upserts rather than duplicating")
    func newerCatalogueUpserts() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        // Stand in for a catalogue that has grown since this install seeded.
        settings.seededCatalogueVersion = 0
        let second = try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        #expect(second.inserted == 0)
        #expect(second.updated == ExerciseCatalogue.all.count)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == ExerciseCatalogue.all.count)
    }

    @Test("Re-seeding preserves favourites, notes and edited rest")
    func reseedPreservesUserEdits() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        let bench = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == "barbell-bench-press" })
        ).first)
        bench.isFavourite = true
        bench.notes = "Pause on the chest."
        bench.defaultRestSeconds = 240
        try context.save()

        settings.seededCatalogueVersion = 0
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        let after = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == "barbell-bench-press" })
        ).first)
        #expect(after.isFavourite)
        #expect(after.notes == "Pause on the chest.")
        #expect(after.defaultRestSeconds == 240)
    }

    @Test("Re-seeding does not delete a custom exercise")
    func reseedKeepsCustomExercises() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        context.insert(Exercise(slug: "custom-thing", name: "My Movement",
                                primaryMuscle: .chest, equipment: .other,
                                mechanic: .isolation, isCustom: true))
        try context.save()

        settings.seededCatalogueVersion = 0
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        #expect(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == "custom-thing" })
        ).count == 1)
    }

    @Test("An empty store re-seeds even when the version flag says it already ran")
    func emptyStoreReseeds() throws {
        let context = try makeContext()
        let settings = makeSettings()
        settings.seededCatalogueVersion = ExerciseCatalogue.version

        let result = try Seeder.seedExerciseCatalogue(context: context, settings: settings)
        #expect(result.inserted == ExerciseCatalogue.all.count)
    }

    // MARK: Split seed

    @Test("Splits are created when none exist")
    func seedsSplits() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)

        #expect(try Seeder.seedSplitsIfNeeded(context: context) == SplitCatalogue.all.count)

        let splits = try context.fetch(FetchDescriptor<Split>())
        #expect(splits.count == SplitCatalogue.all.count)
        #expect(splits.allSatisfy { $0.items.isEmpty == false })
    }

    @Test("Splits are not duplicated on a second run")
    func splitsAreNotDuplicated() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)
        try Seeder.seedSplitsIfNeeded(context: context)

        #expect(try Seeder.seedSplitsIfNeeded(context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<Split>()).count == SplitCatalogue.all.count)
    }

    @Test("An install that already has history still picks up splits")
    func splitsSeedEvenWithExistingHistory() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)
        context.insert(Session(title: "Old session", finishedAt: .now))
        try context.save()

        #expect(try Seeder.seedSplitsIfNeeded(context: context) == SplitCatalogue.all.count)
    }

    // MARK: Starting history seed

    @Test("Starting history is generated on a fresh store")
    func seedsStartingHistory() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)
        try Seeder.seedSplitsIfNeeded(context: context)

        let created = try Seeder.seedStartingHistoryIfNeeded(context: context, settings: settings)
        #expect(created > 0)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == created)
        #expect(sessions.allSatisfy { $0.isFinished })
        #expect(sessions.allSatisfy { $0.completedSetCount > 0 })
        #expect(sessions.allSatisfy { $0.volumeKg > 0 })
    }

    @Test("Starting history never lands on top of real training")
    func startingHistorySkipsWhenSessionsExist() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)
        try Seeder.seedSplitsIfNeeded(context: context)

        context.insert(Session(title: "A real session", finishedAt: .now))
        try context.save()

        #expect(try Seeder.seedStartingHistoryIfNeeded(context: context, settings: settings) == 0)
        #expect(try context.fetch(FetchDescriptor<Session>()).count == 1)
        #expect(settings.didSeedStartingHistory)
    }

    @Test("Starting history runs only once")
    func startingHistoryRunsOnce() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.seedExerciseCatalogue(context: context, settings: settings)
        try Seeder.seedSplitsIfNeeded(context: context)

        let first = try Seeder.seedStartingHistoryIfNeeded(context: context, settings: settings)
        let second = try Seeder.seedStartingHistoryIfNeeded(context: context, settings: settings)
        #expect(first > 0)
        #expect(second == 0)
        #expect(try context.fetch(FetchDescriptor<Session>()).count == first)
    }

    @Test("Seeded history includes warm-ups that contribute no volume")
    func seededHistoryExercisesTheWarmupRule() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.runAll(context: context, settings: settings)

        let sets = try context.fetch(FetchDescriptor<SetEntry>())
        let warmups = sets.filter { $0.setType == .warmup }
        #expect(warmups.isEmpty == false)
        #expect(warmups.allSatisfy { $0.volumeKg(bodyWeightKg: 80) == 0 })
    }

    // MARK: Rotation and records

    @Test("Each split is dated from its most recent session, not left as never trained")
    func splitsAreDatedFromHistory() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.runAll(context: context, settings: settings)

        let splits = try context.fetch(FetchDescriptor<Split>())
        #expect(splits.allSatisfy { $0.lastTrainedAt != nil })
    }

    @Test("Seeding produces records from the generated history")
    func seedingBuildsRecords() throws {
        let context = try makeContext()
        let settings = makeSettings()
        try Seeder.runAll(context: context, settings: settings)

        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        #expect(records.isEmpty == false)
        #expect(records.allSatisfy { $0.value > 0 })
        #expect(records.allSatisfy { $0.exercise != nil })
    }

    @Test("A full seed run leaves a coherent store")
    func fullSeedRun() throws {
        let context = try makeContext()
        let settings = makeSettings()
        let report = try Seeder.runAll(context: context, settings: settings)

        #expect(report.exercisesInserted == ExerciseCatalogue.all.count)
        #expect(report.splitsCreated == SplitCatalogue.all.count)
        #expect(report.sessionsCreated > 0)

        // A second full run changes nothing.
        let again = try Seeder.runAll(context: context, settings: settings)
        #expect(again == Seeder.Report())
    }
}
