import SwiftData
import XCTest
@testable import Dawnwell

final class DemoDataTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_795_000_000)

    func testFiveWeeksOfBelievableUse() {
        let s = DemoData.snapshot(now: now)
        XCTAssertEqual(s.days.count, 35)
        XCTAssertEqual(s.profile?.onboarded, true)
        let today = s.days.last
        XCTAssertEqual(today?.day, DayKey.of(now))
        XCTAssertEqual(today?.takenAt, now.addingTimeInterval(-12 * 60), "wait timer is running in the Today shot")
        XCTAssertGreaterThan(s.weights.first?.value ?? 0, s.weights.last?.value ?? 0, "weight goes down")
        XCTAssertFalse(s.symptoms.isEmpty)
    }

    func testDemoIsAlwaysAtNineFortyOneInTheMorning() {
        // Every quarter hour of a day, the chosen zone is a real one and its clock reads 9:41.
        for step in 0..<96 {
            let at = Date(timeIntervalSince1970: 1_795_000_000 + Double(step * 900))
            let offset = DemoData.morningOffset(now: at)
            XCTAssertTrue((-12 * 3600...14 * 3600).contains(offset), "offset \(offset)")
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: offset)!
            let c = calendar.dateComponents([.hour, .minute], from: at)
            XCTAssertEqual(c.hour, 9)
            XCTAssertEqual(c.minute, 41)
        }
    }

    func testKilogramsOutsideTheUS() {
        let us = DemoData.snapshot(now: now, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(us.profile?.weightUnit, "lb")
        XCTAssertEqual(us.weights.first?.value, 212)
        let de = DemoData.snapshot(now: now, locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(de.profile?.weightUnit, "kg")
        XCTAssertEqual(de.weights.first?.value, 96.2)
        XCTAssertEqual(de.profile?.goalWeight, 84)
    }

    func testNothingInTheFuture() {
        let s = DemoData.snapshot(now: now)
        XCTAssertTrue(s.foods.allSatisfy { $0.at < now })
        XCTAssertFalse(s.foods.contains { $0.day == DayKey.of(now) }, "no food during today's wait")
        XCTAssertTrue(s.days.allSatisfy { $0.day <= DayKey.of(now) })
    }

    @MainActor
    func testLoadsIntoAStore() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let repo = Repository(context: container.mainContext)
        try repo.replaceAll(with: DemoData.snapshot(now: now))
        XCTAssertEqual(repo.snapshot().days.count, 35)
        XCTAssertFalse(ProgressStats.make(from: repo.snapshot(), today: now).weights.isEmpty)
    }

    func testDemoIsOffInNormalLaunches() {
        XCTAssertFalse(Persistence.isDemo)
        XCTAssertTrue(Persistence.isSandboxed, "tests count as sandboxed")
    }
}
