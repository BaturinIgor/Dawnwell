import XCTest
@testable import Dawnwell

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()
/// A Wednesday.
private let today = DateComponents(calendar: cal, year: 2026, month: 11, day: 18, hour: 12).date!

private func at(_ i: Int, _ hour: Int = 12) -> Date {
    cal.date(bySettingHour: hour, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: today))!)!
}
private func key(_ i: Int) -> String { DayKey.of(at(i), calendar: cal) }

private func profile(createdDaysAgo: Int = 60) -> Snapshot.ProfileData {
    .init(createdAt: at(createdDaysAgo, 8), onboarded: true, medication: "oral-semaglutide", doseLabel: "7 mg",
          doseHour: 8, doseMinute: 0, waitMinutes: 30, proteinTarget: 90, fiberTarget: 25, waterTarget: 8,
          weightUnit: "kg", startWeight: nil, goalWeight: nil, tabletsLeft: nil,
          remindTablet: true, remindWaitOver: true, remindProtein: true, remindRefill: false, questions: "")
}

private func symptom(_ i: Int, _ kind: String = "nausea", _ severity: Int = 3, note: String = "") -> Snapshot.SymptomData {
    .init(day: key(i), kind: kind, severity: severity, triggers: [], note: note, at: at(i, 20))
}

private func snapshot(days: [Snapshot.DayData] = [], foods: [Snapshot.FoodData] = [], symptoms: [Snapshot.SymptomData] = [],
                      weights: [Snapshot.WeightData] = [], doses: [Snapshot.DoseData] = [], created: Int = 60) -> Snapshot {
    Snapshot(profile: profile(createdDaysAgo: created), days: days, foods: foods, symptoms: symptoms, weights: weights, doses: doses)
}

final class DoseHistoryTests: XCTestCase {
    func testPeriodsSplitAtEachChangeNewestFirst() {
        let s = snapshot(
            symptoms: [symptom(30), symptom(29, "heartburn", 2), symptom(5), symptom(4, "good", 1)],
            weights: [.init(day: key(40), value: 90, at: at(40)), .init(day: key(21), value: 87.5, at: at(21)),
                      .init(day: key(20), value: 87, at: at(20)), .init(day: key(1), value: 85, at: at(1))],
            doses: [.init(label: "3 mg daily", from: key(40), at: at(40)), .init(label: "7 mg daily", from: key(20), at: at(20))])
        let h = DoseHistory.make(from: s, today: today, calendar: cal)
        XCTAssertEqual(h.periods.count, 2)
        let now = h.periods[0], before = h.periods[1]
        XCTAssertEqual(now.label, "7 mg daily")
        XCTAssertEqual(now.days, 21)
        XCTAssertEqual(h.currentDay, 21)
        XCTAssertEqual(now.through, key(0))
        XCTAssertEqual(now.symptomDays, 1, "feeling good is not a symptom")
        XCTAssertEqual(now.weightChange ?? 0, -2, accuracy: 0.001)
        XCTAssertEqual(before.days, 20)
        XCTAssertEqual(before.through, key(21))
        XCTAssertEqual(before.symptomDays, 2)
        XCTAssertEqual(before.nauseaDays, 1)
        XCTAssertEqual(before.averageSeverity ?? 0, 2.5, accuracy: 0.001)
        XCTAssertEqual(before.weightChange ?? 0, -2.5, accuracy: 0.001)
    }

    func testSameDayChangesKeepTheLastOneAndFutureChangesAreIgnored() {
        let s = snapshot(doses: [.init(label: "3 mg daily", from: key(10), at: at(10, 8)),
                                 .init(label: "7 mg daily", from: key(10), at: at(10, 9)),
                                 .init(label: "14 mg daily", from: DayKey.of(cal.date(byAdding: .day, value: 3, to: today)!, calendar: cal), at: today)])
        let h = DoseHistory.make(from: s, today: today, calendar: cal)
        XCTAssertEqual(h.periods.map(\.label), ["7 mg daily"])
        XCTAssertEqual(h.currentDay, 11)
    }

