import ActivityKit
import Foundation

/// Shared between the app (which starts and updates the Live Activity) and the widget
/// extension (which draws it).
///
/// The state carries the rest period's **absolute end date**, not a remaining count.
/// The lock screen renders the countdown itself from that date, so the display stays
/// correct with no updates at all while the phone is in a pocket.
nonisolated struct RestActivityAttributes: ActivityAttributes {

    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var startDate: Date
        var endDate: Date

        var totalSeconds: Int { max(0, Int(endDate.timeIntervalSince(startDate))) }
    }

    var exerciseName: String
    var sessionTitle: String
}
