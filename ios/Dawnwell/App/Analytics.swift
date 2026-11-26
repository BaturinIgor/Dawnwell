import FirebaseAnalytics
import FirebaseCore
import Foundation
import StoreKit

/// Anonymous usage through Google Analytics for Firebase: which steps people reach, never what they log.
/// No health data ever goes in an event: no medication, dose, weight, food, symptom, note or time of a dose.
/// No IDFA (FirebaseAnalyticsCore, no AdSupport); IDFV and ad signals are off in Info.plist.
/// Nothing is sent without GoogleService-Info.plist (only the TestFlight / App Store build gets it),
/// in tests and demo runs, in Debug builds, on the simulator, or after the user turns it off in "Your data".
@MainActor
enum Analytics {
    nonisolated static let optOutKey = "analyticsOptedOut"

    enum Event: String, CaseIterable {
        case onboardingFinished = "onboarding_finished"
        case tabletTaken = "tablet_taken"
        case paywallShown = "paywall_shown"
        case purchaseCompleted = "purchase_completed"
        case purchaseRestored = "purchase_restored"
        case reportShared = "report_shared"
    }

    private static var configured = false

    private static var configPath: String? { Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") }

    /// The build can send at all: it has the Firebase config and is a release build on a device.
    static var isAvailable: Bool {
        guard configPath != nil, !Persistence.isSandboxed else { return false }
        #if DEBUG || targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-AnalyticsDebug")
        #else
        return true
        #endif
    }

    nonisolated static func isUserEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: optOutKey)
    }

    static func start() {
        guard isAvailable, !configured, let path = configPath,
              // A broken plist would crash FirebaseApp.configure(); this way there is just no analytics.
              let options = FirebaseOptions(contentsOfFile: path) else { return }
        FirebaseApp.configure(options: options)
        configured = true
        // Collection is off in Info.plist (FIREBASE_ANALYTICS_COLLECTION_ENABLED = false) and only turned on here.
        let enabled = isUserEnabled()
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(enabled)
        if enabled { setBuildType() }
    }

    /// The switch in "Your data".
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(!enabled, forKey: optOutKey)
        guard configured else { return }
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(enabled)
        if enabled { setBuildType() } else { FirebaseAnalytics.Analytics.resetAnalyticsData() }
    }

    /// `parameters` must never carry anything the user logged. Plan and format names are fine.
    static func send(_ event: Event, _ parameters: [String: String] = [:]) {
        guard configured, isUserEnabled() else { return }
        FirebaseAnalytics.Analytics.logEvent(event.rawValue, parameters: parameters.isEmpty ? nil : parameters)
    }

    /// user property build_type (testflight / appstore), so reports can leave out test installs.
    private static func setBuildType() {
        Task {
            guard let result = try? await AppTransaction.shared else { return }
            let environment: AppStore.Environment
            switch result {
            case .verified(let t), .unverified(let t, _): environment = t.environment
            }
            FirebaseAnalytics.Analytics.setUserProperty(environment == .production ? "appstore" : "testflight", forName: "build_type")
        }
    }
}
