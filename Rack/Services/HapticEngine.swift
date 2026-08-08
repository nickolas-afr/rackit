import AudioToolbox
import UIKit

/// Both channels are user preferences, so every call takes the setting rather than
/// deciding for itself.
enum HapticEngine {

    static func restFinished(haptics: Bool, sound: Bool) {
        if haptics {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if sound {
            // The system's own alert tone: no bundled asset, nothing to download.
            AudioServicesPlaySystemSound(1_057)
        }
    }

    static func setCompleted(haptics: Bool) {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func recordAwarded(haptics: Bool) {
        guard haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
