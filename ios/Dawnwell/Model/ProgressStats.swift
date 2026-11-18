import Foundation

/// Numbers for the Progress tab, built from a snapshot so they can be tested without a store.
struct ProgressStats: Equatable {
    enum TabletMark: Equatable { case taken, skipped, none }

    struct ProteinDay: Equatable {
        let day: String
        let grams: Int
    }

    struct TabletDay: Equatable {
        let day: String
        let mark: TabletMark
    }

    struct WeightPoint: Equatable {
        let day: String
        let value: Double
    }

    let unit: WeightUnit
    let weights: [WeightPoint]
    let goalWeight: Double?
    /// Start weight minus latest weight. Positive means weight went down.
    let changeSinceStart: Double?
    let toGoal: Double?
    let proteinTarget: Int
    let proteinWeek: [ProteinDay]
    let tabletGrid: [TabletDay]
    let noiseNow: Double?
    let noiseBefore: Double?

    var latest: WeightPoint? { weights.last }
    var proteinHitDays: Int { proteinWeek.filter { $0.grams >= proteinTarget && proteinTarget > 0 }.count }
    var takenCount: Int { tabletGrid.filter { $0.mark == .taken }.count }

    static func make(from s: Snapshot, today: Date = Date(), calendar: Calendar = .current) -> ProgressStats {
        let p = s.profile
        // One point per day: the last entry logged that day wins.
        var byDay: [String: Snapshot.WeightData] = [:]
        for w in s.weights where w.value > 0 {
            if let old = byDay[w.day], old.at > w.at { continue }
            byDay[w.day] = w
        }
        let weights = byDay.values.sorted { $0.day < $1.day }.map { WeightPoint(day: $0.day, value: $0.value) }
        let start = p?.startWeight ?? weights.first?.value
        let latest = weights.last?.value
        let change = (start != nil && latest != nil) ? start! - latest! : nil
        let goal = p?.goalWeight
        let toGoal = (goal != nil && latest != nil) ? latest! - goal! : nil

        let keys = { (n: Int) in DayKey.last(n, endingAt: today, calendar: calendar).map { DayKey.of($0, calendar: calendar) } }
        let proteinByDay = Dictionary(grouping: s.foods, by: \.day).mapValues { $0.reduce(0) { $0 + $1.protein } }
        let proteinWeek = keys(7).map { ProteinDay(day: $0, grams: proteinByDay[$0] ?? 0) }

        let dayLogs = Dictionary(s.days.map { ($0.day, $0) }, uniquingKeysWith: { a, b in a.takenAt != nil ? a : b })
        let grid = keys(28).map { key -> TabletDay in
            guard let d = dayLogs[key] else { return TabletDay(day: key, mark: .none) }
            return TabletDay(day: key, mark: d.takenAt != nil ? .taken : d.skipped ? .skipped : .none)
        }

        let noise = keys(14).compactMap { dayLogs[$0]?.foodNoise }
        let half = noise.count / 2
        func avg(_ xs: ArraySlice<Int>) -> Double? { xs.isEmpty ? nil : Double(xs.reduce(0, +)) / Double(xs.count) }

        return ProgressStats(
            unit: WeightUnit(rawValue: p?.weightUnit ?? "") ?? .lb,
            weights: weights,
            goalWeight: goal,
            changeSinceStart: change,
            toGoal: toGoal,
            proteinTarget: p?.proteinTarget ?? 100,
            proteinWeek: proteinWeek,
            tabletGrid: grid,
            noiseNow: avg(noise[half...]),
            noiseBefore: avg(noise[..<half])
        )
    }
}

extension Repository {
    /// One weight per day: logging again on the same day replaces that day's value.
    func logWeight(_ value: Double, day key: String = DayKey.today(), at: Date = Date()) {
        guard value > 0, value.isFinite else { return }
        let d = FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.day == key })
        for old in (try? context.fetch(d)) ?? [] { context.delete(old) }
        context.insert(WeightEntry(day: key, value: value, at: at))
        save()
    }
}
