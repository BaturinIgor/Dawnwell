import Foundation

/// Stage tips and short articles. General information only: nothing here tells anyone what dose to take.
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

    static let stages: [Stage] = [
        Stage(upTo: 14, title: "Your first two weeks",
              tip: "Mild nausea is common at the start. Eat slowly, stop when you feel full, and go easy on fatty food."),
        Stage(upTo: 60, title: "Settling in",
              tip: "Your appetite may be smaller now. Put protein first on your plate so you still reach your target."),
        Stage(upTo: Int.max, title: "Keeping it going",
              tip: "Strength work two or three times a week helps you keep muscle. Keep logging so your visits stay easy."),
    ]

    static let articles: [Article] = [
        Article(title: "Why the empty-stomach wait matters", minutes: 2,
                body: "Oral GLP-1 tablets are absorbed best when your stomach is empty. Take the tablet with only the amount of water your label says, then wait the time on your label before food, drinks or other medicines. Eating too soon can mean less of the medicine gets absorbed. If you are unsure about your wait time, ask your pharmacist."),
        Article(title: "Protein: how much and from what", minutes: 3,
                body: "When you eat less, protein helps protect muscle. Many people aim for a portion of protein at every meal: Greek yogurt, eggs, cottage cheese, fish, chicken, tofu or a protein shake. Your care team can help you set a daily target that fits you."),
        Article(title: "Easing nausea", minutes: 2,
                body: "Smaller meals, eating slowly and stopping at the first sign of fullness all help. Fatty, fried and very sweet food is often harder. Sip water through the day. If nausea is severe, you keep vomiting, or you have strong stomach pain, contact your clinician."),
        Article(title: "Constipation and fiber", minutes: 2,
                body: "Less food often means less fiber and fluid. Add vegetables, berries, oats, beans or a fiber supplement, and drink water through the day. Tell your clinician if it lasts more than a few days."),
        Article(title: "If you miss a tablet", minutes: 1,
                body: "Follow the instructions on your medication guide or ask your pharmacist. Do not take two tablets to make up for a missed one. Log a skipped day in the app so your visit summary stays accurate."),
        Article(title: "Getting ready for your visit", minutes: 2,
                body: "Open the Report tab a day before. Add the questions you want to ask, then share the summary with yourself or your care team. Bring up any symptom that lasted more than a few days."),
    ]

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
