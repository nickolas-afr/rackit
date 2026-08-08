import Foundation

nonisolated struct PlateStack: Equatable, Sendable, Identifiable {
    var plateKg: Double
    var count: Int

    var id: Double { plateKg }
    var totalKg: Double { plateKg * Double(count) }
}

nonisolated struct PlateSolution: Equatable, Sendable {
    var targetKg: Double
    var barKg: Double
    /// Plates for one side of the bar, heaviest first.
    var perSide: [PlateStack]
    /// What the bar actually weighs with these plates on both sides.
    var achievedKg: Double
    /// The part of the target that no combination of available plates can make.
    /// Reported rather than rounded away, so the user is never silently given a
    /// different weight than the one they asked for.
    var shortfallKg: Double
    /// The target is lighter than the empty bar, so no loading can reach it.
    var isBelowBar: Bool

    var isExact: Bool { shortfallKg == 0 && !isBelowBar }
    var perSideTotalKg: Double { perSide.reduce(0) { $0 + $1.totalKg } }
}

nonisolated enum PlateCalculator {

    /// A typical metric gym's plate set.
    static let defaultPlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    /// Greedy largest-first fill of one side of the bar.
    ///
    /// Arithmetic runs in whole grams rather than Doubles: 2.5 and 1.25 are not exactly
    /// representable in binary floating point, and a greedy loop that subtracts them
    /// repeatedly accumulates error until a plate that should fit no longer does.
    static func solve(
        targetKg: Double,
        barKg: Double,
        availablePlatesKg: [Double] = defaultPlatesKg
    ) -> PlateSolution {
        guard targetKg >= barKg else {
            return PlateSolution(
                targetKg: targetKg,
                barKg: barKg,
                perSide: [],
                achievedKg: barKg,
                shortfallKg: 0,
                isBelowBar: true
            )
        }

        let targetGrams = grams(targetKg)
        let barGrams = grams(barKg)

        // Everything above the bar is split across two sides. Integer division drops an
        // odd gram, which reappears in the shortfall rather than being rounded away.
        let loadGrams = targetGrams - barGrams
        var remainingPerSide = loadGrams / 2

        let plates = availablePlatesKg.filter { $0 > 0 }.sorted(by: >)
        var stacks: [PlateStack] = []

        for plate in plates {
            let plateGrams = grams(plate)
            guard plateGrams > 0, remainingPerSide >= plateGrams else { continue }
            let count = remainingPerSide / plateGrams
            remainingPerSide -= count * plateGrams
            stacks.append(PlateStack(plateKg: plate, count: count))
        }

        let usedPerSideGrams = loadGrams / 2 - remainingPerSide
        let achievedGrams = barGrams + usedPerSideGrams * 2
        let shortfallGrams = targetGrams - achievedGrams

        return PlateSolution(
            targetKg: targetKg,
            barKg: barKg,
            perSide: stacks,
            achievedKg: kilograms(achievedGrams),
            shortfallKg: kilograms(shortfallGrams),
            isBelowBar: false
        )
    }

    private static func grams(_ kg: Double) -> Int { Int((kg * 1000).rounded()) }
    private static func kilograms(_ grams: Int) -> Double { Double(grams) / 1000 }
}
