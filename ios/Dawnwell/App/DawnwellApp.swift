import SwiftData
import SwiftUI

@main
struct DawnwellApp: App {
    private let container: ModelContainer?

    init() {
        if Persistence.isRunningTests {
            container = try? Persistence.makeContainer(inMemory: true)
        } else if Persistence.isDemo {
            let demo = try? Persistence.makeContainer(inMemory: true)
            var snapshot = DemoData.snapshot()
            // Design catalog states (debug builds only): nothing logged yet, or not set up yet.
            if DesignFlags.has("-design-empty") {
                snapshot.days = []; snapshot.foods = []; snapshot.symptoms = []; snapshot.weights = []
            }
            if DesignFlags.has("-design-onboarding") { snapshot.profile?.onboarded = false }
            if let demo { try? Repository(context: demo.mainContext).replaceAll(with: snapshot) }
            container = DesignFlags.has("-design-storage-problem") ? nil : demo
        } else if let opened = try? Persistence.openAppStore() {
            container = opened.0
            CloudStatus.storeSyncs = opened.syncing
        } else {
            container = nil
        }
        Analytics.start()
        if !Persistence.isSandboxed {
            NotificationActions.shared.container = container
            NotificationActions.shared.register()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView().designPresenter().modelContainer(container)
                } else {
                    // Never start over when saved data can't be opened: show this and write nothing.
                    StorageProblemView()
                }
            }
            .tint(Palette.accentText)
        }
    }
}
