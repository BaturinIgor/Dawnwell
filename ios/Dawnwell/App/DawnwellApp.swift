import SwiftData
import SwiftUI

@main
struct DawnwellApp: App {
    private let container: ModelContainer?

    init() {
        if Persistence.isRunningTests {
            container = try? Persistence.makeContainer(inMemory: true)
        } else if let (c, syncing) = try? Persistence.openAppStore() {
            container = c
            CloudStatus.storeSyncs = syncing
        } else {
            container = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView().modelContainer(container)
                } else {
                    // Never start over when saved data can't be opened: show this and write nothing.
                    StorageProblemView()
                }
            }
            .tint(Palette.accentText)
        }
    }
}
