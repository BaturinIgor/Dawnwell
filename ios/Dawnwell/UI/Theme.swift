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

enum Palette {
    static let bg = Color(hex: 0xF4F5F1)
    static let card = Color.white
    static let ink = Color(hex: 0x16201B)
    static let inkSoft = Color(hex: 0x3E4842)
    static let muted = Color(hex: 0x56615A)
    static let line = Color(hex: 0xE3E7E1)
    static let lineSoft = Color(hex: 0xEEF0EB)
    static let field = Color(hex: 0xFAFBF8)
    static let fieldBorder = Color(hex: 0xDCE2DA)
    static let accent = Color(hex: 0x0F6B5C)
    static let accentDark = Color(hex: 0x0B4A40)
    static let accentSoft = Color(hex: 0xE6F1EE)
    static let warm = Color(hex: 0xE07B39)
    static let warmDark = Color(hex: 0xB85A1E)
    static let warmInk = Color(hex: 0x8A3E10)
    static let warmSoft = Color(hex: 0xFCE9DC)
    static let warmLight = Color(hex: 0xF2C29E)
    static let sand = Color(hex: 0xF4EFE2)
    static let sandInk = Color(hex: 0x5E4A12)
    static let neutralSoft = Color(hex: 0xF1F2EE)
}

enum Metrics {
    static let gutter: CGFloat = 20
    static let gap: CGFloat = 16
    static let radius: CGFloat = 24
    static let control: CGFloat = 52
}
