import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
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
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            ComingSoonView(title: "Progress")
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            ComingSoonView(title: "Visit summary")
                .tabItem { Label("Report", systemImage: "doc.text") }
            ComingSoonView(title: "Learn")
                .tabItem { Label("Learn", systemImage: "book") }
        }
    }
}

/// Placeholder while screens are moved over from the first build.
struct ComingSoonView: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 28, weight: .heavy)).foregroundStyle(Palette.ink)
            Text("Coming in the next update.").foregroundStyle(Palette.muted)
            Spacer()
        }
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
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
