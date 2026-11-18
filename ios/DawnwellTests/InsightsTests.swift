import XCTest
@testable import Dawnwell

/// Noon on 2026-11-18 in the test calendar, so day keys don't shift with the time zone.
private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()
private let today = DateComponents(calendar: cal, year: 2026, month: 11, day: 18, hour: 12).date!

final class VisitSummaryTests: XCTestCase {
    func testNumbers() {
        let v = VisitSummary.make(from: sampleSnapshot(), today: today, calendar: cal)
        XCTAssertEqual(v.from, "2026-10-20")
        XCTAssertEqual(v.to, "2026-11-18")
        XCTAssertEqual(v.medication, Medication.orforglipron.label)
        XCTAssertEqual(v.daysTaken, 2)
        XCTAssertEqual(v.daysSkipped, 1)
        XCTAssertEqual(v.firstWeight, 100)
        XCTAssertEqual(v.lastWeight, 97.5)
        XCTAssertEqual(v.weightChange, -2.5)
        XCTAssertEqual(v.unit, .kg)
        // Day totals 12 and 97 → 54.5 rounds to 55.
        XCTAssertEqual(v.averageProtein, 55)
        XCTAssertEqual(v.symptoms.map(\.kind), [.nausea, .fatigue])
        XCTAssertEqual(v.symptoms.first?.days, 2)
        XCTAssertEqual(v.symptoms.first?.worst, 4)
        XCTAssertEqual(v.symptoms.first?.notes, ["after dinner"])
    }

    func testTextHasKeyLinesAndNoDoseAdvice() {
        let text = VisitSummary.make(from: sampleSnapshot(), today: today, calendar: cal).text
        XCTAssertTrue(text.contains("Tablet logged taken on 2 of 30 days, skipped 1"))
        XCTAssertTrue(text.contains("Weight: 100.0 → 97.5 kg (-2.5)"))
        XCTAssertTrue(text.contains("My questions:\nIs nausea normal?"))
        XCTAssertTrue(text.contains("12 mg daily from"))
        XCTAssertTrue(text.hasSuffix("Not medical advice."))
    }

    func testEmptyData() {
        let empty = Snapshot(profile: nil, days: [], foods: [], symptoms: [], weights: [], doses: [])
        let v = VisitSummary.make(from: empty, today: today, calendar: cal)
        XCTAssertNil(v.weightChange)
        XCTAssertNil(v.averageProtein)
        XCTAssertTrue(v.text.contains("- None logged"))
    }
}

final class ProgressStatsTests: XCTestCase {
    func testWeightAndGoal() {
        let p = ProgressStats.make(from: sampleSnapshot(), today: today, calendar: cal)
        XCTAssertEqual(p.latest?.value, 97.5)
        XCTAssertEqual(p.changeSinceStart, 2.5)
        XCTAssertEqual(p.toGoal, 12.5)
    }

    func testProteinWeekAndTabletGrid() {
        let p = ProgressStats.make(from: sampleSnapshot(), today: today, calendar: cal)
        XCTAssertEqual(p.proteinWeek.count, 7)
        XCTAssertEqual(p.proteinWeek.last, .init(day: "2026-11-18", grams: 97))
        XCTAssertEqual(p.proteinHitDays, 1)
        XCTAssertEqual(p.tabletGrid.count, 28)
        XCTAssertEqual(p.tabletGrid.suffix(3).map(\.mark), [.taken, .skipped, .taken])
        XCTAssertEqual(p.takenCount, 2)
    }

    func testNoiseTrend() {
        let p = ProgressStats.make(from: sampleSnapshot(), today: today, calendar: cal)
        // Ratings 4 then 2: the older half averages 4, the recent half 2.
        XCTAssertEqual(p.noiseBefore, 4)
        XCTAssertEqual(p.noiseNow, 2)
    }

    func testSameDayWeightsKeepLatest() {
        var s = sampleSnapshot()
        s.weights.append(.init(day: "2026-11-18", value: 96, at: Date(timeIntervalSince1970: 1_794_972_600 + 9_999)))
        let p = ProgressStats.make(from: s, today: today, calendar: cal)
        XCTAssertEqual(p.weights.count, 2)
        XCTAssertEqual(p.latest?.value, 96)
    }
}

final class LearnContentTests: XCTestCase {
    func testStartDayIsEarliestValid() {
        XCTAssertEqual(LearnContent.startDay(sampleSnapshot()), "2026-11-01")
        let empty = Snapshot(profile: nil, days: [], foods: [], symptoms: [], weights: [], doses: [])
        XCTAssertNil(LearnContent.startDay(empty))
    }

    func testDayNumberAndStage() {
        XCTAssertEqual(LearnContent.dayNumber(start: nil, today: today, calendar: cal), 1)
        XCTAssertEqual(LearnContent.dayNumber(start: "2026-11-18", today: today, calendar: cal), 1)
        XCTAssertEqual(LearnContent.dayNumber(start: "2026-11-01", today: today, calendar: cal), 18)
        XCTAssertEqual(LearnContent.dayNumber(start: "2026-12-01", today: today, calendar: cal), 1)
        XCTAssertEqual(LearnContent.stage(for: 1).title, "Your first two weeks")
        XCTAssertEqual(LearnContent.stage(for: 18).title, "Settling in")
        XCTAssertEqual(LearnContent.stage(for: 400).title, "Keeping it going")
    }

    func testArticlesNeverGiveDoseInstructions() {
        for a in LearnContent.articles {
            XCTAssertFalse(a.body.lowercased().contains("increase your dose"), a.title)
        }
    }
}
