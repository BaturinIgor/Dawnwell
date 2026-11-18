import SwiftData
import SwiftUI

struct SymptomDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let day: String
    @State private var kind: SymptomKind
    @State private var severity = 2
    @State private var triggers: [String] = []
    @State private var note = ""

    init(day: String, initial: SymptomKind = .nausea) {
        self.day = day
        _kind = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    FlowLayout {
                        ForEach(SymptomKind.allCases.filter { $0 != .good }) { k in
                            ChipView(label: k.label, selected: kind == k, warm: true) { pick(k) }
                        }
                    }
                    Text(question(kind))
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    ScaleView(value: severity, words: Catalog.severityWords) { severity = $0 }
                    HStack {
                        Text("Barely there")
                        Spacer()
                        Text(Catalog.severityWords[severity]).fontWeight(.bold)
                        Spacer()
                        Text("Severe")
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)

                    Text("Anything that might have caused it?").font(.system(size: 15, weight: .heavy))
                    FlowLayout {
                        ForEach(Catalog.triggers, id: \.self) { t in
                            ChipView(label: Loc.text(t), selected: triggers.contains(t)) {
                                if let i = triggers.firstIndex(of: t) { triggers.remove(at: i) } else { triggers.append(t) }
                            }
                        }
                    }

                    Text("Note for your visit summary").font(.system(size: 15, weight: .heavy))
                    TextField("What helped, what made it worse", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.fieldBorder, lineWidth: 1.5))

                    if severity >= 4 {
                        Text("Severe or lasting symptoms, or strong stomach pain, are a reason to contact your clinician today.")
                            .font(.footnote)
                            .foregroundStyle(Palette.warmInk)
                            .card(Palette.warmSoft)
                    }

                    Button("Save") {
                        Repository(context: context).saveSymptom(kind, severity: severity, triggers: triggers, note: note, day: day)
                        dismiss()
                    }
                    .buttonStyle(FilledButtonStyle())
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.bg)
            .navigationTitle("Symptom details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onAppear { pick(kind) }
        }
    }

    /// Asked per symptom, so each language can phrase it naturally.
    private func question(_ k: SymptomKind) -> String {
        switch k {
        case .nausea: return String(localized: "How strong is the nausea?")
        case .constipation: return String(localized: "How strong is the constipation?")
        case .heartburn: return String(localized: "How strong is the heartburn?")
        case .fatigue: return String(localized: "How strong is the tiredness?")
        case .noAppetite: return String(localized: "How strong is the loss of appetite?")
        case .good: return String(localized: "How good do you feel?")
        }
    }

    /// Load what was already saved today for this symptom, if anything.
    private func pick(_ next: SymptomKind) {
        kind = next
        let existing = Repository(context: context).symptoms(day).first { $0.kind == next }
        severity = existing?.severity ?? 2
        triggers = existing?.triggers ?? []
        note = existing?.note ?? ""
    }
}
