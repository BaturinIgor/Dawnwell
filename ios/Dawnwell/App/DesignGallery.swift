import SwiftUI

/// Mockups of every screen, state and popup (design/<version>/screens).
/// With `-demo -design -design-screen <id>` the app opens that screen straight away on the demo data;
/// DesignCatalogUITests takes the screenshots. Debug builds only: in release every value here is the
/// app's normal default.
enum DesignFlags {
    static func has(_ flag: String) -> Bool {
        #if DEBUG
        return Persistence.isDemo && ProcessInfo.processInfo.arguments.contains(flag)
        #else
        return false
        #endif
    }

    static func argument(_ name: String) -> String? {
        #if DEBUG
        guard Persistence.isDemo else { return nil }
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }

    /// First tab to show (0 Today, 1 Progress, 2 Report, 3 Learn).
    static var initialTab: Int { Int(argument("-design-tab") ?? "") ?? 0 }
    /// First onboarding step (0 welcome, 1 tablet, 2 goals).
    static var onboardingStep: Int { Int(argument("-design-step") ?? "") ?? 0 }
    /// Plus unlocked without a purchase.
    static var plus: Bool { has("-design-plus") }
    static var alert: String? { argument("-design-alert") }
}

#if DEBUG
enum DesignScreen: String, Identifiable {
    case medication, data, food, symptom, symptomGood, paywall

    var id: String { rawValue }
    var isPush: Bool { self == .medication || self == .data }

    static var requested: DesignScreen? { DesignFlags.argument("-design-screen").flatMap(DesignScreen.init(rawValue:)) }

    @MainActor @ViewBuilder
    var content: some View {
        switch self {
        case .medication: MedicationView()
        case .data: DataView()
        case .food: LogFoodView(day: DayKey.today())
        case .symptom: SymptomDetailView(day: DayKey.today(), initial: .nausea)
        case .symptomGood: SymptomDetailView(day: DayKey.today(), initial: .good)
        case .paywall: PaywallView()
        }
    }
}

/// Opens the requested screen over the app the way the app itself shows it.
struct DesignPresenter: ViewModifier {
    @State private var sheet: DesignScreen?
    @State private var push: DesignScreen?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let push {
                    NavigationStack { push.content }
                        .background(Palette.bg.ignoresSafeArea())
                        .accessibilityIdentifier("design.ready")
                }
            }
            .sheet(item: $sheet) { screen in
                screen.content.accessibilityIdentifier("design.ready")
            }
            .task {
                if DesignFlags.has("-design-dark") {
                    for scene in UIApplication.shared.connectedScenes {
                        (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = .dark }
                    }
                }
                guard let screen = DesignScreen.requested else { return }
                if screen.isPush {
                    push = screen
                } else {
                    try? await Task.sleep(for: .milliseconds(300))
                    sheet = screen
                }
            }
    }
}
#endif

extension View {
    /// Debug builds only: the design catalog opens this screen's popup by itself.
    @ViewBuilder
    func designPresenter() -> some View {
        #if DEBUG
        modifier(DesignPresenter())
        #else
        self
        #endif
    }
}
