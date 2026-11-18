import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// The "Morning" palette Igor chose on 2026-11-18: deep green with apricot, with a dark pair for each color.
/// Hex values are kept apart so contrast can be checked in tests for both themes.
enum PaletteHex {
    struct Pair {
        let light: UInt32
        let dark: UInt32
    }

    static let bg = Pair(light: 0xF4F5F1, dark: 0x111614)
    static let card = Pair(light: 0xFFFFFF, dark: 0x1C2320)
    static let ink = Pair(light: 0x16201B, dark: 0xE9EEEA)
    static let inkSoft = Pair(light: 0x3E4842, dark: 0xC3CCC6)
    static let muted = Pair(light: 0x56615A, dark: 0x98A39C)
    static let line = Pair(light: 0xE3E7E1, dark: 0x2E3733)
    static let lineSoft = Pair(light: 0xEEF0EB, dark: 0x262E2A)
    static let field = Pair(light: 0xFAFBF8, dark: 0x182019)
    static let fieldBorder = Pair(light: 0xDCE2DA, dark: 0x3A4540)
    static let buttonBorder = Pair(light: 0xCBD3C9, dark: 0x3A4540)
    static let accent = Pair(light: 0x0F6B5C, dark: 0x14806C)
    static let accentDark = Pair(light: 0x0B4A40, dark: 0x9FE3D1)
    static let accentSoft = Pair(light: 0xE6F1EE, dark: 0x173A32)
    static let accentText = Pair(light: 0x0F6B5C, dark: 0x5CC8AE)
    static let warm = Pair(light: 0xE07B39, dark: 0xE88A4C)
    static let warmDark = Pair(light: 0xA34A12, dark: 0xF0A06A)
    static let warmInk = Pair(light: 0x8A3E10, dark: 0xF6C29C)
    static let warmSoft = Pair(light: 0xFCE9DC, dark: 0x3A2417)
    static let warmLight = Pair(light: 0xF2C29E, dark: 0x7A4A2C)
    static let warmMark = Pair(light: 0xCC7339, dark: 0xD9824A)
    static let sand = Pair(light: 0xF4EFE2, dark: 0x2B2619)
    static let sandInk = Pair(light: 0x5E4A12, dark: 0xE6D3A1)
    static let neutralSoft = Pair(light: 0xF1F2EE, dark: 0x252C29)
    static let onInk = Pair(light: 0xFFFFFF, dark: 0x111614)
}

/// Colors follow the system appearance. Text on `accent` fills stays white in both themes.
enum Palette {
    static let bg = Color(PaletteHex.bg)
    static let card = Color(PaletteHex.card)
    static let ink = Color(PaletteHex.ink)
    static let inkSoft = Color(PaletteHex.inkSoft)
    static let muted = Color(PaletteHex.muted)
    static let line = Color(PaletteHex.line)
    static let lineSoft = Color(PaletteHex.lineSoft)
    static let field = Color(PaletteHex.field)
    static let fieldBorder = Color(PaletteHex.fieldBorder)
    static let buttonBorder = Color(PaletteHex.buttonBorder)
    static let accent = Color(PaletteHex.accent)
    static let accentDark = Color(PaletteHex.accentDark)
    static let accentSoft = Color(PaletteHex.accentSoft)
    static let accentText = Color(PaletteHex.accentText)
    static let warm = Color(PaletteHex.warm)
    static let warmDark = Color(PaletteHex.warmDark)
    static let warmInk = Color(PaletteHex.warmInk)
    static let warmSoft = Color(PaletteHex.warmSoft)
    static let warmLight = Color(PaletteHex.warmLight)
    static let warmMark = Color(PaletteHex.warmMark)
    static let sand = Color(PaletteHex.sand)
    static let sandInk = Color(PaletteHex.sandInk)
    static let neutralSoft = Color(PaletteHex.neutralSoft)
    static let onInk = Color(PaletteHex.onInk)
}

extension Color {
    init(_ pair: PaletteHex.Pair) {
        self.init(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? pair.dark : pair.light))
        })
    }
}

/// WCAG 2.2 contrast ratio between two sRGB colors.
enum Contrast {
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let c = Double((hex >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}

enum Metrics {
    static let gutter: CGFloat = 20
    static let gap: CGFloat = 16
    static let radius: CGFloat = 24
    static let control: CGFloat = 52
}
