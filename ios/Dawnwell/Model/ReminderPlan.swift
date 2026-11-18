import Foundation

/// What to remind about, worked out from the profile and recent logs. Pure, so it can be tested.
///
/// "Smart" rules:
/// - No tablet reminder on a day the tablet is already logged as taken or skipped.
/// - The wait-over reminder fires at the end of today's wait, only once a tablet is logged.
/// - The protein check is skipped today when the target is already reached.
/// - The refill reminder fires once, at 10 AM the next day, when few tablets are left.
///
/// Wording only repeats what the user set from their label. It never suggests a dose.
struct ReminderPlan: Equatable {
    struct Item: Equatable {
        enum Kind: String { case tablet, waitOver, protein, refill }
        let kind: Kind
        let id: String
        let at: Date
        let title: String
        let body: String
    }

    struct Input {
        var remindTablet: Bool
        var remindWaitOver: Bool
        var remindProtein: Bool
        var remindRefill: Bool
        var doseHour: Int
        var doseMinute: Int
        var waitMinutes: Int
        var proteinTarget: Int
        var tabletsLeft: Int?
        /// Day keys with the tablet logged as taken or skipped.
        var loggedDays: Set<String>
        var takenAtToday: Date?
        var proteinToday: Int
    }

    /// Days ahead to schedule. iOS keeps at most 64 pending requests; this stays well under.
    static let daysAhead = 7
    static let proteinHour = 15
    static let refillHour = 10

    let items: [Item]

    static func make(_ i: Input, now: Date = Date(), calendar: Calendar = .current) -> ReminderPlan {
        var items: [Item] = []
        let today = calendar.startOfDay(for: now)
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> Date? {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        }

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let key = DayKey.of(day, calendar: calendar)
            if i.remindTablet, !i.loggedDays.contains(key), let t = at(offset, i.doseHour, i.doseMinute), t > now {
                items.append(Item(kind: .tablet, id: "tablet-\(key)", at: t, title: "Time for your tablet",
                                  body: "Take it as your label says, then wait \(i.waitMinutes) min before food, drinks or other medicines."))
            }
            if i.remindProtein, let t = at(offset, proteinHour, 0), t > now, !(offset == 0 && i.proteinToday >= i.proteinTarget) {
                let body = offset == 0 && i.proteinToday > 0
                    ? "You're at \(i.proteinToday) of \(i.proteinTarget) g today. A protein snack helps."
                    : "How's your protein today? Log what you've eaten."
                items.append(Item(kind: .protein, id: "protein-\(key)", at: t, title: "Protein check", body: body))
            }
        }

        if i.remindWaitOver, let taken = i.takenAtToday {
            let end = taken.addingTimeInterval(TimeInterval(i.waitMinutes * 60))
            if end > now {
                items.append(Item(kind: .waitOver, id: "wait-\(DayKey.of(taken, calendar: calendar))", at: end,
                                  title: "Your wait is over", body: "You can eat and drink now. Start with protein."))
            }
        }

        if i.remindRefill, let left = i.tabletsLeft, left <= Catalog.refillAt, let t = at(1, refillHour, 0) {
            items.append(Item(kind: .refill, id: "refill", at: t, title: "Running low on tablets",
                              body: left == 0 ? "You have no tablets left. Ask your pharmacy for a refill."
                                              : "\(left) tablet\(left == 1 ? "" : "s") left. Time to ask for a refill."))
        }
        return ReminderPlan(items: items.sorted { $0.at < $1.at })
    }
}
