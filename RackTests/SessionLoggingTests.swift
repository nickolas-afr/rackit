import Foundation
import SwiftData
import Testing
@testable import Rack

@Suite("Session logging")
@MainActor
struct SessionLoggingTests {

    private func makeStore() throws -> (ModelContext, AppSettings) {
        let context = ModelContext(try ModelStore.makeInMemoryContainer())
        let settings = AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        return (context, settings)
    }

    /// A library with one barbell movement and a split that programmes 3 x 8 of it.
    private func makeBenchSplit(context: ModelContext) -> (Exercise, Split) {
        let exercise = Exercise(slug: "bench", name: "Bench Press",
                                primaryMuscle: .chest, equipment: .barbell,
                                mechanic: .compound, defaultRestSeconds: 180)
        context.insert(exercise)
        let split = Split(name: "Chest")
        split.items = [SplitItem(order: 0, exercise: exercise, targetSets: 3, targetReps: 8)]
        context.insert(split)
        try? context.save()
        return (exercise, split)
    }

    @discardableResult
    private func logHistory(
        exercise: Exercise,
        split: Split,
        sets: [(Double, Int, SetType)],
        finishedAt: Date,
        context: ModelContext
    ) -> Session {
        let entry = SessionExercise(order: 0, exercise: exercise)
        entry.sets = sets.enumerated().map { index, spec in
            SetEntry(order: index, weightKg: spec.0, reps: spec.1,
                     setType: spec.2, isCompleted: true, completedAt: finishedAt)
        }
        let session = Session(title: split.name, startedAt: finishedAt.addingTimeInterval(-3600),
                              finishedAt: finishedAt, split: split, exercises: [entry])
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: Pre-fill

    @Test("With no history, rows fall back to the split's target reps at zero load")
    func fallsBackToSplitTargets() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)

        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let sets = try #require(session.orderedExercises.first).orderedSets

