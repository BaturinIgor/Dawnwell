import Foundation

/// A believable five weeks of use, for App Store screenshots. Shown only when the app is
/// launched with `-demo`; it lives in memory and never touches the user's store.
enum DemoData {
    static let launchArgument = "-demo"

    static func snapshot(now: Date = Date(), calendar: Calendar = .current) -> Snapshot {
        let dates = DayKey.last(35, endingAt: now, calendar: calendar)
        let todayKey = DayKey.of(now, calendar: calendar)
        func at(_ day: Date, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        var days: [Snapshot.DayData] = []
        var foods: [Snapshot.FoodData] = []
        var symptoms: [Snapshot.SymptomData] = []
        var weights: [Snapshot.WeightData] = []

        for (i, d) in dates.enumerated() {
            let key = DayKey.of(d, calendar: calendar)
            let isToday = key == todayKey
            // Today: the tablet was taken 12 minutes ago, so the wait timer is running.
            let taken = isToday ? now.addingTimeInterval(-12 * 60) : (i % 11 == 6 ? nil : at(d, 7, 10 + i % 15))
            days.append(.init(day: key, takenAt: taken, skipped: false,
                              water: isToday ? 2 : 5 + i % 4, fiber: isToday ? 4 : 14 + i % 9,
                              foodNoise: max(1, 4 - i / 10), strength: i % 3 == 0 ? 25 : 0,
                              updatedAt: isToday ? now : at(d, 21)))
            // Nothing eaten yet today: the empty-stomach wait is still running.
            let meals: [(String, Int, String, Int)] = isToday
                ? []
                : [("Eggs", 12, "Breakfast", 8), ("Chicken breast", 31 + i % 8, "Lunch", 13),
                   ("Protein shake", 25, "Snack", 16), ("Salmon", 22 + i % 6, "Dinner", 19)]
            for m in meals { foods.append(.init(day: key, name: m.0, protein: m.1, meal: m.2, at: at(d, m.3))) }
            if i % 4 == 1 && i < 24 {
                symptoms.append(.init(day: key, kind: "nausea", severity: i < 10 ? 3 : 2,
                                      triggers: i < 10 ? ["Fatty food"] : [], note: "", at: at(d, 20)))
            }
            if i % 3 == 0 || isToday {
                let lb = 212 - Double(i) * 0.36
                weights.append(.init(day: key, value: (lb * 10).rounded() / 10, at: at(d, 7)))
            }
        }

        let first = dates.first ?? now
        return Snapshot(
            profile: .init(createdAt: first, onboarded: true, medication: Medication.oralSemaglutide.rawValue,
                           doseLabel: "14 mg", doseHour: 7, doseMinute: 0, waitMinutes: 30,
                           proteinTarget: 100, fiberTarget: 25, waterTarget: 8, weightUnit: "lb",
                           startWeight: 212, goalWeight: 185, tabletsLeft: 21,
                           remindTablet: true, remindWaitOver: true, remindProtein: true, remindRefill: true,
                           questions: "Is it OK to take it later on weekends?"),
            days: days, foods: foods, symptoms: symptoms, weights: weights,
            doses: [.init(label: "7 mg", from: DayKey.of(first, calendar: calendar), at: first)]
        )
    }
}