    func testTwelveWeeksWithDoseChangeMarked() {
        let s = snapshot(symptoms: [symptom(0), symptom(1), symptom(1, "heartburn"), symptom(8)],
                         doses: [.init(label: "7 mg daily", from: key(9), at: at(9))])
        let h = DoseHistory.make(from: s, today: today, calendar: cal)
        XCTAssertEqual(h.weeks.count, DoseHistory.weekCount)
        XCTAssertEqual(h.weeks.last?.symptomDays, 2, "two days, even with two symptoms on one of them")
        XCTAssertEqual(h.weeks[h.weeks.count - 2].symptomDays, 1)
        XCTAssertEqual(h.weeks[h.weeks.count - 2].doseChange, "7 mg daily")
        XCTAssertNil(h.weeks.last?.doseChange)
    }

    func testNoDosesNoPeriods() {
        XCTAssertTrue(DoseHistory.make(from: snapshot(), today: today, calendar: cal).periods.isEmpty)
        XCTAssertNil(DoseHistory.make(from: snapshot(), today: today, calendar: cal).currentDay)
    }
}

final class WeekSummaryTests: XCTestCase {
    func testThisWeekAgainstTheWeekBefore() {
        var days: [Snapshot.DayData] = []
        for i in 0..<14 {
            days.append(.init(day: key(i), takenAt: i == 2 || i == 9 ? nil : at(i, 8), skipped: i == 9, water: i < 3 ? 8 : 2,
                              fiber: 0, foodNoise: nil, strength: i == 0 ? 1 : 0, updatedAt: at(i)))
        }
        let foods: [Snapshot.FoodData] = [
            .init(day: key(0), name: "Eggs", protein: 60, meal: "Breakfast", at: at(0, 9)),
            .init(day: key(0), name: "Tuna", protein: 40, meal: "Lunch", at: at(0, 13)),
            .init(day: key(1), name: "Eggs", protein: 50, meal: "Breakfast", at: at(1, 9)),
            .init(day: key(10), name: "Chicken", protein: 95, meal: "Dinner", at: at(10, 19)),
        ]
        let weights: [Snapshot.WeightData] = [.init(day: key(10), value: 88, at: at(10)), .init(day: key(1), value: 87.2, at: at(1))]
        let s = snapshot(days: days, foods: foods, symptoms: [symptom(0), symptom(3, "heartburn"), symptom(4, "heartburn"), symptom(8)],
                         weights: weights)
        let w = WeekSummary.make(from: s, today: today, calendar: cal)
        XCTAssertEqual(w.start, key(6))
        XCTAssertEqual(w.end, key(0))
        XCTAssertEqual(w.now.trackedDays, 7)
        XCTAssertEqual(w.now.taken, 6)
        XCTAssertEqual(w.now.skipped, 0)
        XCTAssertEqual(w.notLogged, 1)
        XCTAssertEqual(w.before.taken, 6)
        XCTAssertEqual(w.before.skipped, 1)
        XCTAssertEqual(w.now.proteinHitDays, 1)
        XCTAssertEqual(w.now.proteinAverage, 75)
        XCTAssertEqual(w.before.proteinHitDays, 1)
        XCTAssertEqual(w.now.waterHitDays, 3)
        XCTAssertEqual(w.now.strengthDays, 1)
        XCTAssertEqual(w.now.symptomDays, 3)
        XCTAssertEqual(w.now.topSymptom, .heartburn)
        XCTAssertEqual(w.before.symptomDays, 1)
        XCTAssertEqual(w.weightChange ?? 0, -0.8, accuracy: 0.001)
        XCTAssertEqual(w.unit, .kg)
    }

    func testDaysBeforeSetupAreNotCounted() {
        let w = WeekSummary.make(from: snapshot(created: 2), today: today, calendar: cal)
        XCTAssertEqual(w.now.trackedDays, 3)
        XCTAssertEqual(w.before.trackedDays, 0)
        XCTAssertEqual(w.notLogged, 3)
        XCTAssertNil(w.weightChange)
        XCTAssertNil(w.now.topSymptom)
    }

    func testTopSymptomTieGoesToTheFirstKind() {
        let w = WeekSummary.make(from: snapshot(symptoms: [symptom(0, "heartburn"), symptom(1, "nausea")]), today: today, calendar: cal)
        XCTAssertEqual(w.now.topSymptom, .nausea)
    }
}

