import Foundation
import Testing
@testable import Rack

@Suite("Record detection")
struct RecordDetectorTests {

    private let formula = OneRepMaxFormula.epley
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ n: Int) -> Date { day0.addingTimeInterval(Double(n) * 86_400) }

    private func performance(
        on date: Date,
        sets: [RecordSetInput],
        mode: TrackingMode = .weightAndReps,
        bodyWeightKg: Double? = 80
    ) -> ExercisePerformance {
        ExercisePerformance(
            date: date,
            exerciseSlug: "bench-press",
            exerciseName: "Bench Press",
            trackingMode: mode,
            bodyWeightKg: bodyWeightKg,
            sets: sets
        )
    }

    @Test("The first performance sets every record as a first time")
    func firstPerformanceIsAllFirstTimes() {
        let first = performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 5)])
        let records = RecordDetector.detect(in: first, priorBests: [:], formula: formula)

        #expect(records.count == 4)
        #expect(records.allSatisfy { $0.isFirstTime })
        #expect(records.allSatisfy { $0.previousValue == nil })
        #expect(records.first { $0.kind == .heaviestWeight }?.value == 100)
    }

    @Test("Equalling a previous best awards no record")
    func aTieIsNotARecord() {
        let first = performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 5)])
        let bests = RecordDetector.bests(across: [first], formula: formula)

        let repeated = performance(on: day(7), sets: [RecordSetInput(weightKg: 100, reps: 5)])
        let records = RecordDetector.detect(in: repeated, priorBests: bests, formula: formula)

        #expect(records.isEmpty)
    }

    @Test("Beating a previous best by any margin awards a record with the improvement")
    func strictImprovementAwardsRecord() {
        let first = performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 5)])
        let bests = RecordDetector.bests(across: [first], formula: formula)

        let heavier = performance(on: day(7), sets: [RecordSetInput(weightKg: 102.5, reps: 5)])
        let records = RecordDetector.detect(in: heavier, priorBests: bests, formula: formula)

        let heaviest = records.first { $0.kind == .heaviestWeight }
        #expect(heaviest?.value == 102.5)
        #expect(heaviest?.previousValue == 100)
        #expect(heaviest?.improvement == 2.5)
        #expect(heaviest?.isFirstTime == false)
    }

    @Test("A warm-up sets no record, even when it is the heaviest set of the day")
    func warmupSetsNoRecord() {
        let first = performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 5)])
        let bests = RecordDetector.bests(across: [first], formula: formula)

        let withHeavyWarmup = performance(on: day(7), sets: [
            RecordSetInput(weightKg: 200, reps: 5, setType: .warmup),
            RecordSetInput(weightKg: 100, reps: 5, setType: .working),
        ])
        let records = RecordDetector.detect(in: withHeavyWarmup, priorBests: bests, formula: formula)
        #expect(records.isEmpty)
    }

    @Test("An unchecked set sets no record")
    func uncheckedSetSetsNoRecord() {
        let attempt = performance(on: day(0), sets: [
            RecordSetInput(weightKg: 200, reps: 5, isCompleted: false)
        ])
        #expect(RecordDetector.detect(in: attempt, priorBests: [:], formula: formula).isEmpty)
    }

    @Test("Best single-set volume and best session volume are tracked separately")
    func setVolumeVersusSessionVolume() {
        let performance = performance(on: day(0), sets: [
            RecordSetInput(weightKg: 100, reps: 5), // 500
            RecordSetInput(weightKg: 60, reps: 10), // 600
        ])
        let marks = RecordDetector.marks(for: performance, formula: formula)
        #expect(marks[.bestSetVolume]?.value == 600)
        #expect(marks[.bestSessionVolume]?.value == 1100)
    }

    @Test("More total work with a lighter top set beats only the session volume record")
    func sessionVolumeCanImproveAlone() {
        let first = performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 5)])
        let bests = RecordDetector.bests(across: [first], formula: formula)

        let volumeDay = performance(on: day(7), sets: [
            RecordSetInput(weightKg: 80, reps: 10),
            RecordSetInput(weightKg: 80, reps: 10),
        ])
        let records = RecordDetector.detect(in: volumeDay, priorBests: bests, formula: formula)
        let kinds = Set(records.map(\.kind))

        #expect(kinds.contains(.bestSessionVolume))
        #expect(kinds.contains(.bestSetVolume))
        #expect(kinds.contains(.heaviestWeight) == false)
        #expect(kinds.contains(.bestOneRepMax) == false)
    }

    @Test("A bodyweight movement records volume but not a heaviest weight")
    func bodyweightRecordKinds() {
        let pullups = ExercisePerformance(
            date: day(0),
            exerciseSlug: "pull-up",
            exerciseName: "Pull-Up",
            trackingMode: .bodyweightReps,
            bodyWeightKg: nil,
            sets: [RecordSetInput(weightKg: 0, reps: 10)]
        )
        let records = RecordDetector.detect(in: pullups, priorBests: [:], formula: formula)
        let kinds = Set(records.map(\.kind))

        #expect(kinds.contains(.heaviestWeight) == false)
        #expect(kinds.contains(.bestOneRepMax) == false)
        #expect(kinds.contains(.bestSetVolume))
        #expect(records.first { $0.kind == .bestSetVolume }?.value == 750)
    }

    @Test("Rebuilding from full history reproduces the standing records")
    func rebuildReproducesRecords() {
        let history = [
            performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 5)]),
            performance(on: day(7), sets: [RecordSetInput(weightKg: 105, reps: 5)]),
            performance(on: day(14), sets: [RecordSetInput(weightKg: 102.5, reps: 5)]),
        ]
        let rebuilt = RecordDetector.rebuild(from: history, formula: formula)
        let bench = rebuilt["bench-press"]

        #expect(bench?[.heaviestWeight]?.value == 105)
        #expect(bench?[.heaviestWeight]?.previousValue == 100)
        #expect(bench?[.heaviestWeight]?.achievedAt == day(7))
    }

    @Test("Rebuilding after a deletion removes the record that depended on it")
    func deletingASessionRemovesItsRecord() {
        let kept = performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 5)])
        let deleted = performance(on: day(7), sets: [RecordSetInput(weightKg: 140, reps: 5)])

        let withBoth = RecordDetector.rebuild(from: [kept, deleted], formula: formula)
        #expect(withBoth["bench-press"]?[.heaviestWeight]?.value == 140)

        let afterDeletion = RecordDetector.rebuild(from: [kept], formula: formula)
        #expect(afterDeletion["bench-press"]?[.heaviestWeight]?.value == 100)
        #expect(afterDeletion["bench-press"]?[.heaviestWeight]?.isFirstTime == true)
    }

    @Test("A rebuild replays oldest-first so each record carries the date that set it")
    func rebuildIsChronological() {
        let outOfOrder = [
            performance(on: day(14), sets: [RecordSetInput(weightKg: 110, reps: 5)]),
            performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 5)]),
            performance(on: day(7), sets: [RecordSetInput(weightKg: 105, reps: 5)]),
        ]
        let rebuilt = RecordDetector.rebuild(from: outOfOrder, formula: formula)
        let heaviest = rebuilt["bench-press"]?[.heaviestWeight]

        #expect(heaviest?.value == 110)
        #expect(heaviest?.achievedAt == day(14))
        #expect(heaviest?.previousValue == 105)
    }

    @Test("Changing the formula changes the 1RM record without touching the others")
    func formulaAffectsOnlyOneRepMax() {
        let history = [
            performance(on: day(0), sets: [RecordSetInput(weightKg: 100, reps: 10)]),
            performance(on: day(7), sets: [RecordSetInput(weightKg: 120, reps: 2)]),
        ]
        let epley = RecordDetector.rebuild(from: history, formula: .epley)["bench-press"]
        let lombardi = RecordDetector.rebuild(from: history, formula: .lombardi)["bench-press"]

        #expect(epley?[.heaviestWeight]?.value == lombardi?[.heaviestWeight]?.value)
        #expect(epley?[.bestSetVolume]?.value == lombardi?[.bestSetVolume]?.value)
        #expect(epley?[.bestOneRepMax]?.value != lombardi?[.bestOneRepMax]?.value)
    }
}
