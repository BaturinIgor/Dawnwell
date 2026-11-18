import XCTest
@testable import Dawnwell

/// Keeps the chosen palette readable in both themes: text needs 4.5:1 (WCAG 2.2 AA), marks and bars need 3:1.
final class PaletteTests: XCTestCase {
    private typealias H = PaletteHex
    private let white: UInt32 = 0xFFFFFF

    private func check(_ name: String, _ fg: H.Pair, _ bg: H.Pair, min: Double, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(Contrast.ratio(fg.light, bg.light), min, "\(name), light", file: file, line: line)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(fg.dark, bg.dark), min, "\(name), dark", file: file, line: line)
    }

    private var onAccent: H.Pair { H.Pair(light: white, dark: white) }

    func testRatioMath() {
        XCTAssertEqual(Contrast.ratio(0x000000, 0xFFFFFF), 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio(0x777777, 0x777777), 1, accuracy: 0.001)
    }

    func testTextPairs() {
        check("ink on bg", H.ink, H.bg, min: 4.5)
        check("ink on card", H.ink, H.card, min: 4.5)
        check("inkSoft on card", H.inkSoft, H.card, min: 4.5)
        check("muted on bg", H.muted, H.bg, min: 4.5)
        check("muted on card", H.muted, H.card, min: 4.5)
        check("white on accent fill", onAccent, H.accent, min: 4.5)
        check("accentText on card", H.accentText, H.card, min: 4.5)
        check("accentText on bg", H.accentText, H.bg, min: 4.5)
        check("accentDark on accentSoft", H.accentDark, H.accentSoft, min: 4.5)
        check("warmDark on card", H.warmDark, H.card, min: 4.5)
        check("warmDark on warmSoft", H.warmDark, H.warmSoft, min: 4.5)
        check("warmInk on warmSoft", H.warmInk, H.warmSoft, min: 4.5)
        check("sandInk on sand", H.sandInk, H.sand, min: 4.5)
        check("onInk on ink", H.onInk, H.ink, min: 4.5)
    }

    func testMarksOnCard() {
        check("taken mark", H.accent, H.card, min: 3)
        check("skipped mark", H.warmMark, H.card, min: 3)
    }

    func testEveryDarkColorDiffersFromLight() {
        let all: [H.Pair] = [H.bg, H.card, H.ink, H.muted, H.accentText, H.warmSoft, H.sand]
        for p in all { XCTAssertNotEqual(p.light, p.dark) }
    }
}
