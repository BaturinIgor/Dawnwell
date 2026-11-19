import CloudKit
import Foundation

/// What to tell the user about their iCloud copy.
enum CloudStatus {
    enum Account: Equatable { case unknown, available, noAccount, restricted, unavailable }

    /// Set at launch: whether the store opened with iCloud sync.
    @MainActor static var storeSyncs = false

    static func account() async -> Account {
        // Without iCloud sync the build may have no iCloud entitlement, and CKContainer then stops the app.
        guard await storeSyncs else { return .unavailable }
        guard let status = try? await CKContainer(identifier: Persistence.cloudContainer).accountStatus() else { return .unavailable }
        switch status {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .couldNotDetermine, .temporarilyUnavailable: return .unknown
        @unknown default: return .unknown
        }
    }

    static func message(storeSyncs: Bool, account: Account) -> String {
        guard storeSyncs else {
            return String(localized: "Your logs are kept on this iPhone. iCloud copy isn't available in this build. Use a backup file to keep a copy.")
        }
        switch account {
        case .available:
            return String(localized: "Your logs are on this iPhone and copied to your own iCloud. Dawnwell has no server and never sees them.")
        case .noAccount:
            return String(localized: "Your logs are on this iPhone. Sign in to iCloud in Settings to keep a copy there, or save a backup file.")
        case .restricted:
            return String(localized: "iCloud is restricted on this iPhone, so your logs stay here. Save a backup file to keep a copy.")
        case .unavailable, .unknown:
            return String(localized: "Your logs are on this iPhone. The iCloud copy will catch up when iCloud is reachable.")
        }
    }
}
