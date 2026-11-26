import Foundation

/// Dawnwell Plus: what is paid and how plans compare. Pure, so it can be tested.
/// Free forever: tablet log, wait timer, reminders, protein, symptoms, backups and iCloud copy.
enum Plus {
    static let monthlyID = "com.dawnwell.app.plus.monthly"
    static let yearlyID = "com.dawnwell.app.plus.yearly"
    /// One payment, Plus for good. A non-consumable, so it restores like the subscriptions.
    static let lifetimeID = "com.dawnwell.app.plus.lifetime"
    /// The two plans in the one subscription group (one free week per Apple ID).
    static let subscriptionIDs = [monthlyID, yearlyID]
    static let productIDs = subscriptionIDs + [lifetimeID]

    /// The plans on the paywall, in the order shown.
    enum Plan: CaseIterable {
        case yearly, monthly, lifetime

        var productID: String {
            switch self {
            case .yearly: return Plus.yearlyID
            case .monthly: return Plus.monthlyID
            case .lifetime: return Plus.lifetimeID
            }
        }
    }
    /// Apple's standard licence. Guideline 3.1.2 asks for it and the privacy policy on the paywall.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    enum Feature: CaseIterable {
        case pdfReport, insights, longSummary

        var title: String {
            switch self {
            case .pdfReport: return String(localized: "Visit report as a PDF")
            case .insights: return String(localized: "Insights about your symptoms and food")
            case .longSummary: return String(localized: "Visit summary for the last 90 days")
            }
        }
    }

    /// What Plus adds, shown on the paywall: the everyday things first, the visit things after.
    static var benefits: [String] { [
        String(localized: "Your week at a glance: tablet, protein, water and symptoms, next to the week before"),
        String(localized: "Symptoms around each dose change, with days on every dose"),
        String(localized: "Insights: which foods and habits line up with your symptoms"),
        String(localized: "A clean PDF report and a 90-day summary for each visit"),
        String(localized: "Export everything to a spreadsheet (CSV)"),
    ] }

    /// Where the paywall was opened from. Sent with the paywall_shown event to see which way in sells.
    enum Source: String, Identifiable {
        case insights, weekSummary = "week_summary", doseHistory = "dose_history", reportPDF = "report_pdf"
        case report90 = "report_90", csvExport = "csv_export", design

        var id: String { rawValue }
    }

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
    static func buyTitle(plan: Plan = .yearly, hasFreeTrial: Bool, eligibleForTrial: Bool, price: String) -> String {
        if plan == .lifetime { return String(localized: "Buy once for \(price)") }
        return hasFreeTrial && eligibleForTrial ? String(localized: "Start free week, then \(price)") : String(localized: "Subscribe for \(price)")
    }
}
