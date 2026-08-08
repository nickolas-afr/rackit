import Foundation
import SwiftData

/// The app's SwiftData stack. Local-only: no CloudKit container, no sync, no network.
enum ModelStore {
    static let schema = Schema([
        Exercise.self,
        Split.self,
        SplitItem.self,
        Session.self,
        SessionExercise.self,
        SetEntry.self,
        PersonalRecord.self,
        BodyWeightEntry.self,
    ])

    /// The on-disk container used by the running app.
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A store that cannot be opened is unrecoverable for a local-only app.
            // Fail loudly in development rather than silently losing the user's log.
            fatalError("Could not open the Rack data store: \(error)")
        }
    }

    /// A throwaway in-memory container, for tests and previews.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
