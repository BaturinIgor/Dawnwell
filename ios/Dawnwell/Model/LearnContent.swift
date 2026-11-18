import Foundation

/// Stage tips and short articles. General information only: nothing here tells anyone what dose to take.
/// Computed, so the text follows the language the app runs in.
enum LearnContent {
    struct Stage: Equatable {
        let upTo: Int
        let title: String
        let tip: String
    }

    struct Article: Identifiable, Equatable {
        let title: String
        let minutes: Int
        let body: String
        var id: String { title }
    }

    static var stages: [Stage] { [
        Stage(upTo: 14, title: String(localized: "Your first two weeks"),
              tip: String(localized: "Mild nausea is common at the start. Eat slowly, stop when you feel full, and go easy on fatty food.")),
        Stage(upTo: 60, title: String(localized: "Settling in"),
              tip: String(localized: "Your appetite may be smaller now. Put protein first on your plate so you still reach your target.")),
        Stage(upTo: Int.max, title: String(localized: "Keeping it going"),
              tip: String(localized: "Strength work two or three times a week helps you keep muscle. Keep logging so your visits stay easy.")),
    ] }

    static var articles: [Article] { [
        Article(title: String(localized: "Why the empty-stomach wait matters"), minutes: 2,
                body: String(localized: "Oral GLP-1 tablets are absorbed best when your stomach is empty. Take the tablet with only the amount of water your label says, then wait the time on your label before food, drinks or other medicines. Eating too soon can mean less of the medicine gets absorbed. If you are unsure about your wait time, ask your pharmacist.")),
        Article(title: String(localized: "Protein: how much and from what"), minutes: 3,
                body: String(localized: "When you eat less, protein helps protect muscle. Many people aim for a portion of protein at every meal: Greek yogurt, eggs, cottage cheese, fish, chicken, tofu or a protein shake. Your care team can help you set a daily target that fits you.")),
        Article(title: String(localized: "Easing nausea"), minutes: 2,
                body: String(localized: "Smaller meals, eating slowly and stopping at the first sign of fullness all help. Fatty, fried and very sweet food is often harder. Sip water through the day. If nausea is severe, you keep vomiting, or you have strong stomach pain, contact your clinician.")),
        Article(title: String(localized: "Constipation and fiber"), minutes: 2,
                body: String(localized: "Less food often means less fiber and fluid. Add vegetables, berries, oats, beans or a fiber supplement, and drink water through the day. Tell your clinician if it lasts more than a few days.")),
        Article(title: String(localized: "If you miss a tablet"), minutes: 1,
                body: String(localized: "Follow the instructions on your medication guide or ask your pharmacist. Do not take two tablets to make up for a missed one. Log a skipped day in the app so your visit summary stays accurate.")),
        Article(title: String(localized: "Getting ready for your visit"), minutes: 2,
                body: String(localized: "Open the Report tab a day before. Add the questions you want to ask, then share the summary with yourself or your care team. Bring up any symptom that lasted more than a few days.")),
    ] }

    /// The first day the user was on the app: earliest dose change, else earliest log.
    static func startDay(_ s: Snapshot) -> String? {
        let candidates = s.doses.map(\.from) + s.days.map(\.day)
        return candidates.filter(DayKey.isValid).min()
    }

    /// Day 1 is the start day. Never less than 1.
    static func dayNumber(start: String?, today: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let start, let from = DayKey.date(start, calendar: calendar) else { return 1 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: today)).day ?? 0
        return max(1, days + 1)
    }

    static func stage(for day: Int) -> Stage {
        stages.first { day <= $0.upTo } ?? stages[stages.count - 1]
    }
}
