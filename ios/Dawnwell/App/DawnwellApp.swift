import SwiftData
import SwiftUI

@main
struct DawnwellApp: App {
    private let container: ModelContainer?

    init() {
        container = try? Persistence.makeContainer(inMemory: Persistence.isRunningTests)
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
