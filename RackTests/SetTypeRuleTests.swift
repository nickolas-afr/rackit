import Testing
@testable import Rack

@Suite("Set type rules")
struct SetTypeRuleTests {

    @Test("Warm-ups are excluded from volume, records and the rest timer")
    func warmupIsExcludedEverywhere() {
        #expect(SetType.warmup.countsTowardVolume == false)
        #expect(SetType.warmup.canSetRecord == false)
        #expect(SetType.warmup.startsRestTimer == false)
    }

    @Test("Every non-warm-up type counts, can record and starts rest",
          arguments: [SetType.working, .dropSet, .toFailure, .amrap])
    func nonWarmupTypesParticipate(_ type: SetType) {
        #expect(type.countsTowardVolume)
        #expect(type.canSetRecord)
        #expect(type.startsRestTimer)
    }

    @Test("Cycling the type chip visits every type and returns to the start")
    func cyclingIsACompleteLoop() {
        var seen: [SetType] = []
        var current = SetType.warmup
        for _ in SetType.allCases {
            seen.append(current)
            current = current.next
        }
        #expect(current == .warmup)
        #expect(Set(seen) == Set(SetType.allCases))
    }
}

@Suite("Tracking modes")
struct TrackingModeTests {

    @Test("A timed movement never asks for reps or weight")
    func timedShowsOnlyDuration() {
        #expect(TrackingMode.timed.showsWeightField == false)
        #expect(TrackingMode.timed.showsRepsField == false)
        #expect(TrackingMode.timed.showsDurationField)
    }

    @Test("A bodyweight movement never asks for weight but does ask for reps")
    func bodyweightShowsOnlyReps() {
        #expect(TrackingMode.bodyweightReps.showsWeightField == false)
        #expect(TrackingMode.bodyweightReps.showsRepsField)
    }

    @Test("Bodyweight plus added asks for both, and includes body weight in volume")
    func bodyweightPlusAdded() {
        #expect(TrackingMode.bodyweightPlusAdded.showsWeightField)
        #expect(TrackingMode.bodyweightPlusAdded.showsRepsField)
        #expect(TrackingMode.bodyweightPlusAdded.includesBodyWeight)
    }

    @Test("Reps-only and timed produce no volume")
    func modesWithoutLoadProduceNoVolume() {
        #expect(TrackingMode.repsOnly.producesVolume == false)
        #expect(TrackingMode.timed.producesVolume == false)
        #expect(TrackingMode.weightAndReps.producesVolume)
        #expect(TrackingMode.bodyweightReps.producesVolume)
    }

    @Test("A 1RM estimate only applies where an external load was moved")
    func oneRepMaxApplicability() {
        #expect(TrackingMode.weightAndReps.supportsOneRepMax)
        #expect(TrackingMode.bodyweightPlusAdded.supportsOneRepMax)
        #expect(TrackingMode.bodyweightReps.supportsOneRepMax == false)
        #expect(TrackingMode.repsOnly.supportsOneRepMax == false)
        #expect(TrackingMode.timed.supportsOneRepMax == false)
    }
}

@Suite("Muscle taxonomy")
struct MuscleTaxonomyTests {

    @Test("Every muscle belongs to exactly one region, and regions cover all muscles")
    func regionsPartitionMuscles() {
        let fromRegions = MuscleRegion.allCases.flatMap(\.muscles)
        #expect(Set(fromRegions) == Set(MuscleGroup.allCases))
        #expect(fromRegions.count == MuscleGroup.allCases.count)
    }

    @Test("Only straight-bar equipment offers the plate calculator")
    func plateCalculatorEquipment() {
        #expect(Equipment.barbell.usesLoadableBar)
        #expect(Equipment.ezBar.usesLoadableBar)
        #expect(Equipment.trapBar.usesLoadableBar)
        #expect(Equipment.smithMachine.usesLoadableBar)
        #expect(Equipment.dumbbell.usesLoadableBar == false)
        #expect(Equipment.machine.usesLoadableBar == false)
        #expect(Equipment.cable.usesLoadableBar == false)
        #expect(Equipment.bodyweight.usesLoadableBar == false)
    }
}