        #expect(sets.count == 3)
        #expect(sets.allSatisfy { $0.weightKg == 0 })
        #expect(sets.allSatisfy { $0.reps == 8 })
    }

    @Test("With history, every row is pre-filled from the same set index of last time")
    func prefillsFromLastSession() throws {
        let (context, settings) = try makeStore()
        let (exercise, split) = makeBenchSplit(context: context)
        logHistory(exercise: exercise, split: split,
                   sets: [(45, 10, .warmup), (87.5, 6, .working), (87.5, 6, .working), (87.5, 5, .working)],
                   finishedAt: .now.addingTimeInterval(-7 * 86_400), context: context)

        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let sets = try #require(session.orderedExercises.first).orderedSets

        // The shape comes back too: the warm-up someone always opens with is still there.
        #expect(sets.count == 4)
        #expect(sets[0].setType == .warmup)
        #expect(sets[0].weightKg == 45)
        #expect(sets[1].weightKg == 87.5)
        #expect(sets[1].reps == 6)
        #expect(sets[3].reps == 5)
    }

    @Test("Logging a set identical to last time takes one tap")
    func sameAsLastTimeIsOneTap() throws {
        let (context, settings) = try makeStore()
        let (exercise, split) = makeBenchSplit(context: context)
        logHistory(exercise: exercise, split: split,
                   sets: [(100, 5, .working)],
                   finishedAt: .now.addingTimeInterval(-7 * 86_400), context: context)

        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)

        // The only interaction is the checkmark — no typing, no stepping.
        controller.toggleCompleted(row, context: context, settings: settings)

        #expect(row.isCompleted)
        #expect(row.weightKg == 100)
        #expect(row.reps == 5)
        #expect(session.volumeKg == 500)
    }

    @Test("The last-time reference is exposed for every row")
    func referenceRowsAreAvailable() throws {
        let (context, settings) = try makeStore()
        let (exercise, split) = makeBenchSplit(context: context)
        logHistory(exercise: exercise, split: split,
                   sets: [(90, 5, .working), (90, 4, .working)],
                   finishedAt: .now.addingTimeInterval(-3 * 86_400), context: context)

        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let entry = try #require(session.orderedExercises.first)

        #expect(controller.reference(for: entry, at: 0)?.weightKg == 90)
        #expect(controller.reference(for: entry, at: 1)?.reps == 4)
        #expect(controller.reference(for: entry, at: 5) == nil)
    }

    @Test("Pre-fill reads the most recent session, not the first one found")
    func prefillUsesMostRecent() throws {
        let (context, settings) = try makeStore()
        let (exercise, split) = makeBenchSplit(context: context)
        logHistory(exercise: exercise, split: split, sets: [(80, 5, .working)],
                   finishedAt: .now.addingTimeInterval(-30 * 86_400), context: context)
        logHistory(exercise: exercise, split: split, sets: [(95, 5, .working)],
                   finishedAt: .now.addingTimeInterval(-3 * 86_400), context: context)

        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        #expect(session.orderedExercises.first?.orderedSets.first?.weightKg == 95)
    }

    @Test("An unfinished session is never used as the reference")
    func inProgressSessionIsNotAReference() throws {
        let (context, settings) = try makeStore()
        let (exercise, split) = makeBenchSplit(context: context)
        logHistory(exercise: exercise, split: split, sets: [(80, 5, .working)],
                   finishedAt: .now.addingTimeInterval(-5 * 86_400), context: context)

        let controller = SessionController()
        let first = controller.start(split: split, context: context, settings: settings)
        first.orderedExercises.first?.orderedSets.first?.weightKg = 999
        try context.save()

        // Starting again while the first is still open must not read the open one.
        let controller2 = SessionController()
        let second = controller2.start(split: split, context: context, settings: settings)
        #expect(second.orderedExercises.first?.orderedSets.first?.weightKg == 80)
    }

    // MARK: Keypad

    @Test("Typing digits commits to the row as they are typed")
    func typingCommits() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)
        let formatter = UnitFormatter(unit: .kilograms, locale: Locale(identifier: "en_GB"))

        controller.focus(KeypadTarget(setUID: row.uid, field: .weight))
        for digit in ["1", "0", "2", ".", "5"] {
            controller.appendDigit(digit, to: row, field: .weight, formatter: formatter, context: context)
        }
        #expect(row.weightKg == 102.5)
    }

    @Test("Step buttons act on the stored value, not on what was typed")
    func stepsActOnStoredValue() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)
        let formatter = UnitFormatter(unit: .kilograms, locale: Locale(identifier: "en_GB"))

        row.weightKg = 100
        controller.focus(KeypadTarget(setUID: row.uid, field: .weight))
        controller.increment(2.5, on: row, field: .weight, formatter: formatter, context: context)
        #expect(row.weightKg == 102.5)

        controller.increment(-5, on: row, field: .weight, formatter: formatter, context: context)
        #expect(row.weightKg == 97.5)

        // Weight never goes negative.
        controller.increment(-1000, on: row, field: .weight, formatter: formatter, context: context)
        #expect(row.weightKg == 0)
    }

    @Test("Stepping in pounds converts before touching the stored kilograms")
    func steppingInPoundsConverts() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)
        let pounds = UnitFormatter(unit: .pounds, locale: Locale(identifier: "en_US"))

        row.weightKg = 100
        controller.increment(5, on: row, field: .weight, formatter: pounds, context: context)

        // 220.462 lb + 5 lb, back to kilograms.
        #expect(abs(pounds.displayValue(kg: row.weightKg) - 225.462) < 0.001)
    }

    @Test("Next advances weight to reps, then on to the next set")
    func nextAdvancesThroughFields() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let rows = try #require(session.orderedExercises.first).orderedSets

        controller.focus(KeypadTarget(setUID: rows[0].uid, field: .weight))
        controller.advanceKeypad()
        #expect(controller.keypadTarget == KeypadTarget(setUID: rows[0].uid, field: .reps))

        controller.advanceKeypad()
        #expect(controller.keypadTarget == KeypadTarget(setUID: rows[1].uid, field: .weight))
    }

    @Test("Next dismisses the panel after the final field")
    func nextEndsAtTheLastRow() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let rows = try #require(session.orderedExercises.first).orderedSets

        controller.focus(KeypadTarget(setUID: rows[rows.count - 1].uid, field: .reps))
        controller.advanceKeypad()
        #expect(controller.keypadTarget == nil)
    }

    @Test("The panel can always be dismissed, which is what the hide button does")
    func hideDismissesThePanel() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)

        controller.focus(KeypadTarget(setUID: row.uid, field: .weight))
        #expect(controller.keypadTarget != nil)
        controller.dismissKeypad()
        #expect(controller.keypadTarget == nil)
        #expect(controller.keypadBuffer.isEmpty)
    }

    @Test("A timed movement offers only a duration field")
    func timedMovementFields() throws {
        let (context, settings) = try makeStore()
        let plank = Exercise(slug: "plank", name: "Plank", primaryMuscle: .abs,
                             equipment: .bodyweight, mechanic: .isolation, trackingMode: .timed)
        context.insert(plank)
        let split = Split(name: "Core")
        split.items = [SplitItem(order: 0, exercise: plank, targetSets: 2, targetReps: 1)]
        context.insert(split)
        try context.save()

        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)
        #expect(controller.availableFields(for: row) == [.duration])
    }

    // MARK: Editing

    @Test("Duplicating a set copies its values and keeps the order contiguous")
    func duplicateSet() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let entry = try #require(session.orderedExercises.first)
        let first = entry.orderedSets[0]
        first.weightKg = 100
        first.reps = 5

        controller.duplicate(first, context: context)

        let sets = entry.orderedSets
        #expect(sets.count == 4)
        #expect(sets[1].weightKg == 100)
        #expect(sets[1].reps == 5)
        #expect(sets.map(\.order) == [0, 1, 2, 3])
    }

    @Test("Deleting a set renumbers the rest")
    func deleteSet() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let entry = try #require(session.orderedExercises.first)

        controller.delete(entry.orderedSets[1], context: context)
        #expect(entry.orderedSets.count == 2)
        #expect(entry.orderedSets.map(\.order) == [0, 1])
    }

    @Test("Adding a set copies the previous one, because the next set is usually the same")
    func addSetCopiesPrevious() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let entry = try #require(session.orderedExercises.first)
        entry.orderedSets.last?.weightKg = 110
        entry.orderedSets.last?.reps = 3

        controller.addSet(to: entry, context: context)
        let added = try #require(entry.orderedSets.last)
        #expect(added.weightKg == 110)
        #expect(added.reps == 3)
    }

    @Test("Tapping the type chip cycles the set type")
    func cycleType() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)

        let start = row.setType
        controller.cycleType(row, context: context)
        #expect(row.setType != start)
        for _ in 1..<SetType.allCases.count { controller.cycleType(row, context: context) }
        #expect(row.setType == start)
    }

    @Test("An exercise can be added mid-session")
    func addExerciseMidSession() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let curl = Exercise(slug: "curl", name: "Curl", primaryMuscle: .biceps,
                            equipment: .dumbbell, mechanic: .isolation)
        context.insert(curl)
        try context.save()

        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        controller.addExercise(curl, context: context)

        #expect(session.orderedExercises.count == 2)
        #expect(session.orderedExercises.last?.displayName == "Curl")
    }

    // MARK: Rest handoff

    @Test("Checking off a working set asks for the rest timer")
    func workingSetRequestsRest() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)

        #expect(controller.toggleCompleted(row, context: context, settings: settings))
    }

    @Test("Checking off a warm-up never asks for the rest timer")
    func warmupDoesNotRequestRest() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)
        row.setType = .warmup

        #expect(controller.toggleCompleted(row, context: context, settings: settings) == false)
    }

    @Test("Turning auto-start off stops the rest timer being requested")
    func autoStartCanBeSwitchedOff() throws {
        let (context, settings) = try makeStore()
        settings.autoStartRestTimer = false
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)

        #expect(controller.toggleCompleted(row, context: context, settings: settings) == false)
    }

    @Test("Un-checking a set asks for nothing")
    func uncheckingRequestsNothing() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let row = try #require(session.orderedExercises.first?.orderedSets.first)

        controller.toggleCompleted(row, context: context, settings: settings)
        #expect(controller.toggleCompleted(row, context: context, settings: settings) == false)
        #expect(row.isCompleted == false)
    }

    // MARK: Finishing

    @Test("Finishing drops unchecked sets and removes exercises with none completed")
    func finishDropsUncheckedWork() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let curl = Exercise(slug: "curl", name: "Curl", primaryMuscle: .biceps,
                            equipment: .dumbbell, mechanic: .isolation)
        context.insert(curl)
        try context.save()

        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        controller.addExercise(curl, context: context)

        let bench = try #require(session.orderedExercises.first)
        bench.orderedSets[0].weightKg = 100
        controller.toggleCompleted(bench.orderedSets[0], context: context, settings: settings)

        // 2 unchecked bench sets + 3 unchecked curl sets.
        #expect(controller.uncheckedSetCount == 5)
        #expect(controller.exercisesLosingAllSetsCount == 1)

        let outcome = try controller.finish(context: context, settings: settings)
        #expect(outcome.droppedSetCount == 5)
        #expect(outcome.droppedExerciseCount == 1)

        #expect(session.orderedExercises.count == 1)
        #expect(session.orderedExercises.first?.orderedSets.count == 1)
        #expect(try context.fetch(FetchDescriptor<SetEntry>()).count == 1)
        #expect(session.isFinished)
    }

    @Test("Unchecked rows never reach the volume total as zeros")
    func uncheckedRowsDoNotCorruptVolume() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        let session = controller.start(split: split, context: context, settings: settings)
        let entry = try #require(session.orderedExercises.first)
        for row in entry.orderedSets { row.weightKg = 100 }
        controller.toggleCompleted(entry.orderedSets[0], context: context, settings: settings)

        try controller.finish(context: context, settings: settings)
        #expect(session.volumeKg == 800) // 100 x 8, one set only
    }

    @Test("Discarding removes the session entirely")
    func discardRemovesEverything() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        controller.start(split: split, context: context, settings: settings)

        controller.discard(context: context)
        #expect(controller.isActive == false)
        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
    }

    @Test("An in-progress session is offered for resume after a relaunch")
    func resumesInProgressSession() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        controller.start(split: split, context: context, settings: settings)

        // A fresh controller stands in for a cold launch after a force-quit.
        let relaunched = SessionController()
        #expect(relaunched.isActive == false)
        relaunched.resumeInProgressSession(context: context)
        #expect(relaunched.isActive)
        #expect(relaunched.session?.title == "Chest")
    }

    @Test("A finished session is never offered for resume")
    func finishedSessionIsNotResumed() throws {
        let (context, settings) = try makeStore()
        let (exercise, split) = makeBenchSplit(context: context)
        logHistory(exercise: exercise, split: split, sets: [(100, 5, .working)],
                   finishedAt: .now, context: context)

        let controller = SessionController()
        controller.resumeInProgressSession(context: context)
        #expect(controller.isActive == false)
    }

    @Test("A minimised session keeps running")
    func minimisingKeepsTheSessionAlive() throws {
        let (context, settings) = try makeStore()
        let (_, split) = makeBenchSplit(context: context)
        let controller = SessionController()
        controller.start(split: split, context: context, settings: settings)

        #expect(controller.isPresented)
        controller.isPresented = false
        #expect(controller.isActive)
        #expect(controller.session != nil)
    }
}
