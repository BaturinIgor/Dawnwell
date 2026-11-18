import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    var body: some View {
        Group {
            if profiles.first?.onboarded == true {
                MainTabs()
            } else {
                OnboardingView()
            }
        }
        .background(Palette.bg)
        .onChange(of: scenePhase, initial: true) { _, phase in
            // One local copy a day, taken when the app comes to the front.
            guard !Persistence.isRunningTests else { return }
            if phase == .active {
                DataSafety.takeDailyCopy(repo: Repository(context: context), copies: .standard)
                WaitActivityController.tidy()
                let repo = Repository(context: context)
                Task { await HealthWeight.importNow(repo: repo) }
            }
            if phase != .inactive { syncReminders() }
        }
        // Any saved change (tablet taken, food logged, settings) can change what to remind about.
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            guard !Persistence.isRunningTests else { return }
            syncReminders()
        }
    }

    private func syncReminders() {
        let repo = Repository(context: context)
        Task { await ReminderScheduler.sync(repo: repo) }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            ReportView()
                .tabItem { Label("Report", systemImage: "doc.text") }
            LearnView()
                .tabItem { Label("Learn", systemImage: "book") }
        }
    }
}

struct StorageProblemView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("We couldn't open your data")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Palette.ink)
            Text("Your logs are still on this phone and nothing was deleted. Close Dawnwell completely and open it again. If this keeps happening, update the app or contact support.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.inkSoft)
        }
        .card()
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
    }
}
