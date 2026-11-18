import XCTest
@testable import Dawnwell

final class ReminderPlanTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(calendar: cal, year: 2026, month: 11, day: day, hour: hour, minute: minute).date!
    }

    private func input(_ change: (inout ReminderPlan.Input) -> Void = { _ in }) -> ReminderPlan.Input {
        var i = ReminderPlan.Input(remindTablet: true, remindWaitOver: true, remindProtein: true, remindRefill: false,
                                   doseHour: 7, doseMinute: 30, waitMinutes: 30, proteinTarget: 100, tabletsLeft: nil,
                                   loggedDays: [], takenAtToday: nil, proteinToday: 0)
        change(&i)
        return i
    }

    private func items(_ i: ReminderPlan.Input, at now: Date, _ kind: ReminderPlan.Item.Kind) -> [ReminderPlan.Item] {
        ReminderPlan.make(i, now: now, calendar: cal).items.filter { $0.kind == kind }
    }

    func testTabletEveryDayAtDoseTime() {
        let t = items(input(), at: date(18, 6), .tablet)
        XCTAssertEqual(t.count, ReminderPlan.daysAhead)
        XCTAssertEqual(t.first?.at, date(18, 7, 30))
        XCTAssertEqual(t.first?.id, "tablet-2026-11-18")
        XCTAssertEqual(t.last?.at, date(24, 7, 30))
    }

    func testNoTabletReminderOnceLoggedOrPast() {
        let logged = items(input { $0.loggedDays = ["2026-11-18"] }, at: date(18, 6), .tablet)
        XCTAssertEqual(logged.first?.at, date(19, 7, 30))
        let afterTime = items(input(), at: date(18, 9), .tablet)
        XCTAssertEqual(afterTime.first?.at, date(19, 7, 30))
        XCTAssertTrue(items(input { $0.remindTablet = false }, at: date(18, 6), .tablet).isEmpty)
    }

    func testWaitOver() {
        let w = items(input { $0.takenAtToday = date(18, 7, 40) }, at: date(18, 7, 45), .waitOver)
        XCTAssertEqual(w.map(\.at), [date(18, 8, 10)])
        XCTAssertTrue(items(input { $0.takenAtToday = date(18, 7, 0) }, at: date(18, 8), .waitOver).isEmpty)
        XCTAssertTrue(items(input(), at: date(18, 8), .waitOver).isEmpty)
    }

    func testProteinSkippedWhenTargetReached() {
        let hit = items(input { $0.proteinToday = 110 }, at: date(18, 12), .protein)
        XCTAssertEqual(hit.first?.at, date(19, 15))
        let partial = items(input { $0.proteinToday = 40 }, at: date(18, 12), .protein)
        XCTAssertEqual(partial.first?.at, date(18, 15))
        XCTAssertEqual(partial.first?.body, "You're at 40 of 100 g today. A protein snack helps.")
    }

    func testRefillOnlyWhenLow() {
        XCTAssertTrue(items(input { $0.remindRefill = true; $0.tabletsLeft = 20 }, at: date(18, 12), .refill).isEmpty)
        let low = items(input { $0.remindRefill = true; $0.tabletsLeft = 3 }, at: date(18, 12), .refill)
        XCTAssertEqual(low.map(\.at), [date(19, 10)])
        XCTAssertEqual(low.first?.body, "3 tablets left. Time to ask for a refill.")
    }

    func testStaysUnderSystemLimitAndSorted() {
        let all = ReminderPlan.make(input { $0.remindRefill = true; $0.tabletsLeft = 1; $0.takenAtToday = date(18, 7) },
                                    now: date(18, 7, 10), calendar: cal).items
        XCTAssertLessThan(all.count, 64)
        XCTAssertEqual(all.map(\.at), all.map(\.at).sorted())
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
    }

    func testWordingNeverSuggestsADose() {
        let all = ReminderPlan.make(input { $0.remindRefill = true; $0.tabletsLeft = 0; $0.takenAtToday = date(18, 7) },
                                    now: date(18, 7, 10), calendar: cal).items
        for item in all {
            let text = (item.title + " " + item.body).lowercased()
            XCTAssertFalse(text.contains(" mg"), item.id)
            XCTAssertFalse(text.contains("double"), item.id)
            XCTAssertFalse(text.contains("extra tablet"), item.id)
        }
    }
}
