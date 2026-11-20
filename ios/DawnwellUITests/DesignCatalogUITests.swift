import XCTest

/// Mockups of every screen, state and popup: design/<version>/screens.
/// Each picture is its own launch with `-demo -design ...` (see App/DesignGallery.swift), in light and dark.
/// Runs only when DESIGN_DIR is set (the Design screens workflow); skipped in every other test run.
final class DesignCatalogUITests: XCTestCase {
    private struct Shot {
        let name: String
        var args: [String] = []
        /// What to wait for before the picture: "tabs", "ready" (a sheet or pushed screen) or "alert".
        var wait = "tabs"
    }

    private static let shots: [Shot] = [
        Shot(name: "01-today"),
        Shot(name: "02-progress", args: ["-design-tab", "1"]),
        Shot(name: "03-report", args: ["-design-tab", "2"]),
        Shot(name: "04-learn", args: ["-design-tab", "3"]),
        Shot(name: "05-progress-plus", args: ["-design-tab", "1", "-design-plus"]),
        Shot(name: "06-report-plus", args: ["-design-tab", "2", "-design-plus"]),
        Shot(name: "07-today-empty", args: ["-design-empty"]),
        Shot(name: "08-progress-empty", args: ["-design-tab", "1", "-design-empty"]),
        Shot(name: "09-report-empty", args: ["-design-tab", "2", "-design-empty"]),
        Shot(name: "10-onboarding-welcome", args: ["-design-onboarding"], wait: "none"),
        Shot(name: "11-onboarding-tablet", args: ["-design-onboarding", "-design-step", "1"], wait: "none"),
        Shot(name: "12-onboarding-goals", args: ["-design-onboarding", "-design-step", "2"], wait: "none"),
        Shot(name: "13-medication", args: ["-design-screen", "medication"], wait: "ready"),
        Shot(name: "14-your-data", args: ["-design-screen", "data"], wait: "ready"),
        Shot(name: "15-your-data-restore-confirm", args: ["-design-screen", "data", "-design-alert", "restore"], wait: "alert"),
        Shot(name: "16-your-data-file-error", args: ["-design-screen", "data", "-design-alert", "fileError"], wait: "ready"),
        Shot(name: "17-log-food", args: ["-design-screen", "food"], wait: "ready"),
        Shot(name: "18-symptom", args: ["-design-screen", "symptom"], wait: "ready"),
        Shot(name: "19-symptom-good-day", args: ["-design-screen", "symptomGood"], wait: "ready"),
        Shot(name: "20-paywall", args: ["-design-screen", "paywall"], wait: "ready"),
        Shot(name: "21-storage-problem", args: ["-design-storage-problem"], wait: "none"),
    ]

    private static var outputDir: URL? {
        guard let path = ProcessInfo.processInfo.environment["DESIGN_DIR"], !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testLight() throws { try run(dark: false) }
    func testDark() throws { try run(dark: true) }

    private func run(dark: Bool) throws {
        guard let dir = Self.outputDir else {
            throw XCTSkip("DESIGN_DIR is not set: design screenshots are taken only by the Design screens workflow")
        }
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        let language = env["DESIGN_LANG"].flatMap { $0.isEmpty ? nil : $0 } ?? "en"
        let locale = env["DESIGN_LOCALE"].flatMap { $0.isEmpty ? nil : $0 } ?? "en_US"
        let theme = dark ? "dark" : "light"
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var missing: [String] = []
        for shot in Self.shots {
            let app = XCUIApplication()
            app.launchArguments = ["-demo", "-design", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
                + (dark ? ["-design-dark"] : []) + shot.args
            app.launch()
            let ready: Bool
            switch shot.wait {
            case "tabs": ready = app.tabBars.firstMatch.waitForExistence(timeout: 20)
            case "ready": ready = app.descendants(matching: .any).matching(identifier: "design.ready").firstMatch.waitForExistence(timeout: 20)
            case "alert": ready = app.sheets.firstMatch.waitForExistence(timeout: 10) || app.alerts.firstMatch.waitForExistence(timeout: 2)
            default: ready = app.wait(for: .runningForeground, timeout: 20)
            }
            if !ready { missing.append(shot.name) }
            sleep(2)
            if springboard.alerts.firstMatch.exists {
                try? XCUIScreen.main.screenshot().pngRepresentation
                    .write(to: dir.appendingPathComponent("\(shot.name)-permission-\(theme).png"))
                allowSystemAlerts(springboard)
                sleep(2)
            }
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: dir.appendingPathComponent("\(shot.name)-\(theme).png"))
            app.terminate()
            allowSystemAlerts(springboard)
        }
        let note = missing.isEmpty ? "all screens shown" : "not confirmed: " + missing.joined(separator: ", ")
        try? note.write(to: dir.appendingPathComponent("report-\(theme).txt"), atomically: true, encoding: .utf8)
        print("==== DESIGN \(theme): \(note)")
    }

    /// Answers system permission prompts so they don't cover the next pictures.
    private func allowSystemAlerts(_ springboard: XCUIApplication) {
        for _ in 0..<4 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 1) else { return }
            let button = ["Allow", "OK"].lazy.map { alert.buttons[$0] }.first { $0.exists }
                ?? alert.buttons.element(boundBy: alert.buttons.count - 1)
            button.tap()
            sleep(1)
        }
    }
}
