import Foundation

/// Where today's tablet stands. Pure, so it can be tested with any clock.
enum TabletState: Equatable {
    /// Not logged yet. `overdue` once two hours have passed since the usual time.
    case pending(overdue: Bool)
    case skipped
    /// Logged, still inside the empty-stomach wait.
    case waiting(until: Date)
    /// Logged and the wait is over.
    case clear

    static let overdueAfter: TimeInterval = 2 * 3600

    static func of(takenAt: Date?, skipped: Bool, waitMinutes: Int, doseHour: Int, doseMinute: Int,
                   now: Date, calendar: Calendar = .current) -> TabletState {
        if let takenAt {
            let until = takenAt.addingTimeInterval(TimeInterval(waitMinutes * 60))
            return now < until ? .waiting(until: until) : .clear
        }
        if skipped { return .skipped }
        let due = calendar.date(bySettingHour: doseHour, minute: doseMinute, second: 0, of: now) ?? now
        return .pending(overdue: now.timeIntervalSince(due) > overdueAfter)
    }
}

enum Logic {
    /// Consecutive days with the tablet logged, ending today. Today not logged yet doesn't break it.
    static func streak(takenDays: Set<String>, today: Date = Date(), calendar: Calendar = .current) -> Int {
        var count = 0
        var day = calendar.startOfDay(for: today)
        if !takenDays.contains(DayKey.of(day, calendar: calendar)) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        while takenDays.contains(DayKey.of(day, calendar: calendar)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// `m:ss`, never negative.
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func greeting(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let h = calendar.component(.hour, from: date)
        if h < 12 { return "Good morning" }
        if h < 18 { return "Good afternoon" }
        return "Good evening"
    }

    /// Reads "72.5" or "72,5". Returns nil for anything that isn't a positive number.
    static func parsePositive(_ text: String) -> Double? {
        let v = Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        guard let v, v.isFinite, v > 0 else { return nil }
        return v
    }

    static func clock(hour: Int, minute: Int, calendar: Calendar = .current) -> String {
        let d = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}
