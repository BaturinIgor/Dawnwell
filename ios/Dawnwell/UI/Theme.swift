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

/// The "Morning" palette Igor chose on 2026-11-18: deep green with apricot. Hex values are kept apart
/// so contrast can be checked in tests.
enum PaletteHex {
    static let bg: UInt32 = 0xF4F5F1
    static let ink: UInt32 = 0x16201B
    static let inkSoft: UInt32 = 0x3E4842
    static let muted: UInt32 = 0x56615A
    static let line: UInt32 = 0xE3E7E1
    static let lineSoft: UInt32 = 0xEEF0EB
    static let field: UInt32 = 0xFAFBF8
    static let fieldBorder: UInt32 = 0xDCE2DA
    static let accent: UInt32 = 0x0F6B5C
    static let accentDark: UInt32 = 0x0B4A40
    static let accentSoft: UInt32 = 0xE6F1EE
    static let warm: UInt32 = 0xE07B39
    static let warmDark: UInt32 = 0xA34A12
    static let warmInk: UInt32 = 0x8A3E10
    static let warmSoft: UInt32 = 0xFCE9DC
    static let warmLight: UInt32 = 0xF2C29E
    static let warmMark: UInt32 = 0xCC7339
    static let sand: UInt32 = 0xF4EFE2
    static let sandInk: UInt32 = 0x5E4A12
    static let neutralSoft: UInt32 = 0xF1F2EE
}

enum Palette {
    static let bg = Color(hex: PaletteHex.bg)
    static let card = Color.white
    static let ink = Color(hex: PaletteHex.ink)
    static let inkSoft = Color(hex: PaletteHex.inkSoft)
    static let muted = Color(hex: PaletteHex.muted)
    static let line = Color(hex: PaletteHex.line)
    static let lineSoft = Color(hex: PaletteHex.lineSoft)
    static let field = Color(hex: PaletteHex.field)
    static let fieldBorder = Color(hex: PaletteHex.fieldBorder)
    static let accent = Color(hex: PaletteHex.accent)
    static let accentDark = Color(hex: PaletteHex.accentDark)
    static let accentSoft = Color(hex: PaletteHex.accentSoft)
    static let warm = Color(hex: PaletteHex.warm)
    static let warmDark = Color(hex: PaletteHex.warmDark)
    static let warmInk = Color(hex: PaletteHex.warmInk)
    static let warmSoft = Color(hex: PaletteHex.warmSoft)
    static let warmLight = Color(hex: PaletteHex.warmLight)
    static let warmMark = Color(hex: PaletteHex.warmMark)
    static let sand = Color(hex: PaletteHex.sand)
    static let sandInk = Color(hex: PaletteHex.sandInk)
    static let neutralSoft = Color(hex: PaletteHex.neutralSoft)
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
