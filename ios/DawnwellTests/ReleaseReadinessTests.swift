import XCTest

/// Checks the App Store asks of every build: privacy manifest, export compliance, Health wording.
final class ReleaseReadinessTests: XCTestCase {
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    func testPrivacyManifestShipsAndDeclaresNoTrackingOrCollection() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0)
        let apis = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = apis.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        XCTAssertEqual(defaults?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }

    func testDeclaresNoNonExemptEncryption() {
        XCTAssertEqual(info["ITSAppUsesNonExemptEncryption"] as? Bool, false)
    }

    func testHealthUsageTextIsPresent() {
        let text = info["NSHealthShareUsageDescription"] as? String ?? ""
        XCTAssertTrue(text.contains("weight"))
    }

    func testVersionIsSet() {
        XCTAssertEqual(info["CFBundleShortVersionString"] as? String, "1.0.0")
        XCTAssertNotNil(info["CFBundleVersion"])
    }
}
