import ActivityKit
import Foundation

/// The empty-stomach wait shown on the Lock Screen and in the Dynamic Island.
/// Compiled into both the app and the widget extension.
struct WaitAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var takenAt: Date
        var endsAt: Date
    }

    var medication: String
}

/// Pure timing rules for the wait, shared by the app, the widget and the tests.
enum WaitTimer {
    static func endsAt(takenAt: Date, waitMinutes: Int) -> Date {
        takenAt.addingTimeInterval(TimeInterval(max(0, waitMinutes) * 60))
    }

    /// 0 at the moment the tablet is taken, 1 when the wait is over.
    static func progress(takenAt: Date, endsAt: Date, now: Date) -> Double {
        let total = endsAt.timeIntervalSince(takenAt)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(takenAt) / total))
    }

    static func isOver(endsAt: Date, now: Date) -> Bool { now >= endsAt }

    /// Keep the finished activity on the Lock Screen a little while, so "You can eat now" is seen.
    static let lingerAfterEnd: TimeInterval = 15 * 60
}
