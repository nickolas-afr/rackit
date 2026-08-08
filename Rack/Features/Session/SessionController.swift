import Foundation
import Observation
import SwiftData

nonisolated enum KeypadField: Equatable, Sendable {
    case weight, reps, duration
}

nonisolated struct KeypadTarget: Equatable, Sendable {
    var setUID: UUID
    var field: KeypadField
}

/// What a finish actually did, so the confirmation and the summary can report it.
///
/// Holds the finished session itself: the controller lets go of it on finish, and the
/// summary still needs something to read.
struct FinishOutcome: Identifiable {
    var session: Session?
    var droppedSetCount: Int
    var droppedExerciseCount: Int
    var records: [RecordCandidate]

    var id: UUID { session?.uid ?? UUID() }
}

/// Owns the one session that can be in progress at a time.
///
/// The session itself lives in SwiftData from the moment it starts, so a force-quit
/// loses nothing; this object only holds the transient bits — what the keypad is
/// pointed at, whether the session is on screen or minimised, and the "last time"
/// reference rows.
@Observable
final class SessionController {

    private(set) var session: Session?
    /// False while the session is minimised: it keeps running, and the rest of the app
    /// stays usable.
    var isPresented = false

    var keypadTarget: KeypadTarget?
    /// Digits typed since the field was focused. Empty means "showing the stored value".
    var keypadBuffer = ""

    /// Reference rows per exercise slug, captured once when the session opens.
    private(set) var lastTimeBySlug: [String: [LastSetReference]] = [:]

    var isActive: Bool { session != nil }

    // MARK: Lifecycle

    /// Offers an unfinished session for resume after a relaunch.
    func resumeInProgressSession(context: ModelContext) {
        guard session == nil else { return }
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.finishedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let found = try? context.fetch(descriptor).first else { return }
        session = found
        rebuildReferences(context: context)
    }

    @discardableResult
    func start(split: Split, context: ModelContext, settings: AppSettings) -> Session {
        let newSession = Session(
            title: split.name,
            bodyWeightKg: latestBodyWeight(context: context),
            split: split
        )

        newSession.exercises = split.orderedItems.enumerated().compactMap { position, item in
            guard let exercise = item.exercise else { return nil }
            let reference = SessionBuilder.reference(
                from: SessionBuilder.lastPerformance(of: exercise, context: context)
            )
            return SessionBuilder.makeSessionExercise(
                order: position,
                exercise: exercise,
                targetSets: item.targetSets,
                targetReps: item.targetReps,
                restOverrideSeconds: split.restOverrideSeconds,
                reference: reference
            )
        }

        context.insert(newSession)
        try? context.save()

        session = newSession
        isPresented = true
        rebuildReferences(context: context)
        return newSession
    }

    @discardableResult
    func startEmpty(context: ModelContext, settings: AppSettings) -> Session {
        let newSession = Session(
            title: "Session",
            bodyWeightKg: latestBodyWeight(context: context)
        )
        context.insert(newSession)
        try? context.save()

        session = newSession
        isPresented = true
        lastTimeBySlug = [:]
        return newSession
    }

