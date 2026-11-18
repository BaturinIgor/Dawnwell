import CoreData
import Foundation
import SwiftData

/// Creates Dawnwell's record types in the iCloud container's Development environment.
///
/// iCloud only syncs record types that exist in the container's Production schema, and
/// Production can't create them on the fly. They are made once in Development by this code,
/// then copied to Production with "Deploy Schema Changes" in CloudKit Console.
///
/// It runs only in a build made with the `CLOUDKIT_SCHEMA_INIT` flag (the TestFlight workflow's
/// "Development" option). It uses a throwaway store in the caches folder, never the user's data.
enum CloudSchema {
    /// The same model SwiftData stores, as Core Data sees it.
    static func managedObjectModel() -> NSManagedObjectModel? {
        NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models)
    }

    static var isEnabledInThisBuild: Bool {
        #if CLOUDKIT_SCHEMA_INIT
        return true
        #else
        return false
        #endif
    }

    /// Set after a successful run, so it runs once per install.
    static let doneKey = "cloudSchemaInitialized"

    static func initializeIfNeeded() {
        guard isEnabledInThisBuild, !UserDefaults.standard.bool(forKey: doneKey),
              let model = managedObjectModel() else { return }
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cloud-schema", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let description = NSPersistentStoreDescription(url: dir.appendingPathComponent("schema.sqlite"))
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Persistence.cloudContainer)
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(name: "DawnwellSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loaded = true
        container.loadPersistentStores { _, error in if error != nil { loaded = false } }
        guard loaded else { return }
        do {
            try container.initializeCloudKitSchema()
            UserDefaults.standard.set(true, forKey: doneKey)
        } catch {
            // Not signed in to iCloud or offline: try again next launch.
        }
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
        try? FileManager.default.removeItem(at: dir)
    }
}
