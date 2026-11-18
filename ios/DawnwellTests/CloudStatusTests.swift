import XCTest
@testable import Dawnwell

final class CloudStatusTests: XCTestCase {
    func testMessages() {
        XCTAssertTrue(CloudStatus.message(storeSyncs: true, account: .available).contains("your own iCloud"))
        XCTAssertTrue(CloudStatus.message(storeSyncs: true, account: .noAccount).contains("Sign in to iCloud"))
        XCTAssertTrue(CloudStatus.message(storeSyncs: false, account: .available).contains("backup file"))
        for a in [CloudStatus.Account.unknown, .available, .noAccount, .restricted, .unavailable] {
            XCTAssertFalse(CloudStatus.message(storeSyncs: true, account: a).isEmpty)
        }
    }

    @MainActor
    func testInMemoryStoreNeverSyncs() throws {
        // In-memory stores (tests, previews) must open without iCloud even when sync is asked for.
        let c = try Persistence.makeContainer(inMemory: true, cloud: true)
        XCTAssertEqual(c.configurations.first?.cloudKitContainerIdentifier, nil)
    }
}
