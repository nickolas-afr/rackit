import Foundation
import SwiftData
import Testing
@testable import Rack

@Suite("Model graph")
struct ModelGraphTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelStore.makeInMemoryContainer()
        return ModelContext(container)
    }

    @Test("An empty store answers every fetch without crashing")
    func emptyStoreIsQueryable() throws {
        let context = try makeContext()
        #expect(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Split>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PersonalRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<BodyWeightEntry>()).isEmpty)
    }

    @Test("Exercise slugs are unique — re-inserting the same slug upserts rather than duplicates")
    func slugIsUnique() throws {
        let context = try makeContext()
        context.insert(Exercise(slug: "bench-press", name: "Bench Press",
                                primaryMuscle: .chest, equipment: .barbell, mechanic: .compound))
        try context.save()
        context.insert(Exercise(slug: "bench-press", name: "Bench Press (dup)",
                                primaryMuscle: .chest, equipment: .barbell, mechanic: .compound))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Exercise>())
        #expect(all.count == 1)
    }

    @Test("Deleting a session removes its exercises and sets")
    func deletingSessionCascades() throws {
        let context = try makeContext()
        let exercise = Exercise(slug: "squat", name: "Squat",
                                primaryMuscle: .quadriceps, equipment: .barbell, mechanic: .compound)
        context.insert(exercise)

        let session = Session(title: "Legs")
        let sessionExercise = SessionExercise(order: 0, exercise: exercise)
        sessionExercise.sets = [
            SetEntry(order: 0, weightKg: 100, reps: 5, isCompleted: true),
            SetEntry(order: 1, weightKg: 100, reps: 5, isCompleted: true),
        ]
        session.exercises = [sessionExercise]
        context.insert(session)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SetEntry>()).count == 2)

        context.delete(session)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SessionExercise>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
        // The exercise itself survives — history deletion must not gut the library.
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    @Test("Deleting a split leaves sessions performed under it intact")
    func deletingSplitPreservesSessions() throws {
        let context = try makeContext()
        let split = Split(name: "Chest")
        context.insert(split)
        let session = Session(title: "Chest", split: split)
        context.insert(session)
        try context.save()

        context.delete(split)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.split == nil)
    }

    @Test("Deleting a split cascades to its items but not to the exercises they point at")
    func deletingSplitCascadesItemsOnly() throws {
        let context = try makeContext()
        let exercise = Exercise(slug: "row", name: "Barbell Row",
                                primaryMuscle: .lats, equipment: .barbell, mechanic: .compound)
        context.insert(exercise)
        let split = Split(name: "Back")
        split.items = [SplitItem(order: 0, exercise: exercise, targetSets: 3, targetReps: 8)]
        context.insert(split)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SplitItem>()).count == 1)

        context.delete(split)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SplitItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    @Test("A session separates checked sets from pre-filled ones that were never performed")
    func completedVersusUncheckedSets() throws {
        let context = try makeContext()
        let exercise = Exercise(slug: "ohp", name: "Overhead Press",
                                primaryMuscle: .anteriorDeltoid, equipment: .barbell, mechanic: .compound)
        context.insert(exercise)

        let sessionExercise = SessionExercise(order: 0, exercise: exercise)
        sessionExercise.sets = [
            SetEntry(order: 0, weightKg: 40, reps: 10, setType: .warmup, isCompleted: true),
            SetEntry(order: 1, weightKg: 60, reps: 5, isCompleted: true),
            SetEntry(order: 2, weightKg: 60, reps: 5, isCompleted: false),
        ]
        let session = Session(title: "Shoulders", exercises: [sessionExercise])
        context.insert(session)
        try context.save()

        #expect(session.completedSetCount == 2)
        #expect(session.uncheckedSets.count == 1)
        // The warm-up is completed but is not working volume.
        #expect(session.workingSetCount == 1)
        #expect(session.totalReps == 5)
    }

    @Test("An in-progress session is persisted immediately so it survives a force-quit")
    func inProgressSessionIsPersisted() throws {
        let container = try ModelStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let session = Session(title: "Arms")
        context.insert(session)
        try context.save()

        // A fresh context over the same store stands in for a relaunch.
        let reopened = ModelContext(container)
        let unfinished = try reopened.fetch(
            FetchDescriptor<Session>(predicate: #Predicate { $0.finishedAt == nil })
        )
        #expect(unfinished.count == 1)
        #expect(unfinished.first?.title == "Arms")
        #expect(unfinished.first?.isFinished == false)
    }
}
