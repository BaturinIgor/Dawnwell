import SwiftData
import SwiftUI

struct ReportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    // Re-read the summary whenever anything it depends on changes.
    @Query private var days: [DayLog]
    @Query private var foods: [FoodEntry]
    @Query private var symptoms: [SymptomEntry]
    @Query private var weights: [WeightEntry]
    @State private var store = PlusStore.shared
    @State private var health = HealthWeight.shared
    @State private var showPaywall = false
    @State private var pdfURL: URL?

    var body: some View {
        let summary = VisitSummary.make(from: HealthImport.adding(health.entries, to: Repository(context: context).snapshot()))
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visit summary").font(.system(size: 28, weight: .heavy))
                        Text("Last \(VisitSummary.span) days").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(summary.medication).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                        Group { if summary.dose.isEmpty { Text("Dose not set") } else { Text(Loc.doseDaily(summary.dose)) } }
                            .font(.system(size: 17, weight: .heavy))
                        Divider()
                        HStack(alignment: .top) {
                            stat("\(summary.daysTaken)/\(VisitSummary.span)", "Days taken")
                            let unitName = summary.unit.rawValue
                            stat(summary.weightChange.map { "\($0 > 0 ? "+" : "")\(VisitSummary.num($0))" } ?? "–", "Weight, \(unitName)")
                            stat(summary.averageProtein.map { "\($0) g" } ?? "–", "Protein a day")
                        }
                    }
                    .card()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Symptoms").font(.system(size: 17, weight: .heavy))
                        if summary.symptoms.isEmpty {
                            Text("No symptoms logged in this period.").font(.footnote).foregroundStyle(Palette.muted)
                        }
                        ForEach(summary.symptoms, id: \.kind) { s in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(s.kind.label).fontWeight(.bold)
                                    Spacer()
                                    Text("\(s.days) days · worst \(s.worst)/5")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .foregroundStyle(s.worst >= 4 ? Palette.warmInk : Palette.inkSoft)
                                        .background(s.worst >= 4 ? Palette.warmSoft : Palette.neutralSoft, in: Capsule())
                                }
                                ForEach(s.notes.prefix(2), id: \.self) { n in
                                    Text(verbatim: "“\(n)”").font(.footnote).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                    .card()
                    if let p = profiles.first {
                        Text("Questions for my clinician").font(.system(size: 17, weight: .heavy))
                        TextField("e.g. Is the nausea after dinner normal?", text: Binding(
                            get: { p.questions },
                            set: { p.questions = $0; Repository(context: context).save() }
                        ), axis: .vertical)
                        .lineLimit(4...10)
                        .padding(14)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.fieldBorder, lineWidth: 1.5))
                    }
                    ShareLink(item: summary.text, subject: Text("Dawnwell visit summary")) {
                        Text("Share summary")
                    }
                    .buttonStyle(FilledButtonStyle())
                    if store.isPlus, let url = pdfURL {
                        ShareLink(item: url) { Label("Share as PDF", systemImage: "doc.richtext") }
                            .buttonStyle(FilledButtonStyle(kind: .secondary))
                    } else if !store.isPlus {
                        Button { showPaywall = true } label: {
                            Label("Share as PDF · Plus", systemImage: "lock.fill")
                        }
                        .buttonStyle(FilledButtonStyle(kind: .secondary))
                    }
                    Text("Send it to yourself or your care team before the visit.")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .task(id: summary.text + String(store.isPlus)) {
                await store.refresh()
                pdfURL = store.isPlus ? try? ReportPDF.file(summary) : nil
            }
        }
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .heavy))
            Text(label).font(.caption).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
