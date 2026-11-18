import PDFKit
import XCTest
@testable import Dawnwell

final class PlusTests: XCTestCase {
    func testYearlySaving() {
        XCTAssertEqual(Plus.yearlySaving(monthly: 4.99, yearly: 29.99), 49)
        XCTAssertEqual(Plus.yearlySaving(monthly: 4.99, yearly: 59.88), 0)
        XCTAssertEqual(Plus.yearlySaving(monthly: 0, yearly: 10), 0)
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
