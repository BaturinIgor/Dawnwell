import XCTest

/// Takes the App Store screenshots from the demo data. Run by the Screenshots and App Store workflows,
/// which set SCREENSHOT_DIR (and SCREENSHOT_LANG / SCREENSHOT_LOCALE for other languages);
/// otherwise the pictures are kept as test attachments.
///
/// Each store screenshot is the real screen under a headline (`-store-caption`), in the order that sells:
/// the wait timer first, then what Plus adds, then the visit summary. The headline comes from the app's
/// translations, so every language gets its own. Screens are found by tab position, scroll targets and
/// accessibility identifiers, never by text, so this works in every language.
final class ScreenshotTests: XCTestCase {
    private let env = ProcessInfo.processInfo.environment
    private var language: String { env["SCREENSHOT_LANG"].flatMap { $0.isEmpty ? nil : $0 } ?? "en" }
    private var locale: String { env["SCREENSHOT_LOCALE"].flatMap { $0.isEmpty ? nil : $0 } ?? "en_US" }

    override func setUp() {
        continueAfterFailure = false
    }

    /// (file name, caption, tab, card to scroll to)
    private let shots: [(String, String, Int, String?)] = [
        ("1-wait", "wait", 0, nil),
        ("2-week", "week", 1, "week"),
        ("3-doses", "doses", 1, "doses"),
        ("4-visit", "visit", 2, nil),
        ("5-protein", "protein", 1, "protein"),
        ("6-learn", "learn", 3, nil),
    ]

    func testAppStoreScreenshots() {
        for (name, caption, tab, scroll) in shots {
            var args = ["-design-plus", "-store-caption", caption, "-design-tab", String(tab)]
            if let scroll { args += ["-design-scroll", scroll] }
            let app = launch(args)
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "\(name): the app did not open")
            sleep(2)
            snap(name)
            app.terminate()
        }
        paywall()
    }

    /// The paywall without a headline, for the in-app purchase review. English only, and only once plans load.
    private func paywall() {
        guard language == "en" else { return }
        let app = launch(["-design-tab", "2"])
        let plus = app.buttons["plus-pdf"]
        guard plus.waitForExistence(timeout: 10) else { return }
        plus.tap()
        if app.buttons.matching(NSPredicate(format: "label CONTAINS 'Lifetime'")).firstMatch.waitForExistence(timeout: 15) {
            sleep(1)
            snap("paywall")
        }
        app.terminate()
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-design", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + extra
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = env["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? shot.pngRepresentation.write(to: url)
        }
    }
}
