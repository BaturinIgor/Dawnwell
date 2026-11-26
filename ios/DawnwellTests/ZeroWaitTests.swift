import SwiftData
import XCTest
@testable import Dawnwell

/// Foundayo is taken with or without food, so a zero wait has to work everywhere the wait shows up.
@MainActor
final class ZeroWaitTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(calendar: cal, year: 2026, month: 11, day: day, hour: hour, minute: minute).date!
    }

    func testDefaultWaitFollowsTheMedication() {
        XCTAssertEqual(Medication.oralSemaglutide.defaultWaitMinutes, 30)
        XCTAssertEqual(Medication.orforglipron.defaultWaitMinutes, 0)
        XCTAssertEqual(Medication.other.defaultWaitMinutes, 30)
    }

    func testBrandNamesAreShown() {
        XCTAssertTrue(Medication.oralSemaglutide.label.contains("Wegovy"))
        XCTAssertTrue(Medication.oralSemaglutide.label.contains("Rybelsus"))
        XCTAssertTrue(Medication.orforglipron.label.contains("Foundayo"))
    }

    func testZeroWaitIsClearRightAfterTaking() {
        let taken = date(20, 7)
        XCTAssertEqual(TabletState.of(takenAt: taken, skipped: false, waitMinutes: 0, doseHour: 7, doseMinute: 0,
                                      now: taken, calendar: cal), .clear)
    }

    func testZeroWaitRemindersSayNothingAboutWaiting() {
        let i = ReminderPlan.Input(remindTablet: true, remindWaitOver: true, remindProtein: false, remindRefill: false,
                                   doseHour: 7, doseMinute: 30, waitMinutes: 0, proteinTarget: 100, tabletsLeft: nil,
                                   loggedDays: [], takenAtToday: date(18, 6), proteinToday: 0)
        let items = ReminderPlan.make(i, now: date(18, 6), calendar: cal).items
        XCTAssertFalse(items.contains { $0.kind == .waitOver })
        let tablet = items.filter { $0.kind == .tablet }
        XCTAssertFalse(tablet.isEmpty)
        XCTAssertTrue(tablet.allSatisfy { !$0.body.contains("wait") })
    }

    func testSwitchingMedicationResetsTheWaitButSavingTheSameOneKeepsIt() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let repo = Repository(context: container.mainContext)
        let p = repo.profile()
        p.medication = .oralSemaglutide
        p.waitMinutes = 45
        repo.updateTablet(medication: .oralSemaglutide, doseLabel: "14 mg")
        XCTAssertEqual(p.waitMinutes, 45)
        repo.updateTablet(medication: .orforglipron, doseLabel: "6 mg")
        XCTAssertEqual(p.waitMinutes, 0)
    }
}

final class ReviewPromptTests: XCTestCase {
    func testAsksAfterAWeekOncePerVersion() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(streak: 6, lastAskedVersion: nil, currentVersion: "1.0.1"))
        XCTAssertTrue(ReviewPrompt.shouldAsk(streak: 7, lastAskedVersion: nil, currentVersion: "1.0.1"))
        XCTAssertTrue(ReviewPrompt.shouldAsk(streak: 30, lastAskedVersion: "1.0.0", currentVersion: "1.0.1"))
        XCTAssertFalse(ReviewPrompt.shouldAsk(streak: 30, lastAskedVersion: "1.0.1", currentVersion: "1.0.1"))
    }
}

@MainActor
final class AnalyticsTests: XCTestCase {
    func testNeverSendsFromTests() {
        XCTAssertFalse(Analytics.isAvailable)
    }

    func testOptOutIsRemembered() {
        let d = UserDefaults(suiteName: "AnalyticsTests")!
        d.removePersistentDomain(forName: "AnalyticsTests")
        XCTAssertTrue(Analytics.isUserEnabled(d))
        d.set(true, forKey: Analytics.optOutKey)
        XCTAssertFalse(Analytics.isUserEnabled(d))
    }

    /// Firebase allows letters, digits and _, up to 40 characters, starting with a letter.
    func testEventNamesAreValidFirebaseNames() {
        for e in Analytics.Event.allCases {
            XCTAssertNotNil(e.rawValue.range(of: "^[a-z][a-z0-9_]{0,39}$", options: .regularExpression), e.rawValue)
        }
    }

    /// Signal names are about steps in the app, never about what the user logged.
    func testEventNamesCarryNoHealthWords() {
        let banned = ["dose", "weight", "symptom", "food", "protein", "medication", "nausea", "mg"]
        for e in Analytics.Event.allCases {
            let name = e.rawValue.lowercased()
            XCTAssertFalse(banned.contains { name.contains($0) }, e.rawValue)
        }
    }
}
