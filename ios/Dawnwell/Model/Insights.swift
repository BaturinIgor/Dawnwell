import Foundation

/// Dawnwell Plus insights: patterns in the user's own logs that line up with their symptoms.
/// Pure, built from a snapshot, so it can be tested. It only describes what was logged together;
/// it never says what caused a symptom and never suggests a dose.
struct Insights: Equatable {
    /// Days looked at.
    static let span = 90
    /// Days with something logged before any pattern is shown.
    static let minimumDays = 7

    enum Finding: Equatable {
        /// A trigger the user marked on several entries of one symptom.
        case trigger(SymptomKind, trigger: String, hits: Int, of: Int)
        /// A symptom showed up on most days a food was eaten, more often than on other days.
        case food(SymptomKind, food: String, hits: Int, of: Int, otherHits: Int, otherOf: Int)
        /// A symptom on days the user ate before the empty-stomach wait was over, against other tablet days.
        case ateEarly(SymptomKind, hits: Int, of: Int, otherHits: Int, otherOf: Int)
        /// A symptom on days with a meal from 8 PM on, against other days.
        case lateMeal(SymptomKind, hits: Int, of: Int, otherHits: Int, otherOf: Int)
        /// Average protein on days with a symptom, against days without.
        case protein(SymptomKind, with: Int, without: Int)
        /// Average water on days with a symptom, against days without.
        case water(SymptomKind, with: Double, without: Double)

        /// One line, led by the symptom so it reads the same in every language.
        var text: String {
            switch self {
            case let Finding.trigger(kind, trigger, hits, of):
                let name = kind.label, cause = Loc.text(trigger)
                return String(localized: "\(name): “\(cause)” marked on \(hits) of \(of) entries.")
            case let Finding.food(kind, food, hits, of, otherHits, otherOf):
                let name = kind.label, item = Self.foodName(food)
                return String(localized: "\(name): on \(hits) of \(of) days with \(item), and on \(otherHits) of \(otherOf) other days.")
            case let Finding.ateEarly(kind, hits, of, otherHits, otherOf):
                let name = kind.label
                return String(localized: "\(name): on \(hits) of \(of) days you ate before the wait was over, and on \(otherHits) of \(otherOf) other tablet days.")
            case let Finding.lateMeal(kind, hits, of, otherHits, otherOf):
                let name = kind.label
                return String(localized: "\(name): on \(hits) of \(of) days with a meal after 8 PM, and on \(otherHits) of \(otherOf) other days.")
            case let Finding.protein(kind, with, without):
                let name = kind.label
                return String(localized: "\(name): on those days you ate \(with) g of protein on average, and \(without) g on other days.")
            case let Finding.water(kind, with, without):
                let name = kind.label, a = VisitSummary.num(with), b = VisitSummary.num(without)
                return String(localized: "\(name): on those days you drank \(a) glasses of water on average, and \(b) on other days.")
            }
        }

        /// The short catalog name when there is one ("Greek yogurt"), else what the user typed.
        static func foodName(_ stored: String) -> String {
            Catalog.foods.first { $0.name == stored }?.shortName ?? Loc.text(stored)
        }
    }

    /// Days with anything logged in the period.
    let loggedDays: Int
    let findings: [Finding]
    /// Days with at least one symptom in each of the last 4 weeks, oldest first.
    let symptomWeeks: [Int]

    var hasEnoughData: Bool { loggedDays >= Self.minimumDays }

    static func make(from s: Snapshot, today: Date = Date(), calendar: Calendar = .current) -> Insights {
        let range = DayKey.last(span, endingAt: today, calendar: calendar).map { DayKey.of($0, calendar: calendar) }
        let inRange = Set(range)
        let days = s.days.filter { inRange.contains($0.day) }
        let foods = s.foods.filter { inRange.contains($0.day) }
        let symptoms = s.symptoms.filter { inRange.contains($0.day) && $0.kind != SymptomKind.good.rawValue }
        let dayLog = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { a, b in a.takenAt != nil ? a : b })
        let foodDays = Set(foods.map(\.day))
        let logged = Set(days.filter { $0.takenAt != nil || $0.skipped || $0.water > 0 || $0.foodNoise != nil }.map(\.day))
            .union(foodDays).union(symptoms.map(\.day))

        // Symptom days per kind; a symptom logged after midnight still counts for the day it was logged on.
        var symptomDays: [SymptomKind: Set<String>] = [:]
        for e in symptoms {
            if let k = SymptomKind(rawValue: e.kind) { symptomDays[k, default: []].insert(e.day) }
        }
        let kinds = SymptomKind.allCases.filter { $0 != .good && (symptomDays[$0]?.count ?? 0) >= 2 }

        var findings: [(score: Double, finding: Finding)] = []

