import Foundation
import SwiftData
import UserNotifications

/// Replaces Dawnwell's pending notifications with the current plan. Safe to call often.
@MainActor
enum ReminderScheduler {
    static let prefix = "dawnwell."

    static func input(repo: Repository, today: String = DayKey.today()) -> ReminderPlan.Input {
        let p = repo.profile()
        let days = (try? repo.context.fetch(FetchDescriptor<DayLog>())) ?? []
        let logged = Set(days.filter { $0.takenAt != nil || $0.skipped }.map(\.day))
        let todayLog = days.first { $0.day == today }
        return ReminderPlan.Input(
            remindTablet: p.remindTablet, remindWaitOver: p.remindWaitOver, remindProtein: p.remindProtein,
            remindRefill: p.remindRefill, doseHour: p.doseHour, doseMinute: p.doseMinute, waitMinutes: p.waitMinutes,
            proteinTarget: p.proteinTarget, tabletsLeft: p.tabletsLeft, loggedDays: logged,
            takenAtToday: todayLog?.takenAt, proteinToday: repo.foods(today).reduce(0) { $0 + $1.protein },
            remindWeekly: NotificationActions.remindWeekly)
    }

    static func sync(repo: Repository) async {
        // Read without creating: during onboarding there may be no profile yet.
        let existing = (try? repo.context.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])))?.first
        guard existing?.onboarded == true else { return }
        let plan = ReminderPlan.make(input(repo: repo))
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            guard !plan.items.isEmpty, (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
        } else if settings.authorizationStatus == .denied {
            return
        }
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let calendar = Calendar.current
        for item in plan.items {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            if item.kind == .waitOver || item.kind == .tablet { content.interruptionLevel = .timeSensitive }
            if item.kind == .tablet { content.categoryIdentifier = NotificationActions.tabletCategory }
            if item.kind == .weekly { content.userInfo = [NotificationActions.routeKey: AppRouter.progress] }
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.at)
            let request = UNNotificationRequest(identifier: prefix + item.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }
}
