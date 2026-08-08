import Foundation
import SwiftData

/// A weigh-in. Bodyweight movements need one to produce meaningful volume; when none
/// is on record the volume calculator assumes a default rather than counting them as zero.
@Model
final class BodyWeightEntry {
    var date: Date
    var weightKg: Double
    var notes: String

    init(date: Date = .now, weightKg: Double, notes: String = "") {
        self.date = date
        self.weightKg = weightKg
        self.notes = notes
    }
}
