import Foundation
import Testing
@testable import Rack

private func isClose(_ a: Double, _ b: Double, tolerance: Double = 0.0001) -> Bool {
    abs(a - b) <= tolerance
}

@Suite("Estimated 1RM")
struct OneRepMaxTests {

    @Test("Epley matches w x (1 + r / 30)")
    func epley() {
        #expect(isClose(OneRepMax.estimate(weight: 100, reps: 10, formula: .epley), 133.3333))
        #expect(isClose(OneRepMax.estimate(weight: 60, reps: 5, formula: .epley), 70))
    }

    @Test("Brzycki matches w x 36 / (37 - r)")
    func brzycki() {
        #expect(isClose(OneRepMax.estimate(weight: 100, reps: 10, formula: .brzycki), 133.3333))
        #expect(isClose(OneRepMax.estimate(weight: 100, reps: 5, formula: .brzycki), 112.5))
    }

    @Test("Lombardi matches w x r^0.10")
    func lombardi() {
        #expect(isClose(OneRepMax.estimate(weight: 100, reps: 10, formula: .lombardi), 125.8925))
        #expect(isClose(OneRepMax.estimate(weight: 100, reps: 4, formula: .lombardi), 100 * pow(4, 0.10)))
    }

    @Test("A single rep returns the weight unchanged, in every formula",
          arguments: OneRepMaxFormula.allCases)
    func singleRepIsTheWeightItself(_ formula: OneRepMaxFormula) {
        #expect(OneRepMax.estimate(weight: 142.5, reps: 1, formula: formula) == 142.5)
    }

    @Test("Reps are capped at 12 for estimation", arguments: OneRepMaxFormula.allCases)
    func repsAreCapped(_ formula: OneRepMaxFormula) {
        let atCap = OneRepMax.estimate(weight: 100, reps: 12, formula: formula)
        #expect(OneRepMax.estimate(weight: 100, reps: 13, formula: formula) == atCap)
        #expect(OneRepMax.estimate(weight: 100, reps: 30, formula: formula) == atCap)
        #expect(OneRepMax.estimate(weight: 100, reps: 100, formula: formula) == atCap)
    }

    @Test("Brzycki stays finite past the rep count where it would diverge")
    func brzyckiDoesNotDiverge() {
        // Uncapped, r = 37 would divide by zero and r > 37 would go negative.
        let estimate = OneRepMax.estimate(weight: 100, reps: 40, formula: .brzycki)
        #expect(estimate.isFinite)
        #expect(estimate > 0)
        #expect(isClose(estimate, 144)) // 100 x 36 / (37 - 12)
    }

    @Test("Zero or negative input estimates nothing", arguments: OneRepMaxFormula.allCases)
    func degenerateInput(_ formula: OneRepMaxFormula) {
        #expect(OneRepMax.estimate(weight: 0, reps: 5, formula: formula) == 0)
        #expect(OneRepMax.estimate(weight: 100, reps: 0, formula: formula) == 0)
        #expect(OneRepMax.estimate(weight: -50, reps: 5, formula: formula) == 0)
    }

    @Test("Target load inverts the estimate", arguments: OneRepMaxFormula.allCases)
    func loadInvertsEstimate(_ formula: OneRepMaxFormula) {
        let oneRM = OneRepMax.estimate(weight: 100, reps: 5, formula: formula)
        let recovered = OneRepMax.load(forReps: 5, oneRepMax: oneRM, formula: formula)
        #expect(isClose(recovered, 100, tolerance: 0.001))
    }
}
