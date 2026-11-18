import Foundation

/// Translations for text known only at run time.
///
/// Most text is translated where it is written: SwiftUI looks up `Text("…")` literals, and
/// model code uses `String(localized:)`. Some values are stored in English on purpose so data
/// stays the same in every language: food names, triggers and dose labels. They are translated
/// here, only for display. The keys live in `Localization/<lang>.lproj/Localizable.strings`.
enum Loc {
    /// The translation of a stored English value, or the value itself when there is none
    /// (for example a food the user typed).
    static func text(_ key: String, bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// "7 mg daily" in the user's language. Dose changes saved before 1.0 kept the English
    /// word "daily" in the label; it is taken off before translating.
    static func doseDaily(_ label: String) -> String {
        let base = label.hasSuffix(" daily") ? String(label.dropLast(" daily".count)) : label
        return String(localized: "\(base) daily")
    }
}
