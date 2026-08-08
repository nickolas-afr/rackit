import Foundation
import Testing
@testable import Rack

@Suite("Muscle load")
struct MuscleLoadTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    @Test("Decay halves every seven days")
    func sevenDayHalfLife() {
        #expect(MuscleLoadCalculator.decayFactor(daysAgo: 0) == 1)
        #expect(abs(MuscleLoadCalculator.decayFactor(daysAgo: 7) - 0.5) < 1e-12)
        #expect(abs(MuscleLoadCalculator.decayFactor(daysAgo: 14) - 0.25) < 1e-12)
        #expect(abs(MuscleLoadCalculator.decayFactor(daysAgo: 21) - 0.125) < 1e-12)
    }

    @Test("A future-dated contribution is not amplified")
    func futureDatesClamp() {
        #expect(MuscleLoadCalculator.decayFactor(daysAgo: -30) == 1)
    }

    @Test("Secondary movers earn half credit")
    func secondaryHalfCredit() {
        let primary = MuscleContribution(muscle: .chest, date: now, isPrimary: true, sets: 4, volumeKg: 1000)
        let secondary = MuscleContribution(muscle: .triceps, date: now, isPrimary: false, sets: 4, volumeKg: 1000)
        #expect(primary.creditedSets == 4)
        #expect(secondary.creditedSets == 2)
        #expect(secondary.creditedVolumeKg == 500)
    }

    @Test("Loads normalise against the hardest-hit muscle")
    func normalisation() {
        let contributions = [
            MuscleContribution(muscle: .chest, date: now, isPrimary: true, sets: 10, volumeKg: 5000),
            MuscleContribution(muscle: .biceps, date: now, isPrimary: true, sets: 5, volumeKg: 1000),
        ]
        let loads = MuscleLoadCalculator.normalisedLoads(contributions: contributions, now: now)
        #expect(loads[.chest] == 1)
        #expect(abs((loads[.biceps] ?? 0) - 0.5) < 1e-12)
    }

    @Test("A lot of work three weeks ago reads as colder than a little work today")
    func decayBeatsRawVolume() {
        let contributions = [
            MuscleContribution(muscle: .chest, date: daysAgo(21), isPrimary: true, sets: 40, volumeKg: 20_000),
            MuscleContribution(muscle: .lats, date: now, isPrimary: true, sets: 10, volumeKg: 4_000),
        ]
        let loads = MuscleLoadCalculator.normalisedLoads(contributions: contributions, now: now)
        // Chest: 40 x 0.125 = 5. Lats: 10 x 1 = 10.
        #expect(loads[.lats] == 1)
        #expect(abs((loads[.chest] ?? 0) - 0.5) < 1e-9)
        #expect((loads[.chest] ?? 0) < (loads[.lats] ?? 0))
    }

    @Test("With no work at all, every muscle reads as zero rather than as peak")
    func emptyInputIsNotPeak() {
        let loads = MuscleLoadCalculator.normalisedLoads(contributions: [], now: now)
        #expect(loads.isEmpty)

        let summaries = MuscleLoadCalculator.summaries(contributions: [], now: now)
        #expect(summaries.count == MuscleGroup.allCases.count)
        #expect(summaries.allSatisfy { $0.load == 0 })
        #expect(summaries.allSatisfy { $0.hasBeenTrained == false })
    }

    @Test("Untrained muscles are listed explicitly, not omitted")
    func untrainedMusclesAreListed() {
        let contributions = [
            MuscleContribution(muscle: .chest, date: now, isPrimary: true, sets: 4, volumeKg: 1000)
        ]
        let summaries = MuscleLoadCalculator.summaries(contributions: contributions, now: now)
        #expect(summaries.count == MuscleGroup.allCases.count)

        let calves = summaries.first { $0.muscle == .calves }
        #expect(calves?.load == 0)
        #expect(calves?.lastTrained == nil)
        #expect(calves?.daysSinceLastTrained(now: now) == nil)
    }

    @Test("A summary reports days since a muscle was last trained")
    func daysSinceLastTrained() {
        let contributions = [
            MuscleContribution(muscle: .glutes, date: daysAgo(3), isPrimary: true, sets: 4, volumeKg: 2000),
            MuscleContribution(muscle: .glutes, date: daysAgo(10), isPrimary: true, sets: 4, volumeKg: 2000),
        ]
        let summaries = MuscleLoadCalculator.summaries(contributions: contributions, now: now)
        let glutes = summaries.first { $0.muscle == .glutes }
        #expect(glutes?.daysSinceLastTrained(now: now) == 3)
        #expect(glutes?.sets == 8)
    }

    @Test("Weekly set counts tally without decay, primary full and secondary half")
    func weeklySetCounts() {
        let contributions = [
            MuscleContribution(muscle: .chest, date: daysAgo(6), isPrimary: true, sets: 6, volumeKg: 3000),
            MuscleContribution(muscle: .chest, date: now, isPrimary: false, sets: 4, volumeKg: 1000),
        ]
        let perMuscle = MuscleLoadCalculator.setsPerMuscle(contributions: contributions)
        #expect(perMuscle[.chest] == 8) // 6 + 2, undecayed

        let perRegion = MuscleLoadCalculator.setsPerRegion(contributions: contributions)
        #expect(perRegion[.chest] == 8)
    }
}
