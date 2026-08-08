import Foundation
import UserNotifications

/// The rest timer's alert for when the screen is locked.
///
/// The app cannot rely on being alive when rest ends — the phone goes in a pocket and
/// iOS suspends it — so the alert is handed to the system up front and cancelled if the
/// user skips or adjusts.
enum RestNotifications {
    static let identifier = "rack.rest-timer"

    static func requestAuthorizationIfNeeded() async {
        let centre = UNUserNotificationCenter.current()
        let settings = await centre.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await centre.requestAuthorization(options: [.alert, .sound])
    }

    /// Replaces any pending alert with one at `date`.
    static func scheduleRestEnd(at date: Date, exerciseName: String, withSound: Bool) {
        cancel()

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = exerciseName.isEmpty ? "Next set." : "Next set of \(exerciseName)."
        content.sound = withSound ? .default : nil
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [identifier])
        centre.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
