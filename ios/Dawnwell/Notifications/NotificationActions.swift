import Foundation
import Observation
import SwiftData
import UserNotifications

/// The "I took it" button on the tablet reminder, banners while the app is open,
/// and which tab a tapped notification opens.
final class NotificationActions: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActions()
    static let tabletCategory = "dawnwell.tablet"
    static let tookIt = "dawnwell.tookIt"
    static let routeKey = "route"
    /// Stored on the phone only, like the analytics switch. On by default.
    static let weeklyKey = "remindWeekly"

    /// Set by the app at launch. A tap on "I took it" can start the app in the background, before any view.
    @MainActor var container: ModelContainer?

    static var remindWeekly: Bool {
        UserDefaults.standard.object(forKey: weeklyKey) as? Bool ?? true
    }

    @MainActor
    func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let took = UNNotificationAction(identifier: Self.tookIt, title: String(localized: "I took it"), options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.tabletCategory, actions: [took],
                                                                 intentIdentifiers: [], options: [])])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let route = response.notification.request.content.userInfo[Self.routeKey] as? String
        await MainActor.run {
            if action == Self.tookIt {
                self.logTaken()
            } else if action == UNNotificationDefaultActionIdentifier, let route {
                AppRouter.shared.open(route)
            }
        }
    }

    @MainActor
    private func logTaken() {
        guard let container else { return }
        let repo = Repository(context: container.mainContext)
        let now = Date()
        guard repo.logTabletTaken(at: now) else { return }
        let p = repo.profile()
        WaitActivityController.start(takenAt: now, waitMinutes: p.waitMinutes, medication: p.medication.label)
        Analytics.send(.tabletTaken, ["from": "notification"])
        Task { await ReminderScheduler.sync(repo: repo) }
    }
}

/// Which tab to show. A notification tap sets it; the tab bar follows.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    static let progress = "progress"

    var tab = DesignFlags.initialTab

    func open(_ route: String) {
        if route == Self.progress { tab = 1 }
    }
}
