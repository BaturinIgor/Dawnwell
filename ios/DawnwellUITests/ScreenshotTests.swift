import XCTest

/// Takes the App Store screenshots from the demo data. Run by the Screenshots workflow,
/// which sets SCREENSHOT_DIR; otherwise the pictures are kept as test attachments.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-demo", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testAppStoreScreenshots() {
        XCTAssertTrue(app.staticTexts["Protein today"].waitForExistence(timeout: 15), "Today screen did not open")
        snap("1-today")

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Weight"].waitForExistence(timeout: 5))
        snap("2-progress")

        app.tabBars.buttons["Report"].tap()
        XCTAssertTrue(app.staticTexts["Visit summary"].waitForExistence(timeout: 5))
        snap("3-report")

        app.tabBars.buttons["Learn"].tap()
        sleep(1)
        snap("4-learn")

        app.tabBars.buttons["Today"].tap()
        let medication = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Oral semaglutide'")).firstMatch
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
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? shot.pngRepresentation.write(to: url)
        }
    }
}
