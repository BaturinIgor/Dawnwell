import PDFKit
import XCTest
@testable import Dawnwell

final class PlusTests: XCTestCase {
    func testYearlySaving() {
        XCTAssertEqual(Plus.yearlySaving(monthly: 4.99, yearly: 29.99), 49)
        XCTAssertEqual(Plus.yearlySaving(monthly: 4.99, yearly: 59.88), 0)
        XCTAssertEqual(Plus.yearlySaving(monthly: 0, yearly: 10), 0)
    }

    func testFreeWeekOnlyPromisedToEligibleUsers() {
        XCTAssertEqual(Plus.buyTitle(hasFreeTrial: true, eligibleForTrial: true, price: "$29.99"), "Start free week, then $29.99")
        XCTAssertEqual(Plus.buyTitle(hasFreeTrial: true, eligibleForTrial: false, price: "$29.99"), "Subscribe for $29.99")
        XCTAssertEqual(Plus.buyTitle(hasFreeTrial: false, eligibleForTrial: true, price: "$4.99"), "Subscribe for $4.99")
    }

    func testBothPlansShareOneSubscriptionGroup() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("StoreKit/Dawnwell.storekit")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("Store config not reachable from the simulator") }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try XCTUnwrap(json["subscriptionGroups"] as? [[String: Any]])
        // One group means one free week per Apple ID, not one per plan.
        XCTAssertEqual(groups.count, 1)
        let ids = (groups.first?["subscriptions"] as? [[String: Any]])?.compactMap { $0["productID"] as? String } ?? []
        XCTAssertEqual(Set(ids), Set(Plus.subscriptionIDs))
    }

    func testLifetimeIsANonConsumableOutsideTheGroup() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("StoreKit/Dawnwell.storekit")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("Store config not reachable from the simulator") }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(json["products"] as? [[String: Any]])
        let lifetime = try XCTUnwrap(products.first { $0["productID"] as? String == Plus.lifetimeID })
        XCTAssertEqual(lifetime["type"] as? String, "NonConsumable")
        XCTAssertEqual(lifetime["displayPrice"] as? String, "59.99")
        XCTAssertFalse(Plus.subscriptionIDs.contains(Plus.lifetimeID))
        XCTAssertTrue(Plus.productIDs.contains(Plus.lifetimeID))
    }

    func testLifetimeButtonNeverPromisesATrial() {
        XCTAssertEqual(Plus.buyTitle(plan: .lifetime, hasFreeTrial: true, eligibleForTrial: true, price: "$59.99"), "Buy once for $59.99")
        XCTAssertEqual(Plus.Plan.allCases.map(\.productID), [Plus.yearlyID, Plus.monthlyID, Plus.lifetimeID])
    }

    func testPaywallLinksAreTheOnesAppStoreReviewChecks() {
        XCTAssertEqual(Plus.termsOfUse.host, "www.apple.com")
        XCTAssertEqual(Support.privacyPolicy.host, "baturinigor.github.io")
    }

    func testPerMonth() {
        XCTAssertEqual(Plus.perMonth(yearly: 29.99), Decimal(string: "2.5"))
    }

    func testProductIDsMatchStoreConfig() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("StoreKit/Dawnwell.storekit")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw XCTSkip("Store config not reachable from the simulator") }
        for id in Plus.productIDs { XCTAssertTrue(text.contains("\"\(id)\""), id) }
    }
}

final class ReportPDFTests: XCTestCase {
    func testRendersReadablePDF() throws {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        let today = DateComponents(calendar: c, year: 2026, month: 11, day: 18, hour: 12).date!
        let summary = VisitSummary.make(from: sampleSnapshot(), today: today, calendar: c)
        let data = ReportPDF.render(summary)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "%PDF")
        let doc = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThanOrEqual(doc.pageCount, 1)
        XCTAssertTrue(doc.string?.contains("Tablet logged taken on 2 of 30 days") == true)
    }

    func testLongReportSpansPages() throws {
        var s = sampleSnapshot()
        s.profile?.questions = Array(repeating: "A question about my symptoms and food.", count: 200).joined(separator: "\n")
        let data = ReportPDF.render(VisitSummary.make(from: s))
        XCTAssertGreaterThan(try XCTUnwrap(PDFDocument(data: data)).pageCount, 1)
    }
}
