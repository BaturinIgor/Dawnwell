import Foundation

/// Dawnwell Plus: what is paid and how plans compare. Pure, so it can be tested.
/// Free forever: tablet log, wait timer, reminders, protein, symptoms, backups and iCloud copy.
enum Plus {
    static let monthlyID = "com.dawnwell.app.plus.monthly"
    static let yearlyID = "com.dawnwell.app.plus.yearly"
    static let productIDs = [monthlyID, yearlyID]

    enum Feature: CaseIterable {
        case pdfReport, insights

        var title: String {
            switch self {
            case .pdfReport: return "Visit report as a PDF"
            case .insights: return "Insights about your symptoms and food"
            }
        }
    }

    /// What Plus adds, shown on the paywall.
    static let benefits = [
        "A clean PDF report to send or print for each visit",
        "Insights: which foods line up with your nausea",
        "Support a small, independent app",
    ]

    /// How much cheaper a year is than 12 months, in whole percent.
    static func yearlySaving(monthly: Decimal, yearly: Decimal) -> Int {
        let fullYear = monthly * 12
        guard fullYear > 0, yearly < fullYear else { return 0 }
        let ratio = NSDecimalNumber(decimal: (fullYear - yearly) / fullYear).doubleValue
        return Int((ratio * 100).rounded(.down))
    }

    /// The per-month price of a yearly plan, for display.
    static func perMonth(yearly: Decimal) -> Decimal {
        var raw = yearly / 12, out = Decimal()
        NSDecimalRound(&out, &raw, 2, .plain)
        return out
    }

    /// The buy button's text. The free week is promised only to someone Apple says can still get it:
    /// Apple gives one trial per Apple ID per subscription group, so after a trial or a past
    /// subscription the button shows the plain price instead.
    static func buyTitle(hasFreeTrial: Bool, eligibleForTrial: Bool, price: String) -> String {
        hasFreeTrial && eligibleForTrial ? "Start free week, then \(price)" : "Subscribe for \(price)"
    }
}
