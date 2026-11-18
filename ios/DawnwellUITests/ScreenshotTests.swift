import XCTest

/// Takes the App Store screenshots from the demo data. Run by the Screenshots and App Store workflows,
/// which set SCREENSHOT_DIR (and SCREENSHOT_LANG / SCREENSHOT_LOCALE for other languages);
/// otherwise the pictures are kept as test attachments.
/// It finds screens by tab position and accessibility identifiers, so it works in every language.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private let env = ProcessInfo.processInfo.environment
    private var language: String { env["SCREENSHOT_LANG"].flatMap { $0.isEmpty ? nil : $0 } ?? "en" }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        let locale = env["SCREENSHOT_LOCALE"].flatMap { $0.isEmpty ? nil : $0 } ?? "en_US"
        app.launchArguments += ["-demo", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
    }

    func testAppStoreScreenshots() {
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 15), "The app did not open")
        XCTAssertTrue(app.buttons["medication"].waitForExistence(timeout: 10), "Today screen did not open")
        sleep(1)
        snap("1-today")

        tabs.buttons.element(boundBy: 1).tap()
        sleep(1)
        snap("2-progress")

        tabs.buttons.element(boundBy: 2).tap()
        sleep(1)
        snap("3-report")

        // The paywall, for the in-app purchase review screenshot. English only, and only once plans load.
        let plus = app.buttons["plus-pdf"]
        if language == "en", plus.waitForExistence(timeout: 3) {
            plus.tap()
            if app.buttons.matching(NSPredicate(format: "label CONTAINS 'Lifetime'")).firstMatch.waitForExistence(timeout: 15) {
                sleep(1)
                snap("paywall")
            }
            let close = app.navigationBars.buttons.firstMatch
            if close.exists { close.tap() } else { app.swipeDown(velocity: .fast) }
            sleep(1)
        }

        tabs.buttons.element(boundBy: 3).tap()
        sleep(1)
        snap("4-learn")

        tabs.buttons.element(boundBy: 0).tap()
        let medication = app.buttons["medication"]
        if medication.waitForExistence(timeout: 5) {
            medication.tap()
            sleep(1)
            snap("5-medication")
        }
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
