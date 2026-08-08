import Foundation

nonisolated enum OneRepMaxFormula: String, Codable, CaseIterable, Identifiable, Sendable {
    case epley, brzycki, lombardi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .epley: "Epley"
        case .brzycki: "Brzycki"
        case .lombardi: "Lombardi"
        }
    }

    var expression: String {
        switch self {
        case .epley: "w × (1 + r / 30)"
        case .brzycki: "w × 36 / (37 − r)"
        case .lombardi: "w × r^0.10"
        }
    }
}

nonisolated enum OneRepMax {

    /// Beyond twelve reps these formulas diverge from reality, and Brzycki tends to
    /// infinity as reps approach 37. Estimation therefore treats anything above this
    /// as exactly this many reps.
    static let repCap = 12

    /// Estimated one-rep max in the same unit as `weight`.
    ///
    /// A single rep returns the weight unchanged — that is not an estimate, it is the
    /// measurement. (Epley alone would otherwise report 3.3% above the weight lifted.)
    static func estimate(weight: Double, reps: Int, formula: OneRepMaxFormula) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }

        let r = Double(min(reps, repCap))
        switch formula {
        case .epley:
            return weight * (1 + r / 30)
        case .brzycki:
            return weight * 36 / (37 - r)
        case .lombardi:
            return weight * pow(r, 0.10)
        }
    }

    /// The load to use for a target rep count, inverting the formula. Drives the
    /// target-load table on the exercise detail screen.
    static func load(forReps reps: Int, oneRepMax: Double, formula: OneRepMaxFormula) -> Double {
        guard oneRepMax > 0, reps > 0 else { return 0 }
        if reps == 1 { return oneRepMax }

        let r = Double(min(reps, repCap))
        switch formula {
        case .epley:
            return oneRepMax / (1 + r / 30)
        case .brzycki:
            return oneRepMax * (37 - r) / 36
        case .lombardi:
            return oneRepMax / pow(r, 0.10)
        }
    }
}
