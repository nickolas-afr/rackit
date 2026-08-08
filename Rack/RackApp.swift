import SwiftData
import SwiftUI

@main
struct RackApp: App {
    private let container = ModelStore.makeContainer()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task { seed() }
        }
        .modelContainer(container)
    }

    private func seed() {
        do {
            try Seeder.runAll(context: container.mainContext, settings: settings)
        } catch {
            // Seeding is best-effort: a failure leaves the app usable with whatever is
            // already in the store rather than blocking launch.
            assertionFailure("Seeding failed: \(error)")
        }
    }
}
