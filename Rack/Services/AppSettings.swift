import Foundation
import Observation

/// User preferences, in UserDefaults rather than SwiftData: they are a handful of
/// scalars, they are read on nearly every view update, and they are not history.
@Observable
final class AppSettings {

    private enum Key {
        static let appearance = "appearance"
        static let weightUnit = "weightUnit"
        static let oneRepMaxFormula = "oneRepMaxFormula"
        static let autoStartRestTimer = "autoStartRestTimer"
        static let fallbackRestSeconds = "fallbackRestSeconds"
        static let restHaptics = "restHaptics"
        static let restSound = "restSound"
        static let keepScreenAwake = "keepScreenAwake"
        static let barWeightKg = "barWeightKg"
        static let bodyWeightLogging = "bodyWeightLogging"
        static let seededCatalogueVersion = "seededCatalogueVersion"
        static let didSeedStartingHistory = "didSeedStartingHistory"
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.appearance: AppearanceMode.automatic.rawValue,
            Key.weightUnit: WeightUnit.kilograms.rawValue,
            Key.oneRepMaxFormula: OneRepMaxFormula.epley.rawValue,
            Key.autoStartRestTimer: true,
            Key.fallbackRestSeconds: 120,
            Key.restHaptics: true,
            Key.restSound: true,
            Key.keepScreenAwake: true,
            Key.barWeightKg: 20.0,
            Key.bodyWeightLogging: true,
            Key.seededCatalogueVersion: 0,
            Key.didSeedStartingHistory: false,
        ])
    }

    var appearance: AppearanceMode {
        get { access(keyPath: \.appearance); return enumValue(Key.appearance, default: .automatic) }
        set { withMutation(keyPath: \.appearance) { defaults.set(newValue.rawValue, forKey: Key.appearance) } }
    }

    var weightUnit: WeightUnit {
        get { access(keyPath: \.weightUnit); return enumValue(Key.weightUnit, default: .kilograms) }
        set { withMutation(keyPath: \.weightUnit) { defaults.set(newValue.rawValue, forKey: Key.weightUnit) } }
    }

    var oneRepMaxFormula: OneRepMaxFormula {
        get { access(keyPath: \.oneRepMaxFormula); return enumValue(Key.oneRepMaxFormula, default: .epley) }
        set { withMutation(keyPath: \.oneRepMaxFormula) { defaults.set(newValue.rawValue, forKey: Key.oneRepMaxFormula) } }
    }

    var autoStartRestTimer: Bool {
        get { access(keyPath: \.autoStartRestTimer); return defaults.bool(forKey: Key.autoStartRestTimer) }
        set { withMutation(keyPath: \.autoStartRestTimer) { defaults.set(newValue, forKey: Key.autoStartRestTimer) } }
    }

    /// Used when neither the exercise nor the split says otherwise.
    var fallbackRestSeconds: Int {
        get { access(keyPath: \.fallbackRestSeconds); return defaults.integer(forKey: Key.fallbackRestSeconds) }
        set { withMutation(keyPath: \.fallbackRestSeconds) { defaults.set(newValue, forKey: Key.fallbackRestSeconds) } }
    }

    var restHapticsEnabled: Bool {
        get { access(keyPath: \.restHapticsEnabled); return defaults.bool(forKey: Key.restHaptics) }
        set { withMutation(keyPath: \.restHapticsEnabled) { defaults.set(newValue, forKey: Key.restHaptics) } }
    }

    var restSoundEnabled: Bool {
        get { access(keyPath: \.restSoundEnabled); return defaults.bool(forKey: Key.restSound) }
        set { withMutation(keyPath: \.restSoundEnabled) { defaults.set(newValue, forKey: Key.restSound) } }
    }

    var keepScreenAwake: Bool {
        get { access(keyPath: \.keepScreenAwake); return defaults.bool(forKey: Key.keepScreenAwake) }
        set { withMutation(keyPath: \.keepScreenAwake) { defaults.set(newValue, forKey: Key.keepScreenAwake) } }
    }

    var barWeightKg: Double {
        get { access(keyPath: \.barWeightKg); return defaults.double(forKey: Key.barWeightKg) }
        set { withMutation(keyPath: \.barWeightKg) { defaults.set(newValue, forKey: Key.barWeightKg) } }
    }

    var bodyWeightLoggingEnabled: Bool {
        get { access(keyPath: \.bodyWeightLoggingEnabled); return defaults.bool(forKey: Key.bodyWeightLogging) }
        set { withMutation(keyPath: \.bodyWeightLoggingEnabled) { defaults.set(newValue, forKey: Key.bodyWeightLogging) } }
    }

    // MARK: Seed guards — each seed is independent and carries its own guard.

    var seededCatalogueVersion: Int {
        get { access(keyPath: \.seededCatalogueVersion); return defaults.integer(forKey: Key.seededCatalogueVersion) }
        set { withMutation(keyPath: \.seededCatalogueVersion) { defaults.set(newValue, forKey: Key.seededCatalogueVersion) } }
    }

    var didSeedStartingHistory: Bool {
        get { access(keyPath: \.didSeedStartingHistory); return defaults.bool(forKey: Key.didSeedStartingHistory) }
        set { withMutation(keyPath: \.didSeedStartingHistory) { defaults.set(newValue, forKey: Key.didSeedStartingHistory) } }
    }

    // MARK: Derived

    var unitFormatter: UnitFormatter { UnitFormatter(unit: weightUnit) }

    private func enumValue<T: RawRepresentable>(_ key: String, default fallback: T) -> T where T.RawValue == String {
        guard let raw = defaults.string(forKey: key), let value = T(rawValue: raw) else { return fallback }
        return value
    }
}
