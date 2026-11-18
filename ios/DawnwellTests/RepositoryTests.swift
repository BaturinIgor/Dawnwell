import SwiftData
import XCTest
@testable import Dawnwell

@MainActor
final class RepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repo: Repository!

    override func setUp() async throws {
        container = try Persistence.makeContainer(inMemory: true)
        repo = Repository(context: container.mainContext)
    }

    func testSingleProfile() {
        let a = repo.profile()
        let b = repo.profile()
        XCTAssertTrue(a === b)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Profile>()), 1)
    }

    func testDayCreatedOnceOnWrite() {
        XCTAssertNil(repo.existingDay("2026-11-18"))
        repo.updateDay("2026-11-18") { $0.water = 3 }
        repo.updateDay("2026-11-18") { $0.water += 1 }
        XCTAssertEqual(repo.existingDay("2026-11-18")?.water, 4)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<DayLog>()), 1)
    }

    func testDuplicateDaysAreMergedNotLost() throws {
        let ctx = container.mainContext
        let a = DayLog(day: "2026-11-18")
        a.water = 2
        a.foodNoise = 3
        let b = DayLog(day: "2026-11-18")
        b.water = 5
        b.takenAt = Date(timeIntervalSince1970: 1_000)
        b.fiber = 10
        ctx.insert(a)
        ctx.insert(b)
        try ctx.save()

        let merged = repo.day("2026-11-18")
        XCTAssertEqual(merged.water, 5)
        XCTAssertEqual(merged.fiber, 10)
        XCTAssertEqual(merged.foodNoise, 3)
        XCTAssertEqual(merged.takenAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<DayLog>()), 1)
    }

    func testMergeKeepsEarliestTakenAndClearsSkipped() {
        let a = DayLog(day: "x")
        a.skipped = true
        let b = DayLog(day: "x")
        b.takenAt = Date(timeIntervalSince1970: 50)
        Repository.merge(b, into: a)
        XCTAssertEqual(a.takenAt, Date(timeIntervalSince1970: 50))
        XCTAssertFalse(a.skipped)
    }

    func testFoodsAndSymptomsBelongToTheirDay() {
        let food = Catalog.quickFoods[0]
        repo.addFood(food, meal: .breakfast, day: "2026-11-17")
        repo.addFood(food, meal: .lunch, day: "2026-11-18")
        repo.addFood(food, meal: .dinner, day: "2026-11-18")
        XCTAssertEqual(repo.foods("2026-11-18").count, 2)
        XCTAssertEqual(repo.foods("2026-11-17").count, 1)

        repo.toggleSymptom(.nausea, day: "2026-11-18")
        XCTAssertEqual(repo.symptoms("2026-11-18").map(\.kind), [.nausea])
        repo.toggleSymptom(.nausea, day: "2026-11-18")
        XCTAssertTrue(repo.symptoms("2026-11-18").isEmpty)
    }

    func testTakenDays() {
        repo.updateDay("2026-11-17") { $0.takenAt = Date() }
        repo.updateDay("2026-11-18") { $0.water = 1 }
        XCTAssertEqual(repo.takenDays(), ["2026-11-17"])
    }

    func testDataSurvivesReopeningTheStore() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dw-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let schema = Schema(versionedSchema: SchemaV1.self)
        do {
            let c = try ModelContainer(for: schema, migrationPlan: DawnwellMigrationPlan.self,
                                       configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            Repository(context: c.mainContext).updateDay("2026-11-18") { $0.water = 7 }
        }
        let reopened = try ModelContainer(for: schema, migrationPlan: DawnwellMigrationPlan.self,
                                          configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        XCTAssertEqual(Repository(context: reopened.mainContext).existingDay("2026-11-18")?.water, 7)
    }
}
