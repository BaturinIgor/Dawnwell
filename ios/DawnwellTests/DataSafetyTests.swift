import SwiftData
import XCTest
@testable import Dawnwell

/// Whole-second dates, so they survive the ISO 8601 round trip exactly.
private func t(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_794_972_600 + s) }

func sampleSnapshot() -> Snapshot {
    Snapshot(
        profile: .init(createdAt: t(0), onboarded: true, medication: "orforglipron", doseLabel: "12 mg",
                       doseHour: 8, doseMinute: 15, waitMinutes: 30, proteinTarget: 90, fiberTarget: 25, waterTarget: 8,
                       weightUnit: "kg", startWeight: 100, goalWeight: 85, tabletsLeft: 20,
                       remindTablet: true, remindWaitOver: false, remindProtein: true, remindRefill: true,
                       questions: "Is nausea normal?"),
        days: [
            .init(day: "2026-11-16", takenAt: t(-172_800), skipped: false, water: 6, fiber: 12, foodNoise: 4, strength: 0, updatedAt: t(-172_000)),
            .init(day: "2026-11-17", takenAt: nil, skipped: true, water: 2, fiber: 0, foodNoise: 2, strength: 20, updatedAt: t(-86_000)),
            .init(day: "2026-11-18", takenAt: t(0), skipped: false, water: 3, fiber: 5, foodNoise: nil, strength: 0, updatedAt: t(10)),
        ],
        foods: [
            .init(day: "2026-11-16", name: "Eggs", protein: 12, meal: "Breakfast", at: t(-170_000)),
            .init(day: "2026-11-18", name: "Greek yogurt, plain", protein: 17, meal: "Breakfast", at: t(100)),
            .init(day: "2026-11-18", name: "Chicken breast", protein: 80, meal: "Lunch", at: t(200)),
        ],
        symptoms: [
            .init(day: "2026-11-17", kind: "nausea", severity: 4, triggers: ["Fatty food"], note: "after dinner", at: t(-80_000)),
            .init(day: "2026-11-18", kind: "nausea", severity: 2, triggers: [], note: "", at: t(300)),
            .init(day: "2026-11-18", kind: "fatigue", severity: 1, triggers: [], note: "", at: t(400)),
        ],
        weights: [
            .init(day: "2026-11-01", value: 100, at: t(-1_500_000)),
            .init(day: "2026-11-18", value: 97.5, at: t(50)),
        ],
        doses: [.init(label: "12 mg daily", from: "2026-11-01", at: t(-1_500_000))]
    )
}

final class BackupFileTests: XCTestCase {
    func testRoundTrip() throws {
        let s = sampleSnapshot()
        let data = try BackupFile.encode(s, at: t(0))
        let back = try BackupFile.decode(data)
        XCTAssertEqual(back.data, s)
        XCTAssertEqual(back.exportedAt, t(0))
        XCTAssertEqual(back.format, "dawnwell-backup")
    }

    func testRejectsOtherFiles() {
        XCTAssertThrowsError(try BackupFile.decode(Data("{\"hello\":1}".utf8))) { XCTAssertEqual($0 as? BackupFile.ReadError, .notABackup) }
        XCTAssertThrowsError(try BackupFile.decode(Data("not json".utf8))) { XCTAssertEqual($0 as? BackupFile.ReadError, .notABackup) }
    }

    func testRejectsNewerVersion() {
        let json = "{\"format\":\"dawnwell-backup\",\"formatVersion\":99,\"exportedAt\":\"2026-11-18T00:00:00Z\",\"data\":{}}"
        XCTAssertThrowsError(try BackupFile.decode(Data(json.utf8))) { XCTAssertEqual($0 as? BackupFile.ReadError, .newerVersion) }
    }

    func testDamagedBody() {
        let json = "{\"format\":\"dawnwell-backup\",\"formatVersion\":2,\"exportedAt\":\"2026-11-18T00:00:00Z\",\"data\":{\"days\":5}}"
        XCTAssertThrowsError(try BackupFile.decode(Data(json.utf8))) { XCTAssertEqual($0 as? BackupFile.ReadError, .damaged) }
    }

    func testFileName() {
        XCTAssertTrue(BackupFile.fileName(for: t(0)).hasPrefix("dawnwell-backup-2026-11-"))
        XCTAssertTrue(BackupFile.fileName(for: t(0)).hasSuffix(".json"))
    }

    func testEmptyAndSummary() {
        let empty = Snapshot(profile: nil, days: [], foods: [], symptoms: [], weights: [], doses: [])
        XCTAssertTrue(empty.isEmpty)
        XCTAssertFalse(sampleSnapshot().isEmpty)
        XCTAssertEqual(sampleSnapshot().summary, "3 days of logs, 2 weight entries")
    }
}

