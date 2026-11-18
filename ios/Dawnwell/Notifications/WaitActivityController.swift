import ActivityKit
import Foundation

/// Starts and ends the Lock Screen wait timer. Does nothing where Live Activities are off or unsupported.
@MainActor
enum WaitActivityController {
    static func start(takenAt: Date, waitMinutes: Int, medication: String) {
        end()
        guard waitMinutes > 0, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let ends = WaitTimer.endsAt(takenAt: takenAt, waitMinutes: waitMinutes)
        guard !WaitTimer.isOver(endsAt: ends, now: Date()) else { return }
        let content = ActivityContent(state: WaitAttributes.ContentState(takenAt: takenAt, endsAt: ends),
                                      staleDate: ends.addingTimeInterval(WaitTimer.lingerAfterEnd))
        _ = try? Activity.request(attributes: WaitAttributes(medication: medication), content: content, pushType: nil)
    }

    /// End every wait timer now, for example when a tablet log is undone.
    static func end() {
        for activity in Activity<WaitAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// End timers whose wait is over, leaving the "You can eat now" card up for a short while.
    static func tidy(now: Date = Date()) {
        for activity in Activity<WaitAttributes>.activities where WaitTimer.isOver(endsAt: activity.content.state.endsAt, now: now) {
            let state = activity.content.state
            Task {
                await activity.end(ActivityContent(state: state, staleDate: nil),
                                   dismissalPolicy: .after(state.endsAt.addingTimeInterval(WaitTimer.lingerAfterEnd)))
            }
        }
    }
}
