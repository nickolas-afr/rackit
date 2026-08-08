import Foundation
import Testing
@testable import Rack

@Suite("Volume")
struct VolumeCalculatorTests {

    @Test("A working set is weight times reps")
    func workingSet() {
        let set = SetSnapshot(weightKg: 100, reps: 5)
        #expect(VolumeCalculator.volume(for: set, bodyWeightKg: 80) == 500)
    }

    @Test("A warm-up contributes nothing, even when heavier than the working sets")
    func warmupContributesNothing() {
        let heavyWarmup = SetSnapshot(weightKg: 200, reps: 5, setType: .warmup)
        let lighterWorking = SetSnapshot(weightKg: 100, reps: 5, setType: .working)
        #expect(VolumeCalculator.volume(for: heavyWarmup, bodyWeightKg: 80) == 0)
        #expect(VolumeCalculator.volume(for: [heavyWarmup, lighterWorking], bodyWeightKg: 80) == 500)
    }

    @Test("Every non-warm-up type contributes",
          arguments: [SetType.working, .dropSet, .toFailure, .amrap])
    func otherTypesContribute(_ type: SetType) {
        let set = SetSnapshot(weightKg: 50, reps: 10, setType: type)
        #expect(VolumeCalculator.volume(for: set, bodyWeightKg: 80) == 500)
    }

    @Test("An unchecked set contributes nothing")
    func uncheckedContributesNothing() {
        let set = SetSnapshot(weightKg: 100, reps: 5, isCompleted: false)
        #expect(VolumeCalculator.volume(for: set, bodyWeightKg: 80) == 0)
    }

    @Test("A bodyweight movement uses the recorded body weight")
    func bodyweightUsesRecordedWeight() {
        let set = SetSnapshot(reps: 10, trackingMode: .bodyweightReps)
        #expect(VolumeCalculator.volume(for: set, bodyWeightKg: 82) == 820)
    }

    @Test("A bodyweight movement with no weigh-in on record still produces non-zero volume")
    func bodyweightFallsBackRatherThanCountingZero() {
        let set = SetSnapshot(reps: 10, trackingMode: .bodyweightReps)
        let volume = VolumeCalculator.volume(for: set, bodyWeightKg: nil)
        #expect(volume == 750) // 75 kg assumed
        #expect(volume > 0)
    }

    @Test("A nonsensical recorded body weight falls back too")
    func zeroBodyWeightFallsBack() {
        let set = SetSnapshot(reps: 10, trackingMode: .bodyweightReps)
        #expect(VolumeCalculator.volume(for: set, bodyWeightKg: 0) == 750)
    }

    @Test("Bodyweight plus added load adds the two")
    func bodyweightPlusAdded() {
        let set = SetSnapshot(weightKg: 20, reps: 5, trackingMode: .bodyweightPlusAdded)
        #expect(VolumeCalculator.volume(for: set, bodyWeightKg: 80) == 500)
        #expect(VolumeCalculator.volume(for: set, bodyWeightKg: nil) == 475) // (75 + 20) x 5
    }

    @Test("Reps-only and timed movements produce no volume")
    func modesWithoutLoad() {
        #expect(VolumeCalculator.volume(
            for: SetSnapshot(reps: 20, trackingMode: .repsOnly), bodyWeightKg: 80) == 0)
        #expect(VolumeCalculator.volume(
            for: SetSnapshot(trackingMode: .timed), bodyWeightKg: 80) == 0)
    }

    @Test("Zero reps or zero load produce no volume")
    func degenerateSets() {
        #expect(VolumeCalculator.volume(for: SetSnapshot(weightKg: 100, reps: 0), bodyWeightKg: 80) == 0)
        #expect(VolumeCalculator.volume(for: SetSnapshot(weightKg: 0, reps: 10), bodyWeightKg: 80) == 0)
    }
}
