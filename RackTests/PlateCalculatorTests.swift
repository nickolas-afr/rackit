import Foundation
import Testing
@testable import Rack

@Suite("Plate calculator")
struct PlateCalculatorTests {

    @Test("A makeable target loads greedily, largest plate first")
    func greedyFill() {
        let solution = PlateCalculator.solve(targetKg: 100, barKg: 20)
        #expect(solution.isExact)
        #expect(solution.achievedKg == 100)
        #expect(solution.perSide == [PlateStack(plateKg: 25, count: 1), PlateStack(plateKg: 15, count: 1)])
        #expect(solution.perSideTotalKg == 40)
    }

    @Test("Fractional plates come out exact despite not being representable in binary")
    func fractionalPlatesAreExact() {
        let solution = PlateCalculator.solve(targetKg: 102.5, barKg: 20)
        #expect(solution.isExact)
        #expect(solution.shortfallKg == 0)
        #expect(solution.achievedKg == 102.5)
        #expect(solution.perSide == [
            PlateStack(plateKg: 25, count: 1),
            PlateStack(plateKg: 15, count: 1),
            PlateStack(plateKg: 1.25, count: 1),
        ])
    }

    @Test("Repeated small plates do not accumulate floating point error")
    func repeatedSmallPlates() {
        // 20 kg bar + 1.25 kg per side x 8 would drift if this ran in Doubles.
        let solution = PlateCalculator.solve(targetKg: 40, barKg: 20, availablePlatesKg: [1.25])
        #expect(solution.isExact)
        #expect(solution.perSide == [PlateStack(plateKg: 1.25, count: 8)])
        #expect(solution.achievedKg == 40)
    }

    @Test("An unmakeable target reports the shortfall instead of rounding it away")
    func unmakeableTargetReportsShortfall() {
        let solution = PlateCalculator.solve(targetKg: 100.5, barKg: 20)
        #expect(solution.isExact == false)
        #expect(solution.achievedKg == 100)
        #expect(solution.shortfallKg == 0.5)
    }

    @Test("An odd remainder that cannot be balanced across two sides is reported, not dropped")
    func oddRemainderIsReported() {
        let solution = PlateCalculator.solve(targetKg: 21.25, barKg: 20, availablePlatesKg: [1.25])
        // 1.25 kg of load cannot be split evenly onto two sides.
        #expect(solution.perSide.isEmpty)
        #expect(solution.achievedKg == 20)
        #expect(solution.shortfallKg == 1.25)
    }

    @Test("An empty bar is an exact solution with no plates")
    func emptyBarIsExact() {
        let solution = PlateCalculator.solve(targetKg: 20, barKg: 20)
        #expect(solution.isExact)
        #expect(solution.perSide.isEmpty)
        #expect(solution.achievedKg == 20)
    }

    @Test("A target lighter than the bar is flagged rather than silently solved")
    func belowBar() {
        let solution = PlateCalculator.solve(targetKg: 15, barKg: 20)
        #expect(solution.isBelowBar)
        #expect(solution.isExact == false)
        #expect(solution.perSide.isEmpty)
    }

    @Test("A heavy target stacks multiples of the largest plate")
    func heavyTarget() {
        let solution = PlateCalculator.solve(targetKg: 220, barKg: 20)
        #expect(solution.isExact)
        #expect(solution.perSide.first == PlateStack(plateKg: 25, count: 4))
        #expect(solution.perSideTotalKg == 100)
    }

    @Test("A restricted plate set still reports exactly what it can and cannot make")
    func restrictedPlateSet() {
        let solution = PlateCalculator.solve(targetKg: 100, barKg: 20, availablePlatesKg: [20])
        #expect(solution.perSide == [PlateStack(plateKg: 20, count: 2)])
        #expect(solution.achievedKg == 100)
        #expect(solution.isExact)

        // 90 kg needs 35 kg a side; a single 20 is all that fits, so the bar makes 60.
        let awkward = PlateCalculator.solve(targetKg: 90, barKg: 20, availablePlatesKg: [20])
        #expect(awkward.perSide == [PlateStack(plateKg: 20, count: 1)])
        #expect(awkward.achievedKg == 60)
        #expect(awkward.shortfallKg == 30)
        #expect(awkward.isExact == false)
    }
}
