import Foundation
import HealthKit
import Observation

/// Reads body weight from Apple Health. Dawnwell only reads, and keeps the readings in memory:
/// they are never saved to the store, so they never reach iCloud (App Review Guideline 5.1.3(ii)).
@MainActor
@Observable
final class HealthWeight {
    static let shared = HealthWeight()

    /// A setting, not health data, so it lives in UserDefaults and not in the store.
    static let enabledKey = "healthWeightEnabled"
    static let lookBackDays = 365

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// One reading per day from the last year, in the user's unit. In memory only.
    private(set) var entries: [HealthImport.Entry] = []

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private let bodyMass = HKQuantityType(.bodyMass)

    /// Ask for read access, then read. Returns how many days Health has.
    func connect(unit: WeightUnit) async -> Int {
        guard Self.isAvailable else { return 0 }
        do {
            try await store.requestAuthorization(toShare: [], read: [bodyMass])
        } catch {
            return 0
        }
        Self.isEnabled = true
        await refresh(unit: unit)
        return entries.count
    }

    /// Read again from Health, e.g. when the app comes to the front.
    func refresh(unit: WeightUnit, now: Date = Date()) async {
        guard Self.isAvailable, Self.isEnabled else { entries = []; return }
        let start = Calendar.current.date(byAdding: .day, value: -Self.lookBackDays, to: now) ?? now
        let samples = (try? await readSamples(since: start)) ?? []
        entries = HealthImport.entries(from: samples, existingDays: [], unit: unit)
    }

    private func readSamples(since start: Date) async throws -> [HealthImport.Sample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let results = try await descriptor.result(for: store)
        return results.map { HealthImport.Sample(kilograms: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)), at: $0.startDate) }
    }
}
