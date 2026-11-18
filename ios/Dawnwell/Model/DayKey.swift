import Foundation

/// Days are stored as local calendar dates in `yyyy-MM-dd` form, so a log belongs to the day the user lived it.
enum DayKey {
    static func of(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func today(calendar: Calendar = .current) -> String { of(Date(), calendar: calendar) }

    /// Local midnight of a key, or nil when the key is malformed.
    static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, key.count == 10 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func isValid(_ key: String) -> Bool { date(key).map { of($0) == key } ?? false }

    static func adding(_ days: Int, to key: String, calendar: Calendar = .current) -> String? {
        guard let d = date(key, calendar: calendar), let moved = calendar.date(byAdding: .day, value: days, to: d) else { return nil }
        return of(moved, calendar: calendar)
    }

    /// The last `count` days ending at `end`, oldest first.
    static func last(_ count: Int, endingAt end: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: end)
        return (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: start) }
    }
}