final class LocalCopiesTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testParse() {
        let c = LocalCopies.parse(URL(fileURLWithPath: "/x/before-restore_1794972600000.json"))
        XCTAssertEqual(c?.reason, .beforeRestore)
        XCTAssertEqual(c?.takenAt, t(0))
        XCTAssertNil(LocalCopies.parse(URL(fileURLWithPath: "/x/daily_abc.json")))
        XCTAssertNil(LocalCopies.parse(URL(fileURLWithPath: "/x/weekly_1.json")))
        XCTAssertNil(LocalCopies.parse(URL(fileURLWithPath: "/x/daily_1.txt")))
    }

    func testToDeleteKeepsNewest() {
        let daily = (0..<10).map { LocalCopies.Copy(url: URL(fileURLWithPath: "/d\($0)"), reason: .daily, takenAt: t(Double($0) * 86_400)) }
        let other = (0..<7).map { LocalCopies.Copy(url: URL(fileURLWithPath: "/o\($0)"), reason: .beforeRestore, takenAt: t(Double($0))) }
        let gone = LocalCopies.toDelete(daily + other)
        XCTAssertEqual(Set(gone.map(\.url.path)), ["/d0", "/d1", "/d2", "/o0", "/o1"])
    }

    func testSaveListReadAndPrune() throws {
        let copies = LocalCopies(directory: dir)
        for i in 0..<9 { try copies.save(sampleSnapshot(), reason: .daily, at: t(Double(i) * 86_400)) }
        try copies.save(sampleSnapshot(), reason: .beforeRestore, at: t(5))
        let list = copies.list()
        XCTAssertEqual(list.filter { $0.reason == .daily }.count, LocalCopies.keepDaily)
        XCTAssertEqual(list.filter { $0.reason == .beforeRestore }.count, 1)
        XCTAssertEqual(list.first?.takenAt, t(8 * 86_400))
        XCTAssertEqual(try copies.read(list[0]), sampleSnapshot())
        XCTAssertTrue(copies.hasDailyCopy(for: DayKey.of(t(8 * 86_400))))
        XCTAssertFalse(copies.hasDailyCopy(for: DayKey.of(t(30 * 86_400))))
    }
}

@MainActor
final class RestoreTests: XCTestCase {
    private var container: ModelContainer!
    private var repo: Repository!
    private var dir: URL!

    override func setUp() async throws {
        container = try Persistence.makeContainer(inMemory: true)
        repo = Repository(context: container.mainContext)
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testReplaceAllRoundTrip() throws {
        try repo.replaceAll(with: sampleSnapshot())
        XCTAssertEqual(repo.snapshot(), sampleSnapshot())
        // Replacing again leaves exactly one copy of everything.
        try repo.replaceAll(with: sampleSnapshot())
        XCTAssertEqual(repo.snapshot(), sampleSnapshot())
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Profile>()), 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<FoodEntry>()), 3)
    }

    func testRestoreKeepsCopyOfCurrentData() throws {
        let copies = LocalCopies(directory: dir)
        repo.profile().onboarded = true
        repo.updateDay("2026-11-10") { $0.water = 7 }
        let before = repo.snapshot()

        try DataSafety.restore(sampleSnapshot(), repo: repo, copies: copies, now: t(0))

        XCTAssertEqual(repo.snapshot(), sampleSnapshot())
        let saved = copies.list()
        XCTAssertEqual(saved.map(\.reason), [.beforeRestore])
        let kept = try copies.read(saved[0])
        XCTAssertEqual(kept.days.map(\.day), before.days.map(\.day))
        XCTAssertEqual(kept.days.first?.water, 7)
    }

    func testRestoreIntoEmptyStoreMakesNoCopy() throws {
        let copies = LocalCopies(directory: dir)
        try DataSafety.restore(sampleSnapshot(), repo: repo, copies: copies)
        XCTAssertTrue(copies.list().isEmpty)
        XCTAssertEqual(repo.snapshot(), sampleSnapshot())
    }

    func testDailyCopyOncePerDayAndNotWhenEmpty() throws {
        let copies = LocalCopies(directory: dir)
        XCTAssertFalse(DataSafety.takeDailyCopy(repo: repo, copies: copies, now: t(0)))
        try repo.replaceAll(with: sampleSnapshot())
        XCTAssertTrue(DataSafety.takeDailyCopy(repo: repo, copies: copies, now: t(0)))
        XCTAssertFalse(DataSafety.takeDailyCopy(repo: repo, copies: copies, now: t(60)))
        XCTAssertTrue(DataSafety.takeDailyCopy(repo: repo, copies: copies, now: t(86_400)))
        XCTAssertEqual(copies.list().count, 2)
    }

    func testExportFileReadsBack() throws {
        try repo.replaceAll(with: sampleSnapshot())
        let url = try DataSafety.exportFile(repo: repo, now: t(0))
        XCTAssertEqual(try BackupFile.decode(Data(contentsOf: url)).data, sampleSnapshot())
    }

    func testLogWeightOnePerDay() {
        repo.logWeight(98, day: "2026-11-18")
        repo.logWeight(97.2, day: "2026-11-18")
        repo.logWeight(0, day: "2026-11-19")
        let w = repo.snapshot().weights
        XCTAssertEqual(w.map(\.value), [97.2])
    }
}
