import Foundation

/// The 30-day summary shown on Report and shared with the care team. Built from a snapshot, so it is pure and testable.
struct VisitSummary: Equatable {
    struct SymptomLine: Equatable {
        let kind: SymptomKind
        let days: Int
        let worst: Int
        let notes: [String]
    }

    /// The free summary covers 30 days; Plus can choose 90.
    static let span = 30
    static let plusSpan = 90

    let span: Int
    let from: String
    let to: String
    let medication: String
    let dose: String
    let daysTaken: Int
    let daysSkipped: Int
    let firstWeight: Double?
    let lastWeight: Double?
    let unit: WeightUnit
    let averageProtein: Int?
    let proteinTarget: Int
    let averageWater: Double?
    let symptoms: [SymptomLine]
    let doses: [Snapshot.DoseData]
    let questions: String

    var weightChange: Double? {
        guard let a = firstWeight, let b = lastWeight else { return nil }
        return b - a
    }

    static func make(from s: Snapshot, today: Date = Date(), calendar: Calendar = .current, span: Int = VisitSummary.span) -> VisitSummary {
        let range = DayKey.last(span, endingAt: today, calendar: calendar).map { DayKey.of($0, calendar: calendar) }
        let inRange = Set(range)
        let from = range.first ?? "", to = range.last ?? ""
        let days = s.days.filter { inRange.contains($0.day) }
        let foodsByDay = Dictionary(grouping: s.foods.filter { inRange.contains($0.day) }, by: \.day)
        let proteinDays = foodsByDay.values.map { $0.reduce(0) { $0 + $1.protein } }
        let waterDays = days.filter { $0.water > 0 }.map(\.water)
        let weights = s.weights.filter { inRange.contains($0.day) }.sorted { $0.day < $1.day }
        let symptomEntries = s.symptoms.filter { inRange.contains($0.day) }
        let lines: [SymptomLine] = SymptomKind.allCases.filter { $0 != .good }.compactMap { kind in
            let hits = symptomEntries.filter { $0.kind == kind.rawValue }
            guard !hits.isEmpty else { return nil }
            return SymptomLine(kind: kind, days: Set(hits.map(\.day)).count, worst: hits.map(\.severity).max() ?? 0,
                               notes: hits.map(\.note).filter { !$0.isEmpty })
        }.sorted { $0.days > $1.days }
        let p = s.profile
        return VisitSummary(
            span: span,
            from: from, to: to,
            medication: Medication(rawValue: p?.medication ?? "")?.label ?? String(localized: "GLP-1 tablet"),
            dose: p?.doseLabel ?? "",
            daysTaken: days.filter { $0.takenAt != nil }.count,
            daysSkipped: days.filter { $0.takenAt == nil && $0.skipped }.count,
            firstWeight: weights.count >= 2 ? weights.first?.value : nil,
            lastWeight: weights.count >= 2 ? weights.last?.value : nil,
            unit: WeightUnit(rawValue: p?.weightUnit ?? "") ?? .lb,
            averageProtein: proteinDays.isEmpty ? nil : Int((Double(proteinDays.reduce(0, +)) / Double(proteinDays.count)).rounded()),
            proteinTarget: p?.proteinTarget ?? 100,
            averageWater: waterDays.isEmpty ? nil : Double(waterDays.reduce(0, +)) / Double(waterDays.count),
            symptoms: lines,
            doses: s.doses.sorted { $0.from < $1.from },
            questions: p?.questions.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    var text: String {
        func short(_ key: String) -> String { DayKey.date(key).map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? key }
        let medicationLine = dose.isEmpty ? medication : String(localized: "\(medication), \(dose) daily")
        var tablet = String(localized: "Tablet logged taken on \(daysTaken) of \(span) days")
        if daysSkipped > 0 { tablet = String(localized: "\(tablet), skipped \(daysSkipped)") }
        var lines = [
            String(localized: "Dawnwell visit summary, \(short(from)) – \(short(to))"),
            "",
            String(localized: "Medication: \(medicationLine)"),
            tablet,
        ]
        if let a = firstWeight, let b = lastWeight, let c = weightChange {
            let first = Self.num(a), last = Self.num(b), unitName = unit.rawValue
            let change = "\(c > 0 ? "+" : "")\(Self.num(c))"
            lines.append(String(localized: "Weight: \(first) → \(last) \(unitName) (\(change))"))
        }
        if let p = averageProtein { lines.append(String(localized: "Protein: \(p) g a day on average (target \(proteinTarget) g)")) }
        if let w = averageWater {
            let glasses = Self.num(w)
            lines.append(String(localized: "Water: \(glasses) glasses a day on average"))
        }
        lines += ["", String(localized: "Symptoms:")]
        if symptoms.isEmpty { lines.append(String(localized: "- None logged")) }
        for s in symptoms {
            let name = s.kind.label
            lines.append(String(localized: "- \(name): \(s.days) days, worst \(s.worst)/5"))
            for n in s.notes.prefix(3) { lines.append("  \"\(n)\"") }
        }
        if !doses.isEmpty {
            lines += ["", String(localized: "Dose history:")]
            for d in doses {
                let label = Loc.doseDaily(d.label), from = short(d.from)
                lines.append(String(localized: "- \(label) from \(from)"))
            }
        }
        if !questions.isEmpty { lines += ["", String(localized: "My questions:"), questions] }
        lines += ["", String(localized: "Recorded by the patient in Dawnwell. Not medical advice.")]
        return lines.joined(separator: "\n")
    }

    /// One decimal, with the decimal mark of the user's region ("97.5", "97,5").
    static func num(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(1)).grouping(.never)) }
}