final class CSVExportTests: XCTestCase {
    func testFieldsAreQuotedAndFormulasDefused() {
        XCTAssertEqual(CSVExport.field("plain"), "plain")
        XCTAssertEqual(CSVExport.field("a, b"), "\"a, b\"")
        XCTAssertEqual(CSVExport.field("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExport.field("two\nlines"), "\"two\nlines\"")
        XCTAssertEqual(CSVExport.field("=HYPERLINK(\"x\")"), "\"'=HYPERLINK(\"\"x\"\")\"")
        XCTAssertEqual(CSVExport.field("@sum"), "'@sum")
        XCTAssertEqual(CSVExport.field("-2.5"), "-2.5", "a negative number stays a number")
    }

    func testFilesHoldEveryRecord() {
        let s = snapshot(
            days: [.init(day: key(1), takenAt: at(1, 7), skipped: false, water: 6, fiber: 20, foodNoise: 2, strength: 1, updatedAt: at(1))],
            foods: [.init(day: key(1), name: "Greek yogurt, plain", protein: 17, meal: "Breakfast", at: at(1, 8))],
            symptoms: [symptom(1, note: "after lunch, mild")],
            weights: [.init(day: key(0), value: 88.4, at: at(0))],
            doses: [.init(label: "7 mg daily", from: key(5), at: at(5))])
        let files = CSVExport.make(from: s, timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(files.map(\.name), ["dawnwell-days.csv", "dawnwell-foods.csv", "dawnwell-symptoms.csv", "dawnwell-doses.csv"])
        let days = files[0].text.components(separatedBy: "\r\n")
        XCTAssertEqual(days[0], "date,tablet_taken_at,tablet_skipped,protein_g,water_glasses,fiber_g,strength,food_noise,weight_kg,symptoms")
        XCTAssertEqual(days[1], "\(key(1)),2026-11-17T07:00:00Z,,17,6,20,1,2,,nausea 3")
        XCTAssertEqual(days[2], "\(key(0)),,,,,,,,88.4,", "a day with only a weight still has a row")
        XCTAssertTrue(files[1].text.contains("\"Greek yogurt, plain\",17"))
        XCTAssertTrue(files[2].text.contains("nausea,3,,\"after lunch, mild\""))
        XCTAssertTrue(files[3].text.contains("\(key(5)),7 mg daily"))
    }

    func testWritesFilesThatReadBack() throws {
        let urls = try CSVExport.write([.init(name: "dawnwell-x.csv", text: "a,b\r\n")])
        XCTAssertEqual(try String(contentsOf: urls[0], encoding: .utf8), "a,b\r\n")
    }
}

final class WeeklyReminderTests: XCTestCase {
    private func input(weekly: Bool) -> ReminderPlan.Input {
        ReminderPlan.Input(remindTablet: false, remindWaitOver: false, remindProtein: false, remindRefill: false,
                           doseHour: 7, doseMinute: 0, waitMinutes: 30, proteinTarget: 100, tabletsLeft: nil,
                           loggedDays: [], takenAtToday: nil, proteinToday: 0, remindWeekly: weekly)
    }

    func testOneSundayEveningNudgeInTheWeekAhead() {
        let items = ReminderPlan.make(input(weekly: true), now: today, calendar: cal).items
        XCTAssertEqual(items.map(\.kind), [.weekly])
        let sunday = DateComponents(calendar: cal, year: 2026, month: 11, day: 22, hour: 18).date!
        XCTAssertEqual(items.first?.at, sunday)
    }

    func testOffMeansNothing() {
        XCTAssertTrue(ReminderPlan.make(input(weekly: false), now: today, calendar: cal).items.isEmpty)
    }

    func testWaitOverMentionsCoffee() {
        var i = input(weekly: false)
        i.remindWaitOver = true
        i.takenAtToday = at(0, 11)
        let item = ReminderPlan.make(i, now: at(0, 11), calendar: cal).items.first { $0.kind == .waitOver }
        XCTAssertTrue(item?.body.contains("coffee") == true)
    }
}

@MainActor
final class TabletLogTests: XCTestCase {
    func testLoggingTwiceCountsOnce() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let repo = Repository(context: container.mainContext)
        repo.profile().tabletsLeft = 10
        XCTAssertTrue(repo.logTabletTaken(day: "2026-11-18"))
        XCTAssertFalse(repo.logTabletTaken(day: "2026-11-18"), "the notification button after Today must not count again")
        XCTAssertEqual(repo.profile().tabletsLeft, 9)
        XCTAssertNotNil(repo.existingDay("2026-11-18")?.takenAt)
    }
}
