import Foundation

/// Rules for showing weight from Apple Health in Dawnwell. Pure, so it can be tested.
///
/// - Health readings are never saved in Dawnwell's store. They are read from Health when the
///   app opens and only joined with the user's own entries on screen. The store syncs to iCloud,
///   and App Review Guideline 5.1.3(ii) does not allow health data from HealthKit in iCloud.
/// - One weight per day, as everywhere in Dawnwell.
/// - A weight the user typed in Dawnwell is never replaced by one from Health.
/// - For a day with several Health readings, the latest one wins.
/// - Readings are converted to the user's unit and rounded to 0.1.
enum HealthImport {
    struct Sample: Equatable {
        let kilograms: Double
        let at: Date
    }

    struct Entry: Equatable {
        let day: String
        let value: Double
        let at: Date
    }

    static let poundsPerKilogram = 2.204_622_621_8

    static func convert(kilograms: Double, to unit: WeightUnit) -> Double {
        let v = unit == .kg ? kilograms : kilograms * poundsPerKilogram
        return (v * 10).rounded() / 10
    }

    /// New entries to add. `existingDays` are days that already have a weight in Dawnwell.
    static func entries(from samples: [Sample], existingDays: Set<String>, unit: WeightUnit,
                        calendar: Calendar = .current) -> [Entry] {
        var latest: [String: Sample] = [:]
        for s in samples where s.kilograms > 0 && s.kilograms < 700 {
            let day = DayKey.of(s.at, calendar: calendar)
            guard !existingDays.contains(day) else { continue }
            if let old = latest[day], old.at >= s.at { continue }
            latest[day] = s
        }
        return latest.map { Entry(day: $0.key, value: convert(kilograms: $0.value.kilograms, to: unit), at: $0.value.at) }
            .sorted { $0.day < $1.day }
    }

    /// The snapshot with Health readings added for days the user did not type a weight.
    /// Only for showing on screen and in the report; never written back to the store.
    static func adding(_ health: [Entry], to snapshot: Snapshot) -> Snapshot {
        let typed = Set(snapshot.weights.map(\.day))
        var out = snapshot
        out.weights += health.filter { !typed.contains($0.day) }.map { Snapshot.WeightData(day: $0.day, value: $0.value, at: $0.at) }
        return out
    }
}
