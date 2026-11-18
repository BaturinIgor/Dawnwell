import XCTest
@testable import Dawnwell

final class DayKeyTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    func testFormatsLocalDate() {
        // 2026-11-18 03:30 UTC is still Nov 17 in New York.
        let d = Date(timeIntervalSince1970: 1_794_972_600)
        XCTAssertEqual(DayKey.of(d, calendar: cal), "2026-11-17")
    }

    func testRoundTrip() {
        let d = DayKey.date("2026-02-28", calendar: cal)!
        XCTAssertEqual(DayKey.of(d, calendar: cal), "2026-02-28")
        XCTAssertEqual(DayKey.adding(1, to: "2026-02-28", calendar: cal), "2026-03-01")
    }

    func testRejectsBadKeys() {
        XCTAssertFalse(DayKey.isValid("2026-13-01"))
        XCTAssertFalse(DayKey.isValid("hello"))
        XCTAssertTrue(DayKey.isValid("2026-11-18"))
    }

    func testLastDaysOldestFirst() {
        let end = DayKey.date("2026-11-18", calendar: cal)!
        let keys = DayKey.last(3, endingAt: end, calendar: cal).map { DayKey.of($0, calendar: cal) }
        XCTAssertEqual(keys, ["2026-11-16", "2026-11-17", "2026-11-18"])
    }
}

final class TabletStateTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: hour, minute: minute))!
    }

    private func state(taken: Date? = nil, skipped: Bool = false, now: Date) -> TabletState {
        TabletState.of(takenAt: taken, skipped: skipped, waitMinutes: 30, doseHour: 7, doseMinute: 0, now: now, calendar: cal)
    }

    func testPendingThenOverdue() {
        XCTAssertEqual(state(now: at(6)), .pending(overdue: false))
        XCTAssertEqual(state(now: at(8, 59)), .pending(overdue: false))
        XCTAssertEqual(state(now: at(9, 1)), .pending(overdue: true))
    }

    func testWaitingThenClear() {
        let taken = at(7, 5)
        XCTAssertEqual(state(taken: taken, now: at(7, 20)), .waiting(until: at(7, 35)))
        XCTAssertEqual(state(taken: taken, now: at(7, 35)), .clear)
    }

    func testSkipped() {
        XCTAssertEqual(state(skipped: true, now: at(10)), .skipped)
        // Taking it after all wins over skipped.
        XCTAssertEqual(state(taken: at(10), skipped: true, now: at(11)), .clear)
    }
}

final class LogicTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    func testStreakCountsBackFromToday() {
        let today = DayKey.date("2026-11-18", calendar: cal)!
        XCTAssertEqual(Logic.streak(takenDays: ["2026-11-16", "2026-11-17", "2026-11-18"], today: today, calendar: cal), 3)
    }

    func testStreakNotBrokenByTodayNotYetTaken() {
        let today = DayKey.date("2026-11-18", calendar: cal)!
        XCTAssertEqual(Logic.streak(takenDays: ["2026-11-16", "2026-11-17"], today: today, calendar: cal), 2)
    }

    func testStreakBrokenByGap() {
        let today = DayKey.date("2026-11-18", calendar: cal)!
        XCTAssertEqual(Logic.streak(takenDays: ["2026-11-15", "2026-11-18"], today: today, calendar: cal), 1)
        XCTAssertEqual(Logic.streak(takenDays: [], today: today, calendar: cal), 0)
    }

    func testCountdown() {
        XCTAssertEqual(Logic.countdown(90), "1:30")
        XCTAssertEqual(Logic.countdown(0.2), "0:01")
        XCTAssertEqual(Logic.countdown(-5), "0:00")
        XCTAssertEqual(Logic.countdown(1800), "30:00")
    }

    func testParsePositive() {
        XCTAssertEqual(Logic.parsePositive("72,5"), 72.5)
        XCTAssertEqual(Logic.parsePositive(" 195 "), 195)
        XCTAssertNil(Logic.parsePositive("-3"))
        XCTAssertNil(Logic.parsePositive("abc"))
        XCTAssertNil(Logic.parsePositive(""))
    }

    func testMealByHour() {
        let d = { (h: Int) in self.cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: h))! }
        XCTAssertEqual(Meal.at(d(8), calendar: cal), .breakfast)
        XCTAssertEqual(Meal.at(d(13), calendar: cal), .lunch)
        XCTAssertEqual(Meal.at(d(19), calendar: cal), .dinner)
        XCTAssertEqual(Meal.at(d(22), calendar: cal), .snack)
    }
}
