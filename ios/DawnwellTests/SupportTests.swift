import XCTest
@testable import Dawnwell

final class SupportTests: XCTestCase {
    func testMailLinkGoesToSupportWithDeviceDetails() throws {
        let url = try XCTUnwrap(Support.mailURL(appVersion: "1.0.0", build: "7", system: "18.2", device: "iPhone17,1"))
        XCTAssertEqual(url.scheme, "mailto")
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.path, "dawnwell.app@gmail.com")
        let items = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["subject"], "Dawnwell feedback")
        XCTAssertTrue(items["body"]?.contains("Dawnwell 1.0.0 (7) · iOS 18.2 · iPhone17,1") == true)
    }

    func testSpacesAreNotTurnedIntoPlusSigns() throws {
        let url = try XCTUnwrap(Support.mailURL(appVersion: "1.0.0", build: "1", system: "18.2", device: "x"))
        XCTAssertFalse(url.absoluteString.contains("+"))
        XCTAssertTrue(url.absoluteString.contains("Dawnwell%20feedback"))
    }

    func testPrivacyPolicyLinkMatchesThePublishedPage() {
        XCTAssertEqual(Support.privacyPolicy.absoluteString, "https://baturinigor.github.io/Dawnwell/privacy")
    }
}
