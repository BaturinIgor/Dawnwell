import Foundation
import SwiftData

enum Persistence {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Opens the store. Throws instead of ever deleting or recreating a store it can't open.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(
            "Dawnwell",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, migrationPlan: DawnwellMigrationPlan.self, configurations: [config])
    }
}
