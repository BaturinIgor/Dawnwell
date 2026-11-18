import Foundation
import SwiftData

enum Persistence {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// The user's own private iCloud database. Dawnwell has no server; Apple stores it in the user's iCloud.
    static let cloudContainer = "iCloud.com.dawnwell.app"

    /// Opens the store. Throws instead of ever deleting or recreating a store it can't open.
    static func makeContainer(inMemory: Bool = false, cloud: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(
            "Dawnwell",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            cloudKitDatabase: cloud && !inMemory ? .private(cloudContainer) : .none
        )
        return try ModelContainer(for: schema, migrationPlan: DawnwellMigrationPlan.self, configurations: [config])
    }

    /// Open the same on-disk store with iCloud sync, or without it if iCloud can't be set up
    /// (for example on a build without the iCloud capability). Both open the same file; neither deletes anything.
    static func openAppStore() throws -> (ModelContainer, syncing: Bool) {
        if let synced = try? makeContainer(cloud: true) { return (synced, true) }
        return (try makeContainer(cloud: false), false)
    }
}
