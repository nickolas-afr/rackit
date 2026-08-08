import Foundation
import SwiftData
import Testing
@testable import Rack

/// Records end to end through the persisted model graph, rather than over the pure
/// detector alone.
@Suite("Records through the store")
@MainActor
struct RecordFlowTests {

    private func makeStore() throws -> (ModelContext, AppSettings, Exercise, Split) {
        let context = ModelContext(try ModelStore.makeInMemoryContainer())
        let settings = AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let exercise = Exercise(slug: "bench", name: "Bench Press", primaryMuscle: .chest,
                                equipment: .barbell, mechanic: .compound)
        context.insert(exercise)
        let split = Split(name: "Chest")
        split.items = [SplitItem(order: 0, exercise: exercise, targetSets: 1, targetReps: 5)]
        context.insert(split)
        try context.save()
        return (context, settings, exercise, split)
    }

    /// Logs one set and finishes.
    @discardableResult
    private func logSession(
        weight: Double,
        reps: Int,
        type: SetType = .working,
        controller: SessionController,
        split: Split,
        context: ModelContext,
        settings: AppSettings
    ) throws -> FinishOutcome {
        let session = controller.start(split: split, context: context, settings: settings)
        let row = session.orderedExercises[0].orderedSets[0]
        row.weightKg = weight
        row.reps = reps
        row.setType = type
        controller.toggleCompleted(row, context: context, settings: settings)
        return try controller.finish(context: context, settings: settings)
    }

    @Test("Finishing a first session awards records as first times")
    func firstSessionAwardsRecords() throws {
        let (context, settings, _, split) = try makeStore()
        let outcome = try logSession(weight: 100, reps: 5, controller: SessionController(),
                                     split: split, context: context, settings: settings)

        #expect(outcome.records.count == 4)
        #expect(outcome.records.allSatisfy { $0.isFirstTime })
        #expect(try context.fetch(FetchDescriptor<PersonalRecord>()).count == 4)
    }

    @Test("Repeating a previous best awards no record")
    func tieAwardsNothing() throws {
        let (context, settings, _, split) = try makeStore()
        try logSession(weight: 100, reps: 5, controller: SessionController(),
                       split: split, context: context, settings: settings)
        let second = try logSession(weight: 100, reps: 5, controller: SessionController(),
                                    split: split, context: context, settings: settings)

        #expect(second.records.isEmpty)
        #expect(try context.fetch(FetchDescriptor<PersonalRecord>()).count == 4)
    }

    @Test("Beating a best replaces the stored record rather than accumulating one")
    func recordsAreSuperseded() throws {
        let (context, settings, exercise, split) = try makeStore()
        try logSession(weight: 100, reps: 5, controller: SessionController(),
                       split: split, context: context, settings: settings)
        try logSession(weight: 110, reps: 5, controller: SessionController(),
                       split: split, context: context, settings: settings)

        let stored = RecordService.records(for: exercise)
        #expect(stored[.heaviestWeight]?.value == 110)
        #expect(stored[.heaviestWeight]?.previousValue == 100)
        #expect(try context.fetch(FetchDescriptor<PersonalRecord>()).count == 4)
    }

    @Test("A warm-up sets no record even when it is the heaviest thing lifted")
    func warmupSetsNoRecord() throws {
        let (context, settings, _, split) = try makeStore()
        try logSession(weight: 100, reps: 5, controller: SessionController(),
                       split: split, context: context, settings: settings)
        let warmupOnly = try logSession(weight: 200, reps: 5, type: .warmup,
                                        controller: SessionController(),
                                        split: split, context: context, settings: settings)

        #expect(warmupOnly.records.isEmpty)
    }

    @Test("Deleting a session removes any record that depended on it")
    func deletingSessionRebuildsRecords() throws {
        let (context, settings, exercise, split) = try makeStore()
        try logSession(weight: 100, reps: 5, controller: SessionController(),
                       split: split, context: context, settings: settings)
        let big = try logSession(weight: 140, reps: 5, controller: SessionController(),
                                 split: split, context: context, settings: settings)

        #expect(RecordService.records(for: exercise)[.heaviestWeight]?.value == 140)

        let session = try #require(big.session)
        context.delete(session)
        try context.save()
        try RecordService.rebuildAll(context: context, formula: settings.oneRepMaxFormula)

        // The 140 record cannot outlive the session that produced it.
        #expect(RecordService.records(for: exercise)[.heaviestWeight]?.value == 100)
    }

    @Test("Changing the 1RM formula rebuilds records without touching any session")
    func formulaChangeRebuildsRecordsOnly() throws {
        let (context, settings, exercise, split) = try makeStore()
        try logSession(weight: 100, reps: 10, controller: SessionController(),
                       split: split, context: context, settings: settings)

        let before = RecordService.records(for: exercise)[.bestOneRepMax]?.value
        let setsBefore = try context.fetch(FetchDescriptor<SetEntry>()).map(\.weightKg)

        try RecordService.rebuildAll(context: context, formula: .lombardi)

        let after = RecordService.records(for: exercise)[.bestOneRepMax]?.value
        #expect(before != after)
        #expect(try context.fetch(FetchDescriptor<SetEntry>()).map(\.weightKg) == setsBefore)
        #expect(try context.fetch(FetchDescriptor<Session>()).count == 1)
    }

    @Test("An in-progress session holds no records until it is finished")
    func recordsOnlyOnFinish() throws {
        let (context, settings, _, split) = try makeStore()
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = session.orderedExercises[0].orderedSets[0]
        row.weightKg = 200
        controller.toggleCompleted(row, context: context, settings: settings)

        #expect(try context.fetch(FetchDescriptor<PersonalRecord>()).isEmpty)

        try controller.finish(context: context, settings: settings)
        #expect(try context.fetch(FetchDescriptor<PersonalRecord>()).isEmpty == false)
    }
}
