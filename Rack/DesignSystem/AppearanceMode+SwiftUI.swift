import SwiftUI

extension AppearanceMode {
    /// Nil hands the decision back to the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
