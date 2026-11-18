import SwiftData
import XCTest
@testable import Dawnwell

final class HealthImportTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int) -> Date {
        DateComponents(calendar: cal, year: 2026, month: 11, day: day, hour: hour).date!
    }

    func testConvertsAndRounds() {
        XCTAssertEqual(HealthImport.convert(kilograms: 80, to: .kg), 80)
        XCTAssertEqual(HealthImport.convert(kilograms: 80, to: .lb), 176.4)
        XCTAssertEqual(HealthImport.convert(kilograms: 72.349, to: .kg), 72.3)
    }

    func testLatestReadingPerDayWins() {
        let samples = [
            HealthImport.Sample(kilograms: 81, at: at(10, 7)),
            HealthImport.Sample(kilograms: 80.5, at: at(10, 21)),
            HealthImport.Sample(kilograms: 80, at: at(11, 7)),
        ]
        let e = HealthImport.entries(from: samples, existingDays: [], unit: .kg, calendar: cal)
        XCTAssertEqual(e.map(\.day), ["2026-11-10", "2026-11-11"])
        XCTAssertEqual(e.map(\.value), [80.5, 80])
    }

    func testNeverReplacesTypedWeight() {
        let samples = [HealthImport.Sample(kilograms: 81, at: at(10, 7)), HealthImport.Sample(kilograms: 80, at: at(11, 7))]
        let e = HealthImport.entries(from: samples, existingDays: ["2026-11-10"], unit: .kg, calendar: cal)
        XCTAssertEqual(e.map(\.day), ["2026-11-11"])
    }

    func testDropsImpossibleReadings() {
        let samples = [HealthImport.Sample(kilograms: 0, at: at(10, 7)), HealthImport.Sample(kilograms: 900, at: at(11, 7))]
        XCTAssertTrue(HealthImport.entries(from: samples, existingDays: [], unit: .kg, calendar: cal).isEmpty)
    }

    func testHealthReadingsFillOnlyDaysWithoutTypedWeight() {
        let typed = Snapshot.WeightData(day: "2026-11-10", value: 82, at: at(10, 8))
        var snap = Snapshot(profile: nil, days: [], foods: [], symptoms: [], weights: [typed], doses: [])
        let health = [
            HealthImport.Entry(day: "2026-11-10", value: 81, at: at(10, 7)),
            HealthImport.Entry(day: "2026-11-11", value: 80, at: at(11, 7)),
        ]
        snap = HealthImport.adding(health, to: snap)
        XCTAssertEqual(snap.weights.map(\.day), ["2026-11-10", "2026-11-11"])
        XCTAssertEqual(snap.weights.first { $0.day == "2026-11-10" }?.value, 82, "a typed weight wins")
    }

    @MainActor
    func testHealthReadingsAreNeverSavedToTheStore() throws {
        // The store syncs to iCloud, and Guideline 5.1.3(ii) forbids HealthKit data there.
        let container = try Persistence.makeContainer(inMemory: true)
        let repo = Repository(context: container.mainContext)
        let health = [HealthImport.Entry(day: "2026-11-11", value: 80, at: at(11, 7))]
        let stats = ProgressStats.make(from: HealthImport.adding(health, to: repo.snapshot()), today: at(12, 9), calendar: cal)
        XCTAssertEqual(stats.weights.map(\.value), [80], "shown on screen")
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<WeightEntry>()), 0, "but not stored")
        XCTAssertTrue(repo.snapshot().weights.isEmpty, "and not in backups")
    }
}
