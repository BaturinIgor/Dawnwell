import Foundation
import Observation
import StoreKit

/// Loads Plus products and keeps track of whether the user has Plus. StoreKit 2, no server.
@MainActor
@Observable
final class PlusStore {
    static let shared = PlusStore()

    private(set) var products: [Product] = []
    private(set) var isPlus = false
    private(set) var loadFailed = false
    /// Whether this Apple ID can still get the free week. Both plans share one group, so one answer covers both.
    private(set) var trialEligible = false
    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
    }

    var monthly: Product? { products.first { $0.id == Plus.monthlyID } }
    var yearly: Product? { products.first { $0.id == Plus.yearlyID } }

    func load() async {
        do {
            products = try await Product.products(for: Plus.productIDs).sorted { $0.price < $1.price }
            loadFailed = false
            trialEligible = await products.first?.subscription?.isEligibleForIntroOffer ?? false
        } catch {
            loadFailed = true
        }
        await refresh()
    }

    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Plus.productIDs.contains(t.productID), t.revocationDate == nil {
                active = true
            }
        }
        isPlus = active
    }

    /// Returns true when the purchase went through.
    func buy(_ product: Product) async -> Bool {
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(let verification):
            guard case .verified(let t) = verification else { return false }
            await t.finish()
            await refresh()
            return true
        default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }
}
