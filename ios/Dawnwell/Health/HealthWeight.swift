import Foundation
import HealthKit
import SwiftData

/// Reads body weight from Apple Health. Dawnwell only reads; it never writes to Health in 1.0.
@MainActor
enum HealthWeight {
    /// A setting, not health data, so it lives in UserDefaults and not in the store.
    static let enabledKey = "healthWeightEnabled"
    static let lookBackDays = 90

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private static let store = HKHealthStore()
    private static let bodyMass = HKQuantityType(.bodyMass)

    /// Ask for read access, then import. Returns how many days were added.
    static func connect(repo: Repository) async -> Int {
        guard isAvailable else { return 0 }
        do {
            try await store.requestAuthorization(toShare: [], read: [bodyMass])
        } catch {
            return 0
        }
        isEnabled = true
        return await importNow(repo: repo)
    }

    /// Bring in readings from the last 90 days that Dawnwell doesn't have yet.
    @discardableResult
    static func importNow(repo: Repository, now: Date = Date()) async -> Int {
        guard isAvailable, isEnabled else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -lookBackDays, to: now) ?? now
        let samples = (try? await readSamples(since: start)) ?? []
        let existing = Set(((try? repo.context.fetch(FetchDescriptor<WeightEntry>())) ?? []).map(\.day))
        let unit = repo.profile().weightUnit
        let entries = HealthImport.entries(from: samples, existingDays: existing, unit: unit)
        for e in entries { repo.context.insert(WeightEntry(day: e.day, value: e.value, at: e.at)) }
        if !entries.isEmpty { repo.save() }
        return entries.count
    }

    private static func readSamples(since start: Date) async throws -> [HealthImport.Sample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let results = try await descriptor.result(for: store)
        return results.map { HealthImport.Sample(kilograms: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)), at: $0.startDate) }
    }
}
