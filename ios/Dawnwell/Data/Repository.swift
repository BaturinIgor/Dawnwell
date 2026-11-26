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

    func addFoods(_ picked: [Food], custom: (name: String, protein: Int)?, meal: Meal, day key: String, at: Date = Date()) {
        for f in picked {
            context.insert(FoodEntry(day: key, name: f.name, protein: f.protein, meal: meal, at: at))
        }
        if let custom {
            let name = custom.name.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty && custom.protein > 0 {
                context.insert(FoodEntry(day: key, name: name, protein: custom.protein, meal: meal, at: at))
            }
        }
        save()
    }

    func deleteFood(_ entry: FoodEntry) {
        context.delete(entry)
        save()
    }

    /// One entry per symptom per day: saving details replaces that symptom's entry.
    func saveSymptom(_ kind: SymptomKind, severity: Int, triggers: [String], note: String, day key: String, at: Date = Date()) {
        for old in symptoms(key) where old.kind == kind { context.delete(old) }
        let clamped = min(5, max(1, severity))
        context.insert(SymptomEntry(day: key, kind: kind, severity: clamped, triggers: triggers,
                                    note: note.trimmingCharacters(in: .whitespacesAndNewlines), at: at))
        save()
    }

    /// Records a new dose from the label. Adds a dose-history line only when the dose actually changed.
    func updateTablet(medication: Medication, doseLabel: String, today: String = DayKey.today()) {
        let p = profile()
        let label = doseLabel.trimmingCharacters(in: .whitespaces)
        if !label.isEmpty && label != p.doseLabel {
            context.insert(DoseChange(label: "\(label) daily", from: today))
        }
        // A different tablet comes with a different wait rule. The user can still change it after.
        if medication != p.medication { p.waitMinutes = medication.defaultWaitMinutes }
        p.medication = medication
        p.doseLabel = label
        save()
    }

    func addTablets(_ count: Int) {
        guard count > 0 else { return }
        let p = profile()
        p.tabletsLeft = (p.tabletsLeft ?? 0) + count
        save()
    }

    func doseHistory() -> [DoseChange] {
        (try? context.fetch(FetchDescriptor<DoseChange>(sortBy: [SortDescriptor(\.from, order: .reverse), SortDescriptor(\.at, order: .reverse)]))) ?? []
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