    /// Repeats the most recent finished session's exercise list.
    @discardableResult
    func repeatLast(context: ModelContext, settings: AppSettings) -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.finishedAt != nil },
            sortBy: [SortDescriptor(\.finishedAt, order: .reverse)]
        )
        guard let previous = try? context.fetch(descriptor).first else { return nil }
        return repeatSession(previous, context: context, settings: settings)
    }

    /// Repeats a specific session from history.
    @discardableResult
    func repeatSession(_ previous: Session, context: ModelContext, settings: AppSettings) -> Session? {
        if let split = previous.split {
            return start(split: split, context: context, settings: settings)
        }

        let newSession = Session(
            title: previous.title,
            bodyWeightKg: latestBodyWeight(context: context)
        )
        newSession.exercises = previous.orderedExercises.enumerated().compactMap { position, entry in
            guard let exercise = entry.exercise else { return nil }
            return SessionBuilder.makeSessionExercise(
                order: position,
                exercise: exercise,
                targetSets: entry.sets.count,
                targetReps: 8,
                restOverrideSeconds: entry.restOverrideSeconds,
                reference: SessionBuilder.reference(from: entry)
            )
        }
        context.insert(newSession)
        try? context.save()

        session = newSession
        isPresented = true
        rebuildReferences(context: context)
        return newSession
    }

    // MARK: Editing

    func addExercise(_ exercise: Exercise, context: ModelContext) {
        guard let session else { return }
        let reference = SessionBuilder.reference(
            from: SessionBuilder.lastPerformance(of: exercise, excluding: session.uid, context: context)
        )
        let entry = SessionBuilder.makeSessionExercise(
            order: (session.exercises.map(\.order).max() ?? -1) + 1,
            exercise: exercise,
            targetSets: 3,
            targetReps: 8,
            restOverrideSeconds: session.split?.restOverrideSeconds,
            reference: reference
        )
        entry.session = session
        session.exercises.append(entry)
        lastTimeBySlug[exercise.slug] = reference
        try? context.save()
    }

    /// A new set copies the last one, because the next set is almost always the same
    /// weight as the one just finished.
    func addSet(to entry: SessionExercise, context: ModelContext) {
        let existing = entry.orderedSets
        let template = existing.last
        let new = SetEntry(
            order: (existing.map(\.order).max() ?? -1) + 1,
            weightKg: template?.weightKg ?? 0,
            reps: template?.reps ?? 8,
            durationSeconds: template?.durationSeconds ?? 0,
            setType: template?.setType == .warmup ? .working : (template?.setType ?? .working)
        )
        new.sessionExercise = entry
        entry.sets.append(new)
        try? context.save()
    }

    func duplicate(_ set: SetEntry, context: ModelContext) {
        guard let entry = set.sessionExercise else { return }
        let copy = SetEntry(
            order: set.order + 1,
            weightKg: set.weightKg,
            reps: set.reps,
            durationSeconds: set.durationSeconds,
            setType: set.setType
        )
        for other in entry.sets where other.order > set.order {
            other.order += 1
        }
        copy.sessionExercise = entry
        entry.sets.append(copy)
        try? context.save()
    }

    func delete(_ set: SetEntry, context: ModelContext) {
        guard let entry = set.sessionExercise else { return }
        if keypadTarget?.setUID == set.uid { dismissKeypad() }
        entry.sets.removeAll { $0.uid == set.uid }
        context.delete(set)
        for (index, remaining) in entry.orderedSets.enumerated() {
            remaining.order = index
        }
        try? context.save()
    }

    func removeExercise(_ entry: SessionExercise, context: ModelContext) {
        guard let session else { return }
        session.exercises.removeAll { $0 === entry }
        context.delete(entry)
        for (index, remaining) in session.orderedExercises.enumerated() {
            remaining.order = index
        }
        try? context.save()
    }

    func cycleType(_ set: SetEntry, context: ModelContext) {
        set.setType = set.setType.next
        try? context.save()
    }

    /// Checks a set off. Returns true when the rest timer should start — a warm-up
    /// never does, and the preference can switch it off entirely.
    @discardableResult
    func toggleCompleted(_ set: SetEntry, context: ModelContext, settings: AppSettings) -> Bool {
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? .now : nil
        try? context.save()

        guard set.isCompleted else { return false }
        guard set.setType.startsRestTimer else { return false }
        return settings.autoStartRestTimer
    }

    // MARK: Finishing

    var uncheckedSetCount: Int { session?.uncheckedSets.count ?? 0 }

    var exercisesLosingAllSetsCount: Int {
        session?.orderedExercises.filter { $0.hasCompletedSets == false }.count ?? 0
    }

    /// Drops everything that was pre-filled but never performed, then awards records.
    ///
    /// Keeping unchecked rows as zeros would corrupt every volume total that reads this
    /// session afterwards, so they are removed rather than stored.
    @discardableResult
    func finish(context: ModelContext, settings: AppSettings) throws -> FinishOutcome {
        guard let session else {
            return FinishOutcome(session: nil, droppedSetCount: 0, droppedExerciseCount: 0, records: [])
        }
        dismissKeypad()

        let droppedSets = session.uncheckedSets
        let droppedSetCount = droppedSets.count
        for set in droppedSets {
            set.sessionExercise?.sets.removeAll { $0.uid == set.uid }
            context.delete(set)
        }

        let emptied = session.exercises.filter { $0.sets.isEmpty }
        let droppedExerciseCount = emptied.count
        for entry in emptied {
            session.exercises.removeAll { $0 === entry }
            context.delete(entry)
        }

        for (index, remaining) in session.orderedExercises.enumerated() {
            remaining.order = index
            for (setIndex, set) in remaining.orderedSets.enumerated() {
                set.order = setIndex
            }
        }

        session.finishedAt = .now
        try context.save()

        // Records are detected now, not while logging, because until this moment a set
        // could still be edited or deleted.
        let records = try RecordService.detectRecords(
            for: session,
            context: context,
            formula: settings.oneRepMaxFormula
        )
        try RecordService.apply(records, context: context)

        self.session = nil
        isPresented = false
        lastTimeBySlug = [:]

        return FinishOutcome(
            session: session,
            droppedSetCount: droppedSetCount,
            droppedExerciseCount: droppedExerciseCount,
            records: records
        )
    }

    func discard(context: ModelContext) {
        guard let session else { return }
        dismissKeypad()
        context.delete(session)
        try? context.save()
        self.session = nil
        isPresented = false
        lastTimeBySlug = [:]
    }

    // MARK: Keypad

    func focus(_ target: KeypadTarget) {
        keypadTarget = target
        keypadBuffer = ""
    }

    func dismissKeypad() {
        keypadTarget = nil
        keypadBuffer = ""
    }

    /// Advances weight to reps, then on to the next set's first field.
    func advanceKeypad() {
        guard let current = keypadTarget, let session else { return }
        let rows = session.orderedExercises.flatMap(\.orderedSets)
        guard let index = rows.firstIndex(where: { $0.uid == current.setUID }) else {
            dismissKeypad()
            return
        }
        let set = rows[index]
        let fields = availableFields(for: set)

        if let position = fields.firstIndex(of: current.field), position + 1 < fields.count {
            focus(KeypadTarget(setUID: set.uid, field: fields[position + 1]))
            return
        }
        guard index + 1 < rows.count else {
            dismissKeypad()
            return
        }
        let next = rows[index + 1]
        guard let first = availableFields(for: next).first else {
            dismissKeypad()
            return
        }
        focus(KeypadTarget(setUID: next.uid, field: first))
    }

    func availableFields(for set: SetEntry) -> [KeypadField] {
        let mode = set.trackingMode
        var fields: [KeypadField] = []
        if mode.showsWeightField { fields.append(.weight) }
        if mode.showsRepsField { fields.append(.reps) }
        if mode.showsDurationField { fields.append(.duration) }
        return fields
    }

    func focusedSet(in session: Session) -> SetEntry? {
        guard let target = keypadTarget else { return nil }
        return session.orderedExercises
            .flatMap(\.orderedSets)
            .first { $0.uid == target.setUID }
    }

    // MARK: Helpers

    func reference(for entry: SessionExercise, at index: Int) -> LastSetReference? {
        guard let slug = entry.exercise?.slug, let rows = lastTimeBySlug[slug] else { return nil }
        return index < rows.count ? rows[index] : nil
    }

    private func rebuildReferences(context: ModelContext) {
        guard let session else { return }
        var result: [String: [LastSetReference]] = [:]
        for entry in session.orderedExercises {
            guard let exercise = entry.exercise else { continue }
            let performance = SessionBuilder.lastPerformance(
                of: exercise,
                excluding: session.uid,
                context: context
            )
            result[exercise.slug] = SessionBuilder.reference(from: performance)
        }
        lastTimeBySlug = result
    }

    private func latestBodyWeight(context: ModelContext) -> Double? {
        let descriptor = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try? context.fetch(descriptor).first?.weightKg
    }
}
