import SwiftData
import SwiftUI

struct MedicationView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(sort: [SortDescriptor(\DoseChange.from, order: .reverse), SortDescriptor(\DoseChange.at, order: .reverse)]) private var history: [DoseChange]

    @State private var editing = false
    @State private var medication: Medication = .oralSemaglutide
    @State private var dose = ""
    @State private var packCount = ""

    private var repo: Repository { Repository(context: context) }

    private var supportMail: URL? {
        let info = Bundle.main.infoDictionary
        var sys = utsname()
        uname(&sys)
        let model = withUnsafeBytes(of: &sys.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return Support.mailURL(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            system: UIDevice.current.systemVersion,
            device: model
        )
    }

    var body: some View {
        ScrollView {
            if let p = profiles.first {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    hero(p)
                    if editing { editor }
                    schedule(p)
                    tablets(p)
                    reminders(p)
                    doseHistory
                    NavigationLink(value: "data") {
                        HStack {
                            labelled("Your data", "Backup file and copies on this phone")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                    if let mail = supportMail {
                        Link(destination: mail) {
                            HStack {
                                labelled("Write to us", Support.email)
                                Spacer()
                                Image(systemName: "envelope").foregroundStyle(Palette.muted)
                            }
                            .card()
                        }
                        .buttonStyle(.plain)
                    }
                    Link(destination: Support.privacyPolicy) {
                        HStack {
                            labelled("Privacy policy", "Your data stays on your phone and in your iCloud")
                            Spacer()
                            Image(systemName: "arrow.up.right").foregroundStyle(Palette.muted)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                    Text("Dawnwell only records what your prescriber set. Talk to them before changing anything.")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(Metrics.gutter)
            }
        }
        .background(Palette.bg)
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hero(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your tablet").font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.8))
            Text(p.medication.label).font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
            Text("\(p.doseLabel.isEmpty ? "" : "\(p.doseLabel) · ")every day at \(Logic.clock(hour: p.doseHour, minute: p.doseMinute))")
                .foregroundStyle(.white.opacity(0.9))
            if !editing {
                Button("Update from my label") {
                    medication = p.medication
                    dose = p.doseLabel
                    editing = true
                }
                .buttonStyle(FilledButtonStyle(kind: .light))
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Copy from your prescription label").font(.system(size: 15, weight: .heavy))
            Picker("Medication", selection: $medication) {
                ForEach(Medication.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            TextField("Dose, e.g. 7 mg", text: $dose).fieldStyle()
            Text("Only change this when your prescriber changes your dose.").font(.footnote).foregroundStyle(Palette.muted)
            HStack {
                Button("Cancel") { editing = false }.buttonStyle(FilledButtonStyle(kind: .secondary))
                Button("Save") {
                    repo.updateTablet(medication: medication, doseLabel: dose)
                    editing = false
                }
                .buttonStyle(FilledButtonStyle())
            }
        }
        .card()
    }

    private func schedule(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                labelled("Usual time", "Your tablet reminder follows this")
                Spacer()
                DatePicker("Usual time", selection: Binding(
                    get: { Calendar.current.date(bySettingHour: p.doseHour, minute: p.doseMinute, second: 0, of: Date()) ?? Date() },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        p.doseHour = c.hour ?? p.doseHour
                        p.doseMinute = c.minute ?? p.doseMinute
                        repo.save()
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
            }
            Divider()
            HStack {
                labelled("Wait before eating", "As written on your label")
                Spacer()
                StepperView(value: Binding(get: { p.waitMinutes }, set: { p.waitMinutes = $0; repo.save() }),
                            unit: "min", step: 5, range: 5...120)
            }
        }
        .card()
    }

    private func tablets(_ p: Profile) -> some View {
        let low = (p.tabletsLeft ?? Int.max) <= Catalog.refillAt
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                labelled("Tablets left", p.tabletsLeft == nil
                         ? "Add your pack to get a refill heads-up"
                         : low ? "Time to ask for a refill" : "About \(p.tabletsLeft ?? 0) days left")
                Spacer()
                Text(p.tabletsLeft.map(String.init) ?? "–")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(low ? Palette.warmDark : Palette.ink)
            }
            HStack {
                TextField("Tablets in new pack", text: $packCount).keyboardType(.numberPad).fieldStyle()
                Button("Add") {
                    repo.addTablets(Int(packCount) ?? 0)
                    packCount = ""
                }
                .buttonStyle(FilledButtonStyle(kind: .secondary))
                .frame(width: 88)
            }
        }
        .card(low ? Palette.warmSoft : Palette.card)
    }

    private func reminders(_ p: Profile) -> some View {
        VStack(spacing: 0) {
            toggle("Tablet reminder", "Every day at \(Logic.clock(hour: p.doseHour, minute: p.doseMinute))",
                   Binding(get: { p.remindTablet }, set: { p.remindTablet = $0; repo.save() }))
            toggle("Wait is over", "Tells you when you can eat",
                   Binding(get: { p.remindWaitOver }, set: { p.remindWaitOver = $0; repo.save() }))
            toggle("Protein check", "At 3 PM",
                   Binding(get: { p.remindProtein }, set: { p.remindProtein = $0; repo.save() }))
            toggle("Refill heads-up", "Shown on Today at \(Catalog.refillAt) tablets",
                   Binding(get: { p.remindRefill }, set: { p.remindRefill = $0; repo.save() }))
        }
        .card()
    }

    private var doseHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dose history").font(.subheadline.weight(.bold)).foregroundStyle(Palette.inkSoft)
            VStack(alignment: .leading, spacing: 8) {
                if history.isEmpty {
                    Text("Your dose changes will show here, for your visit summary.").font(.footnote).foregroundStyle(Palette.muted)
                }
                ForEach(Array(history.enumerated()), id: \.offset) { i, h in
                    HStack {
                        Text(h.label).fontWeight(i == 0 ? .bold : .regular)
                        Spacer()
                        Text("\(i == 0 ? "Since" : "From") \(DayKey.date(h.from).map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? h.from)")
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            .card()
        }
    }

    private func labelled(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.ink)
            Text(sub).font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    private func toggle(_ label: String, _ sub: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) { labelled(label, sub) }.frame(minHeight: 60)
    }
}
