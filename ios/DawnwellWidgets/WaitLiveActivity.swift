import ActivityKit
import SwiftUI
import WidgetKit

@main
struct DawnwellWidgets: WidgetBundle {
    var body: some Widget {
        WaitLiveActivity()
    }
}

/// Colors from the "Morning" palette. The widget can't see the app's theme file.
private enum Ink {
    static let accent = Color(red: 15 / 255, green: 107 / 255, blue: 92 / 255)
    static let mint = Color(red: 92 / 255, green: 200 / 255, blue: 174 / 255)
}

struct WaitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WaitAttributes.self) { context in
            LockScreenWait(state: context.state, medication: context.attributes.medication)
                .activityBackgroundTint(Ink.accent)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Wait", systemImage: "fork.knife").font(.headline).foregroundStyle(Ink.mint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: s.takenAt...s.endsAt, countsDown: true)
                        .font(.title2.weight(.heavy)).monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(timerInterval: s.takenAt...s.endsAt, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                            .tint(Ink.mint)
                        Text("Breakfast at \(s.endsAt.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "fork.knife").foregroundStyle(Ink.mint)
            } compactTrailing: {
                Text(timerInterval: s.takenAt...s.endsAt, countsDown: true)
                    .monospacedDigit().frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "fork.knife").foregroundStyle(Ink.mint)
            }
            .keylineTint(Ink.mint)
        }
    }
}

private struct LockScreenWait: View {
    let state: WaitAttributes.ContentState
    let medication: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Wait before food").font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(medication).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
            }
            if state.endsAt > Date() {
                Text(timerInterval: state.takenAt...state.endsAt, countsDown: true)
                    .font(.system(size: 40, weight: .heavy)).monospacedDigit().foregroundStyle(.white)
                ProgressView(timerInterval: state.takenAt...state.endsAt, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(.white)
                Text("Breakfast at \(state.endsAt.formatted(date: .omitted, time: .shortened)). No food, coffee or other medicines yet.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.85))
            } else {
                Text("You can eat now").font(.system(size: 28, weight: .heavy)).foregroundStyle(.white)
                Text("Start with protein.").font(.footnote).foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(16)
    }
}
