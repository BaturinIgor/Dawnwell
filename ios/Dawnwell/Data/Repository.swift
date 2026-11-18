import Foundation
import SwiftData

/// All reads and writes go through here, so the rules for duplicates and saving live in one place.
@MainActor
struct Repository {
    let context: ModelContext

    /// The one profile. If a sync ever produced more than one, the oldest wins and the rest are left untouched.
    func profile() -> Profile {
        let all = (try? context.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        if let first = all.first { return first }
        let p = Profile()
        context.insert(p)
        save()
        return p
    }

    func existingDay(_ key: String) -> DayLog? {
        days(key).first
    }

    /// The log for a day, created on first write. Duplicate rows for the same day are merged, never dropped.
    func day(_ key: String) -> DayLog {
        let rows = days(key)
        guard let first = rows.first else {
            let d = DayLog(day: key)
            context.insert(d)
            return d
        }
        if rows.count > 1 {
            for extra in rows.dropFirst() {
                Self.merge(extra, into: first)
                context.delete(extra)
            }
            save()
        }
        return first
    }

    static func merge(_ other: DayLog, into day: DayLog) {
        if let t = other.takenAt { day.takenAt = min(day.takenAt ?? t, t) }
        day.skipped = day.takenAt == nil && (day.skipped || other.skipped)
        day.water = max(day.water, other.water)
        day.fiber = max(day.fiber, other.fiber)
        day.strength = max(day.strength, other.strength)
        if day.foodNoise == nil { day.foodNoise = other.foodNoise }
        day.updatedAt = max(day.updatedAt, other.updatedAt)
    }

    func foods(_ key: String) -> [FoodEntry] {
        let d = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == key }, sortBy: [SortDescriptor(\.at)])
        return (try? context.fetch(d)) ?? []
    }

    func symptoms(_ key: String) -> [SymptomEntry] {
        let d = FetchDescriptor<SymptomEntry>(predicate: #Predicate { $0.day == key }, sortBy: [SortDescriptor(\.at)])
        return (try? context.fetch(d)) ?? []
    }

    func takenDays() -> Set<String> {
        let d = FetchDescriptor<DayLog>(predicate: #Predicate { $0.takenAt != nil })
        return Set(((try? context.fetch(d)) ?? []).map(\.day))
    }

    // MARK: Writes

    func updateDay(_ key: String, _ change: (DayLog) -> Void) {
        let d = day(key)
        change(d)
        d.updatedAt = Date()
        save()
    }

    func addFood(_ food: Food, meal: Meal, day key: String, at: Date = Date()) {
        context.insert(FoodEntry(day: key, name: food.name, protein: food.protein, meal: meal, at: at))
        save()
    }

    func toggleSymptom(_ kind: SymptomKind, day key: String) {
        let existing = symptoms(key).filter { $0.kind == kind }
        if existing.isEmpty {
            context.insert(SymptomEntry(day: key, kind: kind))
        } else {
            for entry in existing { context.delete(entry) }
        }
        save()
    }

    /// Save now. A failure keeps the changes in memory, so the next save tries again.
    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Save failed: \(error)")
        }
    }

    private func days(_ key: String) -> [DayLog] {
        let d = FetchDescriptor<DayLog>(predicate: #Predicate { $0.day == key }, sortBy: [SortDescriptor(\.updatedAt)])
        return (try? context.fetch(d)) ?? []
    }
}
