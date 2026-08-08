import CoreGraphics
import Foundation

nonisolated enum BodySide: String, CaseIterable, Identifiable, Sendable {
    case front, back

    var id: String { rawValue }
    var displayName: String { self == .front ? "Front" : "Back" }
}

/// One shaded region of the diagram.
nonisolated struct MuscleRegionShape: Identifiable, Sendable {
    let id: String
    let muscle: MuscleGroup
    let rect: CGRect
    let isEllipse: Bool
    let cornerRadius: CGFloat
}

/// The body diagrams, expressed as plain rectangles and ellipses in a fixed design
/// space and scaled at draw time. No image assets: the app ships no artwork, and the
/// shapes tint cleanly in both colour schemes.
nonisolated enum BodyDiagram {

    /// Everything below is in this coordinate space.
    static let designSize = CGSize(width: 100, height: 220)

    static func shapes(for side: BodySide) -> [MuscleRegionShape] {
        switch side {
        case .front: frontShapes
        case .back: backShapes
        }
    }

    /// Head and limb outlines, drawn unshaded so the shaded muscles read as a body.
    static func outlineRects(for side: BodySide) -> [CGRect] {
        [
            CGRect(x: 42, y: 4, width: 16, height: 18),   // head
            CGRect(x: 46, y: 21, width: 8, height: 6),    // neck
            CGRect(x: 40, y: 196, width: 8, height: 18),  // left shin/foot
            CGRect(x: 52, y: 196, width: 8, height: 18),  // right shin/foot
            CGRect(x: 14, y: 108, width: 8, height: 12),  // left hand
            CGRect(x: 78, y: 108, width: 8, height: 12),  // right hand
        ]
    }

    // MARK: Front

    private static let frontShapes: [MuscleRegionShape] = [
        mirrored(.chest, x: 34, y: 40, width: 15, height: 16, radius: 5),
        mirrored(.anteriorDeltoid, x: 22, y: 36, width: 12, height: 13, ellipse: true),
        mirrored(.lateralDeltoid, x: 17, y: 40, width: 8, height: 12, ellipse: true),
        mirrored(.biceps, x: 19, y: 56, width: 9, height: 22, ellipse: true),
        mirrored(.forearms, x: 16, y: 80, width: 9, height: 26, ellipse: true),
        [
            MuscleRegionShape(id: "abs", muscle: .abs,
                              rect: CGRect(x: 42, y: 60, width: 16, height: 32),
                              isEllipse: false, cornerRadius: 5),
        ],
        mirrored(.obliques, x: 33, y: 62, width: 8, height: 28, radius: 4),
        mirrored(.quadriceps, x: 34, y: 108, width: 14, height: 48, ellipse: true),
        mirrored(.adductors, x: 44, y: 104, width: 6, height: 34, radius: 3),
        mirrored(.abductors, x: 28, y: 102, width: 7, height: 24, radius: 3),
        [
            MuscleRegionShape(id: "neck", muscle: .neck,
                              rect: CGRect(x: 44, y: 24, width: 12, height: 8),
                              isEllipse: true, cornerRadius: 0),
        ],
    ].flatMap { $0 }

    // MARK: Back

    private static let backShapes: [MuscleRegionShape] = [
        [
            MuscleRegionShape(id: "trapezius", muscle: .trapezius,
                              rect: CGRect(x: 36, y: 28, width: 28, height: 26),
                              isEllipse: false, cornerRadius: 8),
            MuscleRegionShape(id: "rhomboids", muscle: .rhomboids,
                              rect: CGRect(x: 40, y: 52, width: 20, height: 14),
                              isEllipse: false, cornerRadius: 4),
            MuscleRegionShape(id: "lowerBack", muscle: .lowerBack,
                              rect: CGRect(x: 40, y: 82, width: 20, height: 18),
                              isEllipse: false, cornerRadius: 5),
        ],
        mirrored(.posteriorDeltoid, x: 21, y: 36, width: 12, height: 13, ellipse: true),
        mirrored(.lats, x: 32, y: 56, width: 16, height: 30, radius: 6),
        mirrored(.triceps, x: 19, y: 56, width: 9, height: 22, ellipse: true),
        mirrored(.forearms, x: 16, y: 80, width: 9, height: 26, ellipse: true),
        mirrored(.glutes, x: 34, y: 100, width: 15, height: 20, radius: 6),
        mirrored(.hamstrings, x: 34, y: 122, width: 14, height: 40, ellipse: true),
        mirrored(.calves, x: 35, y: 164, width: 12, height: 30, ellipse: true),
    ].flatMap { $0 }

    /// Most muscles come in pairs; this places both and mirrors the right one about the
    /// vertical centre line so the diagram stays symmetrical.
    private static func mirrored(
        _ muscle: MuscleGroup,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat = 0,
        ellipse: Bool = false
    ) -> [MuscleRegionShape] {
        let mirroredX = designSize.width - x - width
        return [
            MuscleRegionShape(id: "\(muscle.rawValue)-l",
                              muscle: muscle,
                              rect: CGRect(x: x, y: y, width: width, height: height),
                              isEllipse: ellipse,
                              cornerRadius: radius),
            MuscleRegionShape(id: "\(muscle.rawValue)-r",
                              muscle: muscle,
                              rect: CGRect(x: mirroredX, y: y, width: width, height: height),
                              isEllipse: ellipse,
                              cornerRadius: radius),
        ]
    }

    /// Muscles the diagram can actually show on a given side.
    static func muscles(on side: BodySide) -> Set<MuscleGroup> {
        Set(shapes(for: side).map(\.muscle))
    }
}
