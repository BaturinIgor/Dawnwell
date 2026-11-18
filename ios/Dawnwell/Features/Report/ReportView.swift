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

    var body: some View {
        let summary = VisitSummary.make(from: Repository(context: context).snapshot())
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visit summary").font(.system(size: 28, weight: .heavy))
                        Text("Last \(VisitSummary.span) days").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(summary.medication).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                        Text(summary.dose.isEmpty ? "Dose not set" : "\(summary.dose) daily").font(.system(size: 17, weight: .heavy))
                        Divider()
                        HStack(alignment: .top) {
                            stat("\(summary.daysTaken)/\(VisitSummary.span)", "Days taken")
                            stat(summary.weightChange.map { "\($0 > 0 ? "+" : "")\(VisitSummary.num($0))" } ?? "–", "Weight, \(summary.unit.rawValue)")
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
                                    Text("\(s.days) day\(s.days == 1 ? "" : "s") · worst \(s.worst)/5")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .foregroundStyle(s.worst >= 4 ? Palette.warmInk : Palette.inkSoft)
                                        .background(s.worst >= 4 ? Palette.warmSoft : Palette.neutralSoft, in: Capsule())
                                }
                                ForEach(s.notes.prefix(2), id: \.self) { n in
                                    Text("“\(n)”").font(.footnote).foregroundStyle(Palette.muted)
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
                    Text("Send it to yourself or your care team before the visit.")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.bg)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .heavy))
            Text(label).font(.caption).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
