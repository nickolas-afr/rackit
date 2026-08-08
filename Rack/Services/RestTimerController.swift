import Foundation
import Observation

/// The rest timer.
///
/// State is an **absolute end date**, never a decrementing counter. Remaining time is
/// always derived by subtracting `now` from it, so the timer cannot drift or stall when
/// iOS suspends the app — which is exactly what happens the moment the phone goes into
/// a pocket between sets.
@Observable
final class RestTimerController {

    private(set) var startDate: Date?
    private(set) var endDate: Date?
    private(set) var exerciseName = ""
    private(set) var sessionTitle = ""

    /// Guards against firing completion more than once per rest period.
    @ObservationIgnored private var hasSignalledCompletion = false

    var isRunning: Bool { endDate != nil }

    var totalSeconds: Int {
        guard let startDate, let endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(startDate).rounded()))
    }

    /// Derived, never stored.
    func remaining(at now: Date = .now) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(now))
    }

    func remainingSeconds(at now: Date = .now) -> Int {
        Int(remaining(at: now).rounded(.up))
    }

    func progress(at now: Date = .now) -> Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(at: now) / Double(totalSeconds)))
    }

    func formattedRemaining(at now: Date = .now) -> String {
        let seconds = remainingSeconds(at: now)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Control

    func start(seconds: Int, exerciseName: String, sessionTitle: String, settings: AppSettings) {
        guard seconds > 0 else { return }
        let now = Date.now
        let end = now.addingTimeInterval(Double(seconds))

        startDate = now
        endDate = end
        self.exerciseName = exerciseName
        self.sessionTitle = sessionTitle
        hasSignalledCompletion = false

        RestNotifications.scheduleRestEnd(
            at: end,
            exerciseName: exerciseName,
            withSound: settings.restSoundEnabled
        )
        RestLiveActivity.start(
            exerciseName: exerciseName,
            sessionTitle: sessionTitle,
            startDate: now,
            endDate: end
        )
        Task { await RestNotifications.requestAuthorizationIfNeeded() }
    }

    /// −15s and +15s move the end date, then the alert and the Live Activity follow it.
    func adjust(by seconds: Int, settings: AppSettings) {
        guard let currentEnd = endDate, let currentStart = startDate else { return }
        let proposed = currentEnd.addingTimeInterval(Double(seconds))

        guard proposed > .now else {
            skip()
            return
        }
        endDate = proposed
        // Keep the progress bar honest when time is added.
        if proposed.timeIntervalSince(currentStart) < 0 { startDate = .now }

        RestNotifications.scheduleRestEnd(
            at: proposed,
            exerciseName: exerciseName,
            withSound: settings.restSoundEnabled
        )
        RestLiveActivity.update(startDate: startDate ?? currentStart, endDate: proposed)
    }

    func skip() {
        clear()
    }

    /// Called each tick by the countdown view. Signals completion exactly once.
    func checkCompletion(settings: AppSettings, now: Date = .now) {
        guard isRunning, !hasSignalledCompletion, remaining(at: now) <= 0 else { return }
        hasSignalledCompletion = true

        HapticEngine.restFinished(
            haptics: settings.restHapticsEnabled,
            sound: settings.restSoundEnabled
        )
        clear()
    }

    func clear() {
        startDate = nil
        endDate = nil
        exerciseName = ""
        sessionTitle = ""
        hasSignalledCompletion = false
        RestNotifications.cancel()
        RestLiveActivity.end()
    }
}
