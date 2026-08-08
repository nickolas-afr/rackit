import ActivityKit
import Foundation

/// Drives the lock-screen Live Activity for the rest timer.
///
/// Only the end date is ever sent. The widget renders the countdown from it, so the
/// activity needs no periodic updates to stay accurate while the app is suspended.
///
/// No `Activity` handle is stored. `Activity` is not `Sendable`, so keeping one and then
/// using it from an async context trips region isolation; looking the live activities up
/// inside the task keeps every handle on one side of the boundary. There is at most one
/// rest activity at a time, so the lookup is exact rather than a guess.
enum RestLiveActivity {

    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(exerciseName: String, sessionTitle: String, startDate: Date, endDate: Date) {
        guard isSupported else { return }

        let attributes = RestActivityAttributes(
            exerciseName: exerciseName,
            sessionTitle: sessionTitle
        )
        let content = ActivityContent(
            state: RestActivityAttributes.ContentState(startDate: startDate, endDate: endDate),
            staleDate: endDate.addingTimeInterval(60)
        )

        Task {
            await endAll()
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
    }

    /// Used by −15s and +15s, which move the end date.
    static func update(startDate: Date, endDate: Date) {
        guard isSupported else { return }
        let content = ActivityContent(
            state: RestActivityAttributes.ContentState(startDate: startDate, endDate: endDate),
            staleDate: endDate.addingTimeInterval(60)
        )
        Task {
            for activity in Activity<RestActivityAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    static func end() {
        guard isSupported else { return }
        Task { await endAll() }
    }

    private static func endAll() async {
        for activity in Activity<RestActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
