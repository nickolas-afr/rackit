import Foundation

// MARK: - Muscles

/// The muscle taxonomy. Deliberately coarse: fine enough to drive a heatmap and
/// weekly set counts, coarse enough that tagging an exercise is never a judgement call.
nonisolated enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest
    case anteriorDeltoid
    case lateralDeltoid
    case posteriorDeltoid
    case biceps
    case triceps
    case forearms
    case abs
    case obliques
    case lats
    case trapezius
    case rhomboids
    case lowerBack
    case glutes
    case quadriceps
    case hamstrings
    case adductors
    case abductors
    case calves
    case neck

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .anteriorDeltoid: "Front Delts"
        case .lateralDeltoid: "Side Delts"
        case .posteriorDeltoid: "Rear Delts"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .lats: "Lats"
        case .trapezius: "Traps"
        case .rhomboids: "Rhomboids"
        case .lowerBack: "Lower Back"
        case .glutes: "Glutes"
        case .quadriceps: "Quads"
        case .hamstrings: "Hamstrings"
        case .adductors: "Adductors"
        case .abductors: "Abductors"
        case .calves: "Calves"
        case .neck: "Neck"
        }
    }

    var region: MuscleRegion {
        switch self {
        case .chest: .chest
        case .lats, .trapezius, .rhomboids, .lowerBack: .back
        case .anteriorDeltoid, .lateralDeltoid, .posteriorDeltoid: .shoulders
        case .biceps, .triceps, .forearms: .arms
        case .glutes, .quadriceps, .hamstrings, .adductors, .abductors, .calves: .legs
        case .abs, .obliques, .neck: .core
        }
    }
}

nonisolated enum MuscleRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest, back, shoulders, arms, legs, core

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .arms: "Arms"
        case .legs: "Legs"
        case .core: "Core"
        }
    }

    var muscles: [MuscleGroup] { MuscleGroup.allCases.filter { $0.region == self } }
}

// MARK: - Equipment and mechanic

nonisolated enum Equipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case band
    case smithMachine
    case ezBar
    case trapBar
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .machine: "Machine"
        case .cable: "Cable"
        case .bodyweight: "Bodyweight"
        case .kettlebell: "Kettlebell"
        case .band: "Band"
        case .smithMachine: "Smith Machine"
        case .ezBar: "EZ Bar"
        case .trapBar: "Trap Bar"
        case .other: "Other"
        }
    }

    /// Only straight-bar movements get the plate calculator — it is meaningless
    /// for a dumbbell or a stack machine.
    var usesLoadableBar: Bool {
        switch self {
        case .barbell, .ezBar, .trapBar, .smithMachine: true
        default: false
        }
    }
}

nonisolated enum Mechanic: String, Codable, CaseIterable, Identifiable, Sendable {
    case compound, isolation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compound: "Compound"
        case .isolation: "Isolation"
        }
    }
}

// MARK: - Tracking mode

/// Decides which fields a set row shows, so a plank never asks for reps and a
/// push-up never asks for weight.
nonisolated enum TrackingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case weightAndReps
    case bodyweightReps
    case bodyweightPlusAdded
    case repsOnly
    case timed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weightAndReps: "Weight & reps"
        case .bodyweightReps: "Bodyweight reps"
        case .bodyweightPlusAdded: "Bodyweight + added"
        case .repsOnly: "Reps only"
        case .timed: "Timed"
        }
    }

    var showsWeightField: Bool {
        switch self {
        case .weightAndReps, .bodyweightPlusAdded: true
        case .bodyweightReps, .repsOnly, .timed: false
        }
    }

    var showsRepsField: Bool {
        switch self {
        case .weightAndReps, .bodyweightReps, .bodyweightPlusAdded, .repsOnly: true
        case .timed: false
        }
    }

    var showsDurationField: Bool { self == .timed }

    /// Whether the session's body weight is added to the entered load.
    var includesBodyWeight: Bool {
        switch self {
        case .bodyweightReps, .bodyweightPlusAdded: true
        case .weightAndReps, .repsOnly, .timed: false
        }
    }

    /// `repsOnly` and `timed` contribute no tonnage at all — there is no load to count.
    var producesVolume: Bool {
        switch self {
        case .weightAndReps, .bodyweightReps, .bodyweightPlusAdded: true
        case .repsOnly, .timed: false
        }
    }

    /// A 1RM estimate only means something when an external load was moved.
    var supportsOneRepMax: Bool {
        switch self {
        case .weightAndReps, .bodyweightPlusAdded: true
        case .bodyweightReps, .repsOnly, .timed: false
        }
    }

    var label: String { displayName }
}

// MARK: - Set type

/// Warm-ups are excluded from volume, records and the rest timer. Including them
/// would inflate volume trends and award records for submaximal work.
nonisolated enum SetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case warmup
    case working
    case dropSet
    case toFailure
    case amrap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmup: "Warm-up"
        case .working: "Working"
        case .dropSet: "Drop set"
        case .toFailure: "To failure"
        case .amrap: "AMRAP"
        }
    }

    /// The short badge shown on a set row.
    var badge: String {
        switch self {
        case .warmup: "W"
        case .working: ""
        case .dropSet: "D"
        case .toFailure: "F"
        case .amrap: "A"
        }
    }

    var countsTowardVolume: Bool { self != .warmup }
    var canSetRecord: Bool { self != .warmup }
    var startsRestTimer: Bool { self != .warmup }

    /// Tapping the type chip cycles through the types in this order.
    var next: SetType {
        let all = SetType.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

// MARK: - Records

nonisolated enum RecordKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case heaviestWeight
    case bestOneRepMax
    case bestSetVolume
    case bestSessionVolume

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heaviestWeight: "Heaviest weight"
        case .bestOneRepMax: "Best est. 1RM"
        case .bestSetVolume: "Best set volume"
        case .bestSessionVolume: "Best session volume"
        }
    }

    var shortName: String {
        switch self {
        case .heaviestWeight: "Heaviest"
        case .bestOneRepMax: "1RM"
        case .bestSetVolume: "Set volume"
        case .bestSessionVolume: "Session volume"
        }
    }

    var symbolName: String {
        switch self {
        case .heaviestWeight: "scalemass"
        case .bestOneRepMax: "trophy"
        case .bestSetVolume: "square.stack.3d.up"
        case .bestSessionVolume: "chart.bar.fill"
        }
    }
}

// MARK: - Settings-backed choices

nonisolated enum WeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case kilograms, pounds

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kilograms: "Kilograms"
        case .pounds: "Pounds"
        }
    }

    var abbreviation: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        }
    }
}

nonisolated enum AppearanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
