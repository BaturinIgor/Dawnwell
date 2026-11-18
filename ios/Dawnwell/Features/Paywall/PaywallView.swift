import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = PlusStore.shared
    @State private var plan: Plus.Plan = .yearly
    @State private var busy = false

    private var selected: Product? { store.product(for: plan) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dawnwell Plus").font(.system(size: 30, weight: .heavy)).foregroundStyle(Palette.ink)
                        Text("Your tablet, timer, reminders and backups stay free. Plus adds:")
                            .foregroundStyle(Palette.inkSoft)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Plus.benefits, id: \.self) { b in
                            Label { Text(b).foregroundStyle(Palette.ink) } icon: {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accentText)
                            }
                        }
                    }
                    .card()

                    if store.products.isEmpty {
                        Group {
                            if store.loadFailed {
                                Text("Plans couldn't load. Check your connection and try again.")
                            } else {
                                Text("Loading plans…")
                            }
                        }
                        .font(.footnote).foregroundStyle(Palette.muted)
                    } else {
                        ForEach(Plus.Plan.allCases, id: \.self) { p in
                            if let product = store.product(for: p) { row(product, plan: p) }
                        }
                    }

                    Button {
                        guard let p = selected else { return }
                        busy = true
                        Task {
                            if await store.buy(p) { dismiss() }
                            busy = false
                        }
                    } label: {
                        Text(busy ? String(localized: "Working…") : trialText)
                    }
                    .buttonStyle(FilledButtonStyle())
                    .disabled(selected == nil || busy)

                    Group {
                        if plan == .lifetime {
                            Text("One payment. No subscription to renew.")
                        } else {
                            Text("Cancel any time in Settings. The subscription renews automatically unless you cancel at least 24 hours before the end of the period.")
                        }
                    }
                    .font(.caption).foregroundStyle(Palette.muted)
                    HStack {
                        Button("Restore purchases") { Task { await store.restore(); if store.isPlus { dismiss() } } }
                        Spacer()
                        Link("Privacy", destination: Support.privacyPolicy)
                        Link("Terms of Use", destination: Plus.termsOfUse)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accentText)
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
            .task { await store.load() }
        }
    }

    private var trialText: String {
        guard let p = selected else { return String(localized: "Continue") }
        return Plus.buyTitle(
            plan: plan,
            hasFreeTrial: p.subscription?.introductoryOffer?.paymentMode == .freeTrial,
            eligibleForTrial: store.trialEligible,
            price: p.displayPrice
        )
    }

    @ViewBuilder
    private func title(_ plan: Plus.Plan) -> some View {
        switch plan {
        case .yearly: Text("Yearly")
        case .monthly: Text("Monthly")
        case .lifetime: Text("Lifetime")
        }
    }

    @ViewBuilder
    private func priceLine(_ plan: Plus.Plan, _ price: String) -> some View {
        switch plan {
        case .yearly: Text("\(price) a year")
        case .monthly: Text("\(price) a month")
        case .lifetime: Text("\(price) once")
        }
    }

    private func row(_ p: Product, plan this: Plus.Plan) -> some View {
        let on = plan == this
        return Button { plan = this } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    title(this).font(.system(size: 17, weight: .heavy)).foregroundStyle(Palette.ink)
                    priceLine(this, p.displayPrice).font(.footnote).foregroundStyle(Palette.muted)
                }
                Spacer()
                if this == .yearly, let m = store.monthly {
                    let saving = Plus.yearlySaving(monthly: m.price, yearly: p.price)
                    if saving > 0 {
                        Text("Save \(saving)%")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Palette.accentDark)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Palette.accentSoft, in: Capsule())
                    }
                }
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22)).foregroundStyle(on ? Palette.accentText : Palette.muted)
            }
            .card()
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(on ? Palette.accent : Palette.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
