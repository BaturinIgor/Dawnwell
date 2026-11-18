import SwiftData
import XCTest
@testable import Dawnwell

@MainActor
final class LoggingTests: XCTestCase {
    private var container: ModelContainer!
    private var repo: Repository!

    override func setUp() async throws {
        container = try Persistence.makeContainer(inMemory: true)
        repo = Repository(context: container.mainContext)
    }

    func testAddFoodsWithCustomItem() {
        let picked = Array(Catalog.foods.prefix(2))
        repo.addFoods(picked, custom: (name: "  Jerky ", protein: 9), meal: .snack, day: "2026-11-18")
        let foods = repo.foods("2026-11-18")
        XCTAssertEqual(foods.count, 3)
        XCTAssertTrue(foods.contains { $0.name == "Jerky" && $0.protein == 9 && $0.meal == .snack })
    }

    func testCustomItemNeedsNameAndGrams() {
        repo.addFoods([], custom: (name: " ", protein: 9), meal: .snack, day: "d")
        repo.addFoods([], custom: (name: "Bar", protein: 0), meal: .snack, day: "d")
        XCTAssertTrue(repo.foods("d").isEmpty)
    }

    func testSymptomDetailsReplaceThatSymptomOnly() {
        repo.toggleSymptom(.fatigue, day: "d")
        repo.saveSymptom(.nausea, severity: 3, triggers: ["Fatty food"], note: " after dinner ", day: "d")
        repo.saveSymptom(.nausea, severity: 9, triggers: [], note: "", day: "d")
        let all = repo.symptoms("d")
        XCTAssertEqual(all.count, 2)
        let nausea = all.first { $0.kind == .nausea }
        XCTAssertEqual(nausea?.severity, 5)
        XCTAssertEqual(nausea?.note, "")
        XCTAssertTrue(all.contains { $0.kind == .fatigue })
    }

    func testSymptomNoteIsTrimmed() {
        repo.saveSymptom(.heartburn, severity: 2, triggers: [], note: "  late pizza \n", day: "d")
        XCTAssertEqual(repo.symptoms("d").first?.note, "late pizza")
    }

    func testDoseHistoryOnlyOnRealChange() {
        repo.updateTablet(medication: .orforglipron, doseLabel: "3 mg", today: "2026-11-01")
        repo.updateTablet(medication: .orforglipron, doseLabel: " 3 mg ", today: "2026-11-05")
        repo.updateTablet(medication: .orforglipron, doseLabel: "6 mg", today: "2026-11-18")
        XCTAssertEqual(repo.doseHistory().map(\.label), ["6 mg daily", "3 mg daily"])
        XCTAssertEqual(repo.profile().doseLabel, "6 mg")
        XCTAssertEqual(repo.profile().medication, .orforglipron)
    }

    func testAddTablets() {
        repo.addTablets(30)
        repo.addTablets(0)
        repo.addTablets(-5)
        XCTAssertEqual(repo.profile().tabletsLeft, 30)
    }
}
