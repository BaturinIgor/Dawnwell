import Foundation

/// The 30-day summary shown on Report and shared with the care team. Built from a snapshot, so it is pure and testable.
struct VisitSummary: Equatable {
    struct SymptomLine: Equatable {
        let kind: SymptomKind
        let days: Int
        let worst: Int
        let notes: [String]
    }

    static let span = 30

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

    static func make(from s: Snapshot, today: Date = Date(), calendar: Calendar = .current) -> VisitSummary {
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
            from: from, to: to,
            medication: Medication(rawValue: p?.medication ?? "")?.label ?? "GLP-1 tablet",
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
        var lines = [
            "Dawnwell visit summary, \(short(from)) – \(short(to))",
            "",
            "Medication: \(medication)\(dose.isEmpty ? "" : ", \(dose) daily")",
            "Tablet logged taken on \(daysTaken) of \(Self.span) days\(daysSkipped > 0 ? ", skipped \(daysSkipped)" : "")",
        ]
        if let a = firstWeight, let b = lastWeight, let c = weightChange {
            lines.append("Weight: \(Self.num(a)) → \(Self.num(b)) \(unit.rawValue) (\(c > 0 ? "+" : "")\(Self.num(c)))")
        }
        if let p = averageProtein { lines.append("Protein: \(p) g a day on average (target \(proteinTarget) g)") }
        if let w = averageWater { lines.append("Water: \(String(format: "%.1f", w)) glasses a day on average") }
        lines += ["", "Symptoms:"]
        if symptoms.isEmpty { lines.append("- None logged") }
        for s in symptoms {
            lines.append("- \(s.kind.label): \(s.days) day\(s.days == 1 ? "" : "s"), worst \(s.worst)/5")
            for n in s.notes.prefix(3) { lines.append("  \"\(n)\"") }
        }
        if !doses.isEmpty {
            lines += ["", "Dose history:"]
            for d in doses { lines.append("- \(d.label) from \(short(d.from))") }
        }
        if !questions.isEmpty { lines += ["", "My questions:", questions] }
        lines += ["", "Recorded by the patient in Dawnwell. Not medical advice."]
        return lines.joined(separator: "\n")
    }

    static func num(_ v: Double) -> String { String(format: "%.1f", v) }
}
