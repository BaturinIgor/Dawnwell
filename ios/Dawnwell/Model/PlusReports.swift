import Foundation

/// What happened on each dose the user logged: days on it, symptoms and weight. Pure, so it can be tested.
/// It only describes the user's own logs and never suggests a dose.
struct DoseHistory: Equatable {
    struct Period: Equatable {
        /// As stored, e.g. "7 mg daily". Show it with `Loc.doseDaily`.
        var label: String
        var from: String
        /// Last day on this dose: the day before the next change, or today.
        var through: String
        var days: Int
        var symptomDays: Int
        var nauseaDays: Int
        /// Average severity (1–5) of the symptoms logged on this dose.
        var averageSeverity: Double?
        /// Last weight on this dose minus the first one, when there are at least two.
        var weightChange: Double?
    }

    struct Week: Equatable {
        var start: String
        var symptomDays: Int
        /// The dose started in this week, if there was a change.
        var doseChange: String?
    }

    static let weekCount = 12

    /// Newest first.
    var periods: [Period]
    /// Oldest first, ending with the week that ends today.
    var weeks: [Week]

    /// Day number on the current dose, counting its first day as day 1.
    var currentDay: Int? { periods.first?.days }

    static func make(from s: Snapshot, today: Date = Date(), calendar: Calendar = .current) -> DoseHistory {
        let todayKey = DayKey.of(today, calendar: calendar)
        // One change per day: the last one entered that day wins. Changes dated after today are ignored.
        var byDay: [String: Snapshot.DoseData] = [:]
        for d in s.doses where DayKey.isValid(d.from) && d.from <= todayKey {
            if let old = byDay[d.from], old.at > d.at { continue }
            byDay[d.from] = d
        }
        let doses = byDay.values.sorted { $0.from < $1.from }
        let unwell = s.symptoms.filter { $0.kind != SymptomKind.good.rawValue }

        var periods: [Period] = []
        for (i, d) in doses.enumerated() {
            let through = i + 1 < doses.count ? (DayKey.adding(-1, to: doses[i + 1].from, calendar: calendar) ?? d.from) : todayKey
            guard through >= d.from else { continue }
            let inside = { (day: String) in day >= d.from && day <= through }
            let symptoms = unwell.filter { inside($0.day) }
            let weights = s.weights.filter { inside($0.day) }.sorted { ($0.day, $0.at) < ($1.day, $1.at) }
            periods.append(Period(
                label: d.label, from: d.from, through: through,
                days: days(from: d.from, through: through, calendar: calendar),
                symptomDays: Set(symptoms.map(\.day)).count,
                nauseaDays: Set(symptoms.filter { $0.kind == SymptomKind.nausea.rawValue }.map(\.day)).count,
                averageSeverity: symptoms.isEmpty ? nil : Double(symptoms.map(\.severity).reduce(0, +)) / Double(symptoms.count),
                weightChange: weights.count >= 2 ? weights[weights.count - 1].value - weights[0].value : nil
            ))
        }

        var weeks: [Week] = []
        let start = calendar.startOfDay(for: today)
        for w in (0..<weekCount).reversed() {
            guard let last = calendar.date(byAdding: .day, value: -7 * w, to: start),
                  let first = calendar.date(byAdding: .day, value: -6, to: last) else { continue }
            let a = DayKey.of(first, calendar: calendar), b = DayKey.of(last, calendar: calendar)
            weeks.append(Week(
                start: a,
                symptomDays: Set(unwell.filter { $0.day >= a && $0.day <= b }.map(\.day)).count,
                doseChange: doses.last { $0.from >= a && $0.from <= b }?.label
            ))
        }
        return DoseHistory(periods: periods.reversed(), weeks: weeks)
    }

    static func days(from a: String, through b: String, calendar: Calendar = .current) -> Int {
        guard let x = DayKey.date(a, calendar: calendar), let y = DayKey.date(b, calendar: calendar) else { return 0 }
        return (calendar.dateComponents([.day], from: x, to: y).day ?? 0) + 1
    }
}

/// The last seven days, ending today, next to the seven before. Pure, so it can be tested.
struct WeekSummary: Equatable {
    struct Numbers: Equatable {
        /// Days in the week the app was in use (not before setup).
        var trackedDays = 0
        var taken = 0
        var skipped = 0
        var proteinHitDays = 0
        /// Average protein on days with food logged.
        var proteinAverage: Int?
        var waterHitDays = 0
        var symptomDays = 0
        var topSymptom: SymptomKind?
        var strengthDays = 0
    }

    var start: String
    var end: String
    var now: Numbers
    var before: Numbers
    /// Latest weight in the week minus the latest weight before it.
    var weightChange: Double?
    var unit: WeightUnit

    var notLogged: Int { max(0, now.trackedDays - now.taken - now.skipped) }

