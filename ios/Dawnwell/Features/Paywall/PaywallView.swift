import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = PlusStore.shared
    @State private var yearly = true
    @State private var busy = false

    private var selected: Product? { yearly ? store.yearly : store.monthly }

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
                        Text(store.loadFailed ? "Plans couldn't load. Check your connection and try again." : "Loading plans…")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    } else {
                        if let y = store.yearly { plan(y, isYearly: true) }
                        if let m = store.monthly { plan(m, isYearly: false) }
                    }

                    Button {
                        guard let p = selected else { return }
                        busy = true
                        Task {
                            if await store.buy(p) { dismiss() }
                            busy = false
                        }
                    } label: {
                        Text(busy ? "Working…" : trialText)
                    }
                    .buttonStyle(FilledButtonStyle())
                    .disabled(selected == nil || busy)

                    Text("Cancel any time in Settings. The subscription renews automatically unless you cancel at least 24 hours before the end of the period.")
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
        guard let p = selected else { return "Continue" }
        return Plus.buyTitle(
            hasFreeTrial: p.subscription?.introductoryOffer?.paymentMode == .freeTrial,
            eligibleForTrial: store.trialEligible,
            price: p.displayPrice
        )
    }

    private func plan(_ p: Product, isYearly: Bool) -> some View {
        let on = yearly == isYearly
        return Button { yearly = isYearly } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isYearly ? "Yearly" : "Monthly").font(.system(size: 17, weight: .heavy)).foregroundStyle(Palette.ink)
                    Text(isYearly ? "\(p.displayPrice) a year" : "\(p.displayPrice) a month").font(.footnote).foregroundStyle(Palette.muted)
                }
                Spacer()
                if isYearly, let m = store.monthly {
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
