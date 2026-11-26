import Foundation
import TelemetryDeck

/// Anonymous usage counts, sent to TelemetryDeck: which steps people reach, never what they log.
/// No health data ever goes in a signal: no medication, dose, weight, food, symptom or time of a dose.
/// Off when `appID` is empty, in tests and demo runs, and when the user turns it off in "Your data".
enum Analytics {
    /// TelemetryDeck app ID. Not a secret: it ships inside the app either way.
    static let appID = ""
    static let optOutKey = "analyticsOptedOut"

    enum Event: String, CaseIterable {
        case onboardingFinished = "Onboarding.finished"
        case tabletTaken = "Tablet.taken"
        case paywallShown = "Paywall.shown"
        case purchaseCompleted = "Purchase.completed"
        case purchaseRestored = "Purchase.restored"
        case reportShared = "Report.shared"
    }

    private static var started = false

    static var isEnabled: Bool {
        !appID.isEmpty && !Persistence.isSandboxed && !UserDefaults.standard.bool(forKey: optOutKey)
    }

    static func start() {
        guard isEnabled, !started else { return }
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
        started = true
    }

    /// `parameters` must never carry anything the user logged. Plan names and screen names are fine.
    static func send(_ event: Event, _ parameters: [String: String] = [:]) {
        guard isEnabled else { return }
        start()
        TelemetryDeck.signal(event.rawValue, parameters: parameters)
    }
}