    static func make(from s: Snapshot, today: Date = Date(), calendar: Calendar = .current) -> WeekSummary {
        let day0 = calendar.startOfDay(for: today)
        func key(_ offset: Int) -> String { DayKey.of(calendar.date(byAdding: .day, value: offset, to: day0) ?? day0, calendar: calendar) }
        let end = key(0), start = key(-6), beforeStart = key(-13), beforeEnd = key(-7)
        let since = s.profile.map { DayKey.of($0.createdAt, calendar: calendar) } ?? beforeStart
        let target = s.profile?.proteinTarget ?? 100, water = s.profile?.waterTarget ?? 8

        func numbers(_ a: String, _ b: String) -> Numbers {
            var n = Numbers()
            let first = max(a, since)
            n.trackedDays = first <= b ? DoseHistory.days(from: first, through: b, calendar: calendar) : 0
            let days = s.days.filter { $0.day >= a && $0.day <= b }
            n.taken = days.filter { $0.takenAt != nil }.count
            n.skipped = days.filter { $0.takenAt == nil && $0.skipped }.count
            n.waterHitDays = days.filter { $0.water >= water && water > 0 }.count
            n.strengthDays = days.filter { $0.strength > 0 }.count
            var protein: [String: Int] = [:]
            for f in s.foods where f.day >= a && f.day <= b { protein[f.day, default: 0] += f.protein }
            n.proteinHitDays = protein.values.filter { $0 >= target }.count
            n.proteinAverage = protein.isEmpty ? nil : protein.values.reduce(0, +) / protein.count
            let unwell = s.symptoms.filter { $0.day >= a && $0.day <= b && $0.kind != SymptomKind.good.rawValue }
            n.symptomDays = Set(unwell.map(\.day)).count
            let counts = Dictionary(grouping: unwell, by: \.kind).mapValues(\.count)
            // Ties go to the kind listed first, so the answer is the same every time.
            var top: SymptomKind?
            for k in SymptomKind.allCases where (counts[k.rawValue] ?? 0) > (top.flatMap { counts[$0.rawValue] } ?? 0) { top = k }
            n.topSymptom = top
            return n
        }

        let weights = s.weights.sorted { ($0.day, $0.at) < ($1.day, $1.at) }
        let latest = weights.last { $0.day >= start && $0.day <= end }
        let prior = weights.last { $0.day < start }
        let change = latest.flatMap { l in prior.map { l.value - $0.value } }
        return WeekSummary(start: start, end: end, now: numbers(start, end), before: numbers(beforeStart, beforeEnd),
                           weightChange: change, unit: WeightUnit(rawValue: s.profile?.weightUnit ?? "") ?? .lb)
    }
}

/// Spreadsheet files of everything the user logged. Plain CSV, one file per kind of record.
enum CSVExport {
    struct File: Equatable {
        var name: String
        var text: String
    }

    static func make(from s: Snapshot, timeZone: TimeZone = .current) -> [File] {
        let time = ISO8601DateFormatter()
        time.timeZone = timeZone
        time.formatOptions = [.withInternetDateTime]
        func t(_ d: Date?) -> String { d.map { time.string(from: $0) } ?? "" }

        var weightByDay: [String: Double] = [:]
        for w in s.weights.sorted(by: { $0.at < $1.at }) { weightByDay[w.day] = w.value }
        var proteinByDay: [String: Int] = [:]
        for f in s.foods { proteinByDay[f.day, default: 0] += f.protein }
        var symptomsByDay: [String: [String]] = [:]
        for x in s.symptoms.sorted(by: { $0.at < $1.at }) { symptomsByDay[x.day, default: []].append("\(x.kind) \(x.severity)") }
        let allDays = Set(s.days.map(\.day)).union(weightByDay.keys).union(proteinByDay.keys).union(symptomsByDay.keys).sorted()
        let dayLogs = Dictionary(s.days.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        let unit = s.profile?.weightUnit ?? "lb"

        var days = [row(["date", "tablet_taken_at", "tablet_skipped", "protein_g", "water_glasses", "fiber_g",
                         "strength", "food_noise", "weight_\(unit)", "symptoms"])]
        for d in allDays {
            let log = dayLogs[d]
            days.append(row([d, t(log?.takenAt), log?.skipped == true ? "yes" : "", proteinByDay[d].map(String.init) ?? "",
                             log.map { String($0.water) } ?? "", log.map { String($0.fiber) } ?? "",
                             log.map { String($0.strength) } ?? "", log?.foodNoise.map(String.init) ?? "",
                             weightByDay[d].map { String($0) } ?? "", (symptomsByDay[d] ?? []).joined(separator: "; ")]))
        }
        var foods = [row(["date", "time", "meal", "food", "protein_g"])]
        for f in s.foods.sorted(by: { $0.at < $1.at }) { foods.append(row([f.day, t(f.at), f.meal, f.name, String(f.protein)])) }
        var symptoms = [row(["date", "time", "symptom", "severity_1_to_5", "triggers", "note"])]
        for x in s.symptoms.sorted(by: { $0.at < $1.at }) {
            symptoms.append(row([x.day, t(x.at), x.kind, String(x.severity), x.triggers.joined(separator: "; "), x.note]))
        }
        var doses = [row(["from", "dose"])]
        for d in s.doses.sorted(by: { ($0.from, $0.at) < ($1.from, $1.at) }) { doses.append(row([d.from, d.label])) }

        func file(_ name: String, _ rows: [String]) -> File { File(name: "dawnwell-\(name).csv", text: rows.joined(separator: "\r\n") + "\r\n") }
        return [file("days", days), file("foods", foods), file("symptoms", symptoms), file("doses", doses)]
    }

    /// Writes the files to a fresh temporary folder and returns their URLs, for sharing.
    static func write(_ files: [File]) throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("csv-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try files.map { f in
            let url = dir.appendingPathComponent(f.name)
            try Data(f.text.utf8).write(to: url, options: .completeFileProtection)
            return url
        }
    }

    /// RFC 4180: quote a field that has a comma, quote, or line break, and double its quotes.
    /// A leading =, +, - or @ is prefixed with ' so a spreadsheet never runs a note as a formula.
    static func field(_ value: String) -> String {
        var v = value
        if let c = v.first, "=+-@".contains(c), Double(v) == nil { v = "'" + v }
        guard v.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return v }
        return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func row(_ fields: [String]) -> String { fields.map(field).joined(separator: ",") }
}
