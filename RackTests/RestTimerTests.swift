import Foundation
import Testing
@testable import Rack

@Suite("Rest timer")
@MainActor
struct RestTimerTests {

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    @Test("Starting sets an absolute end date rather than a countdown")
    func startsFromAnAbsoluteEndDate() {
        let timer = RestTimerController()
        timer.start(seconds: 120, exerciseName: "Bench Press", sessionTitle: "Chest",
                    settings: makeSettings())

        #expect(timer.isRunning)
        let end = try? #require(timer.endDate)
        #expect(end != nil)
        #expect(abs((timer.endDate ?? .now).timeIntervalSinceNow - 120) < 1)
        #expect(timer.totalSeconds == 120)
    }

    @Test("Remaining time stays correct across a suspension")
    func survivesSuspension() {
        let timer = RestTimerController()
        timer.start(seconds: 120, exerciseName: "Squat", sessionTitle: "Legs", settings: makeSettings())
        let start = try! #require(timer.startDate)

        // Nothing ticked while the phone was in a pocket; the answer is still derived
        // from the end date, so 90 seconds later exactly 30 remain.
        #expect(abs(timer.remaining(at: start.addingTimeInterval(90)) - 30) < 0.01)
        #expect(timer.remainingSeconds(at: start.addingTimeInterval(90)) == 30)

        // And well past the end it is clamped at zero rather than going negative.
        #expect(timer.remaining(at: start.addingTimeInterval(10_000)) == 0)
    }

    @Test("Progress is derived from the same absolute dates")
    func progressIsDerived() {
        let timer = RestTimerController()
        timer.start(seconds: 100, exerciseName: "Row", sessionTitle: "Back", settings: makeSettings())
        let start = try! #require(timer.startDate)

        #expect(abs(timer.progress(at: start) - 0) < 0.02)
        #expect(abs(timer.progress(at: start.addingTimeInterval(50)) - 0.5) < 0.02)
        #expect(timer.progress(at: start.addingTimeInterval(500)) == 1)
    }

    @Test("Adding and removing 15 seconds moves the end date")
    func adjustMovesTheEndDate() {
        let settings = makeSettings()
        let timer = RestTimerController()
        timer.start(seconds: 120, exerciseName: "Bench", sessionTitle: "Chest", settings: settings)
        let original = try! #require(timer.endDate)

        timer.adjust(by: 15, settings: settings)
        #expect(abs((timer.endDate ?? .now).timeIntervalSince(original) - 15) < 0.01)

        timer.adjust(by: -15, settings: settings)
        #expect(abs((timer.endDate ?? .now).timeIntervalSince(original)) < 0.01)
    }

    @Test("Taking the timer past zero ends it instead of going negative")
    func adjustingBelowZeroEnds() {
        let settings = makeSettings()
        let timer = RestTimerController()
        timer.start(seconds: 10, exerciseName: "Curl", sessionTitle: "Arms", settings: settings)

        timer.adjust(by: -60, settings: settings)
        #expect(timer.isRunning == false)
        #expect(timer.remaining() == 0)
    }

    @Test("Skip stops the timer")
    func skipStops() {
        let timer = RestTimerController()
        timer.start(seconds: 120, exerciseName: "Dip", sessionTitle: "Chest", settings: makeSettings())
        timer.skip()

        #expect(timer.isRunning == false)
        #expect(timer.endDate == nil)
        #expect(timer.exerciseName.isEmpty)
    }

    @Test("Completion is signalled once and only after the end date")
    func completionFiresOnce() {
        let settings = makeSettings()
        let timer = RestTimerController()
        timer.start(seconds: 60, exerciseName: "Press", sessionTitle: "Shoulders", settings: settings)
        let start = try! #require(timer.startDate)

        // Still resting: nothing happens.
        timer.checkCompletion(settings: settings, now: start.addingTimeInterval(30))
        #expect(timer.isRunning)

        timer.checkCompletion(settings: settings, now: start.addingTimeInterval(61))
        #expect(timer.isRunning == false)

        // A second tick after it has already finished is harmless.
        timer.checkCompletion(settings: settings, now: start.addingTimeInterval(62))
        #expect(timer.isRunning == false)
    }

    @Test("A zero or negative rest period never starts the timer")
    func zeroRestDoesNotStart() {
        let timer = RestTimerController()
        timer.start(seconds: 0, exerciseName: "X", sessionTitle: "Y", settings: makeSettings())
        #expect(timer.isRunning == false)
    }

    @Test("The formatted label counts minutes and seconds")
    func formatting() {
        let timer = RestTimerController()
        timer.start(seconds: 125, exerciseName: "X", sessionTitle: "Y", settings: makeSettings())
        let start = try! #require(timer.startDate)

        #expect(timer.formattedRemaining(at: start) == "2:05")
        #expect(timer.formattedRemaining(at: start.addingTimeInterval(65)) == "1:00")
        #expect(timer.formattedRemaining(at: start.addingTimeInterval(200)) == "0:00")
    }
}
