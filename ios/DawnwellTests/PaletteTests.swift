import XCTest
@testable import Dawnwell

/// Keeps the chosen palette readable: text needs 4.5:1 (WCAG 2.2 AA), marks and bars need 3:1.
final class PaletteTests: XCTestCase {
    private let white: UInt32 = 0xFFFFFF

    func testRatioMath() {
        XCTAssertEqual(Contrast.ratio(0x000000, 0xFFFFFF), 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio(0x777777, 0x777777), 1, accuracy: 0.001)
    }

    func testTextPairs() {
        let pairs: [(String, UInt32, UInt32)] = [
            ("ink on bg", PaletteHex.ink, PaletteHex.bg),
            ("muted on bg", PaletteHex.muted, PaletteHex.bg),
            ("muted on card", PaletteHex.muted, white),
            ("white on accent button", white, PaletteHex.accent),
            ("accentDark on accentSoft", PaletteHex.accentDark, PaletteHex.accentSoft),
            ("warmDark on card", PaletteHex.warmDark, white),
            ("white on warmDark", white, PaletteHex.warmDark),
            ("warmInk on warmSoft", PaletteHex.warmInk, PaletteHex.warmSoft),
            ("sandInk on sand", PaletteHex.sandInk, PaletteHex.sand),
        ]
        for (name, fg, bg) in pairs {
            XCTAssertGreaterThanOrEqual(Contrast.ratio(fg, bg), 4.5, name)
        }
    }

    func testMarksOnCard() {
        XCTAssertGreaterThanOrEqual(Contrast.ratio(PaletteHex.accent, white), 3, "taken mark")
        XCTAssertGreaterThanOrEqual(Contrast.ratio(PaletteHex.warmMark, white), 3, "skipped mark")
    }
}
