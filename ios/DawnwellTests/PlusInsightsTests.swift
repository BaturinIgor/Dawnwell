import XCTest
@testable import Dawnwell

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()
private let today = DateComponents(calendar: cal, year: 2026, month: 11, day: 18, hour: 12).date!

/// `i` days before today, at the given hour and minute.
private func at(_ i: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: today))!
    return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
}
private func key(_ i: Int) -> String { DayKey.of(at(i, 12), calendar: cal) }

private func profile(wait: Int = 30) -> Snapshot.ProfileData {
    .init(createdAt: at(30, 8), onboarded: true, medication: "oral-semaglutide", doseLabel: "7 mg",
          doseHour: 8, doseMinute: 0, waitMinutes: wait, proteinTarget: 90, fiberTarget: 25, waterTarget: 8,
          weightUnit: "kg", startWeight: nil, goalWeight: nil, tabletsLeft: nil,
          remindTablet: true, remindWaitOver: true, remindProtein: true, remindRefill: false, questions: "")
}

/// Ten days of logs. Salmon on the 4 most recent days, nausea on 3 of them and on 1 of the other 6 days,
/// with "Fatty food" marked on 3 of the 4 nausea entries. Breakfast always after the wait.
private func tenDays() -> Snapshot {
    var days: [Snapshot.DayData] = [], foods: [Snapshot.FoodData] = [], symptoms: [Snapshot.SymptomData] = []
    for i in 0..<10 {
        days.append(.init(day: key(i), takenAt: at(i, 8), skipped: false, water: 6, fiber: 10, foodNoise: 2,
                          strength: 0, updatedAt: at(i, 9)))
        foods.append(.init(day: key(i), name: "Eggs", protein: 12, meal: "Breakfast", at: at(i, 9)))
        if i < 4 { foods.append(.init(day: key(i), name: "Salmon", protein: 30, meal: "Dinner", at: at(i, 19))) }
    }
    for (n, i) in [0, 1, 2, 7].enumerated() {
        symptoms.append(.init(day: key(i), kind: "nausea", severity: 3, triggers: n < 3 ? ["Fatty food"] : ["Not sure"],
                              note: "", at: at(i, 21)))
    }
    return Snapshot(profile: profile(), days: days, foods: foods, symptoms: symptoms, weights: [], doses: [])
}

final class PlusInsightsTests: XCTestCase {
    func testFindsMarkedTriggerAndFood() {
        let i = Insights.make(from: tenDays(), today: today, calendar: cal)
        XCTAssertTrue(i.hasEnoughData)
        XCTAssertEqual(i.loggedDays, 10)
        XCTAssertEqual(i.findings, [
            .trigger(.nausea, trigger: "Fatty food", hits: 3, of: 4),
            .food(.nausea, food: "Salmon", hits: 3, of: 4, otherHits: 1, otherOf: 6),
        ])
    }

    func testFindingTextLeadsWithTheSymptom() {
        let food = Insights.Finding.food(.nausea, food: "Greek yogurt, plain", hits: 3, of: 4, otherHits: 1, otherOf: 6)
        XCTAssertEqual(food.text, "Nausea: on 3 of 4 days with Greek yogurt, and on 1 of 6 other days.")
        XCTAssertEqual(Insights.Finding.trigger(.nausea, trigger: "Fatty food", hits: 3, of: 4).text,
                       "Nausea: “Fatty food” marked on 3 of 4 entries.")
    }

    func testWeeksCountSymptomDaysOldestFirst() {
        let i = Insights.make(from: tenDays(), today: today, calendar: cal)
        XCTAssertEqual(i.symptomWeeks, [0, 0, 1, 3])
    }

    func testEatingBeforeTheWaitIsOver() {
        var s = tenDays()
        // Remove the food and trigger patterns, then make breakfast early on the 4 nausea-heavy days.
        s.foods = s.foods.filter { $0.name == "Eggs" }
        s.symptoms = s.symptoms.map { var e = $0; e.triggers = []; return e }
        for (n, f) in s.foods.enumerated() {
            if let i = (0..<4).first(where: { key($0) == f.day }) { s.foods[n].at = at(i, 8, 10) }
        }
        let i = Insights.make(from: s, today: today, calendar: cal)
        XCTAssertEqual(i.findings, [.ateEarly(.nausea, hits: 3, of: 4, otherHits: 1, otherOf: 6)])
    }

    func testNotEnoughDataShowsNothing() {
        var s = tenDays()
        let recent = Set((0..<3).map(key))
        s.days = s.days.filter { recent.contains($0.day) }
        s.foods = s.foods.filter { recent.contains($0.day) }
        s.symptoms = s.symptoms.filter { recent.contains($0.day) }
        let i = Insights.make(from: s, today: today, calendar: cal)
        XCTAssertFalse(i.hasEnoughData)
        XCTAssertEqual(i.loggedDays, 3)
    }

    func testFeelingGoodIsNotASymptom() {
        var s = tenDays()
        s.symptoms = (0..<10).map { .init(day: key($0), kind: "good", severity: 1, triggers: [], note: "", at: at($0, 20)) }
        let i = Insights.make(from: s, today: today, calendar: cal)
        XCTAssertEqual(i.findings, [])
        XCTAssertEqual(i.symptomWeeks, [0, 0, 0, 0])
    }

    func testNeverTalksAboutDoses() {
        let i = Insights.make(from: tenDays(), today: today, calendar: cal)
        for f in i.findings { XCTAssertFalse(f.text.lowercased().contains("dose"), f.text) }
    }
}

final class LongSummaryTests: XCTestCase {
    func testNinetyDaySummaryReachesFurtherBack() {
        var s = tenDays()
        s.days.append(.init(day: key(60), takenAt: at(60, 8), skipped: false, water: 0, fiber: 0, foodNoise: nil,
                            strength: 0, updatedAt: at(60, 9)))
        let short = VisitSummary.make(from: s, today: today, calendar: cal)
        let long = VisitSummary.make(from: s, today: today, calendar: cal, span: VisitSummary.plusSpan)
        XCTAssertEqual(short.span, 30)
        XCTAssertEqual(short.daysTaken, 10)
        XCTAssertEqual(long.span, 90)
        XCTAssertEqual(long.daysTaken, 11)
        XCTAssertTrue(long.text.contains("Tablet logged taken on 11 of 90 days"))
    }
}