        // Triggers the user marked themselves.
        for kind in kinds {
            let entries = symptoms.filter { $0.kind == kind.rawValue }
            let counts = Dictionary(grouping: entries.flatMap(\.triggers).filter { $0 != "Not sure" }, by: { $0 }).mapValues(\.count)
            if let top = counts.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }),
               top.value >= 2 {
                findings.append((Double(top.value) / Double(entries.count) + 1,
                                 Finding.trigger(kind, trigger: top.key, hits: top.value, of: entries.count)))
            }
        }

        // Compare symptom days in a group of days against the other days.
        struct Split { let hits, of, otherHits, otherOf: Int; let lift: Double }
        func compare(_ kind: SymptomKind, group: Set<String>, among all: Set<String>) -> Split? {
            let hit = symptomDays[kind] ?? []
            let rest = all.subtracting(group)
            guard group.count >= 3, rest.count >= 3 else { return nil }
            let a = group.intersection(hit).count, b = rest.intersection(hit).count
            let rateA = Double(a) / Double(group.count), rateB = Double(b) / Double(rest.count)
            guard a >= 2, rateA >= 0.4, rateA >= rateB * 1.5 + 0.1 else { return nil }
            return Split(hits: a, of: group.count, otherHits: b, otherOf: rest.count, lift: rateA - rateB)
        }

        // Foods.
        let daysByFood = Dictionary(grouping: foods, by: \.name).mapValues { Set($0.map(\.day)) }
        for kind in kinds where [.nausea, .heartburn, .constipation].contains(kind) {
            var best: [(Double, Finding)] = []
            // Sorted, so ties come out the same every time.
            for (name, eaten) in daysByFood.sorted(by: { $0.key < $1.key }) {
                if let r = compare(kind, group: eaten, among: foodDays) {
                    best.append((r.lift, Finding.food(kind, food: name, hits: r.hits, of: r.of, otherHits: r.otherHits, otherOf: r.otherOf)))
                }
            }
            for b in best.sorted(by: { $0.0 > $1.0 }).prefix(2) { findings.append((score: b.0, finding: b.1)) }
        }

        // Eating before the wait was over.
        let wait = TimeInterval((s.profile?.waitMinutes ?? 30) * 60)
        let tabletDays = Set(days.filter { $0.takenAt != nil && foodDays.contains($0.day) }.map(\.day))
        let early = Set(tabletDays.filter { day in
            guard let taken = dayLog[day]?.takenAt else { return false }
            return foods.contains { $0.day == day && $0.at >= taken.addingTimeInterval(-3 * 3600) && $0.at < taken.addingTimeInterval(wait) }
        })
        for kind in kinds where [.nausea, .heartburn].contains(kind) {
            if let r = compare(kind, group: early, among: tabletDays) {
                findings.append((r.lift, Finding.ateEarly(kind, hits: r.hits, of: r.of, otherHits: r.otherHits, otherOf: r.otherOf)))
            }
        }

        // Late meals.
        let late = Set(foods.filter { calendar.component(.hour, from: $0.at) >= 20 }.map(\.day))
        for kind in kinds where [.nausea, .heartburn].contains(kind) {
            if let r = compare(kind, group: late, among: foodDays) {
                findings.append((r.lift, Finding.lateMeal(kind, hits: r.hits, of: r.of, otherHits: r.otherHits, otherOf: r.otherOf)))
            }
        }

        // Protein and water.
        let proteinByDay = Dictionary(grouping: foods, by: \.day).mapValues { $0.reduce(0) { $0 + $1.protein } }
        if let nausea = symptomDays[.nausea], kinds.contains(.nausea) {
            let with = proteinByDay.filter { nausea.contains($0.key) }.map(\.value)
            let without = proteinByDay.filter { !nausea.contains($0.key) }.map(\.value)
            if with.count >= 3, without.count >= 3 {
                let a = with.reduce(0, +) / with.count, b = without.reduce(0, +) / without.count
                if b > 0, Double(b - a) / Double(b) >= 0.2 {
                    findings.append((Double(b - a) / Double(b), Finding.protein(.nausea, with: a, without: b)))
                }
            }
        }
        if let constipation = symptomDays[.constipation], kinds.contains(.constipation) {
            let water = days.filter { $0.water > 0 }
            let with = water.filter { constipation.contains($0.day) }.map(\.water)
            let without = water.filter { !constipation.contains($0.day) }.map(\.water)
            if with.count >= 3, without.count >= 3 {
                let a = Double(with.reduce(0, +)) / Double(with.count), b = Double(without.reduce(0, +)) / Double(without.count)
                if b > 0, (b - a) / b >= 0.2 { findings.append(((b - a) / b, Finding.water(.constipation, with: a, without: b))) }
            }
        }

        // Weekly symptom days, last 4 weeks.
        let allSymptomDays = Set(symptoms.map(\.day))
        let last28 = Array(range.suffix(28))
        let weeks = stride(from: 0, to: last28.count, by: 7).map { i in
            last28[i..<min(i + 7, last28.count)].filter { allSymptomDays.contains($0) }.count
        }

        return Insights(
            loggedDays: logged.count,
            findings: findings.sorted { $0.score > $1.score }.prefix(6).map(\.finding),
            symptomWeeks: weeks
        )
    }
}
