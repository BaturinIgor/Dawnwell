import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var medication: Medication = .oralSemaglutide
    @State private var dose = ""
    @State private var doseTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var wait = 30
    @State private var unit: WeightUnit = Locale.current.measurementSystem == .us ? .lb : .kg
    @State private var weight = ""
    @State private var goal = ""
    @State private var protein = 100
    @State private var remindTablet = true
    @State private var remindWaitOver = true
    @State private var remindProtein = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.gap) {
                if step > 0 { header }
                switch step {
                case 0: welcome
                case 1: tablet
                default: goals
                }
            }
            .padding(Metrics.gutter)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { step -= 1 } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Palette.card, in: Circle())
            }
            .accessibilityLabel("Back")
            ForEach(1...2, id: \.self) { i in
                Capsule().fill(step >= i ? Palette.accent : Palette.fieldBorder).frame(height: 6)
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dawnwell").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white.opacity(0.9))
                Text("Your daily GLP-1 tablet, made simple")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(24)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 36, style: .continuous))

            ForEach([
                String(localized: "Know exactly when you can eat after your tablet"),
                String(localized: "Hit your protein to keep your muscle"),
                String(localized: "Bring a clear summary to every visit"),
            ], id: \.self) { line in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Palette.accentText)
                        .frame(width: 28, height: 28)
                        .background(Palette.accentSoft, in: Circle())
                    Text(line).foregroundStyle(Palette.inkSoft)
                }
            }
            Button("Get started") { step = 1 }.buttonStyle(FilledButtonStyle())
            Text("Dawnwell records what you log. It does not give medical advice or change your dose.")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private var tablet: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            title("Your tablet", "Copy these from your prescription label. You can change them anytime.")
            fieldLabel("Medication")
            ForEach(Medication.allCases) { m in
                Button { medication = m } label: {
                    HStack {
                        Text(m.label).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: medication == m ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(medication == m ? Palette.accentText : Palette.muted)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(medication == m ? Palette.accent : Palette.line, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(medication == m ? .isSelected : [])
            }
            fieldLabel("Dose on your label")
            TextField("e.g. 7 mg", text: $dose).fieldStyle()
            HStack {
                fieldLabel("Usual time")
                Spacer()
                DatePicker("Usual time", selection: $doseTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wait before eating").font(.system(size: 15, weight: .heavy))
                    Text("As written on your label").font(.footnote).foregroundStyle(Palette.muted)
                }
                Spacer()
                StepperView(value: $wait, unit: String(localized: "min"), step: 5, range: 5...120)
            }
            .card()
            Button("Continue") { step = 2 }.buttonStyle(FilledButtonStyle())
        }
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            title("Goals and reminders", "Agree on your targets with your care team.")
            Picker("Units", selection: $unit) {
                ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Current weight (\(unit.rawValue))")
                    TextField(unit == .lb ? "195" : "88", text: $weight).keyboardType(.decimalPad).fieldStyle()
                }
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Goal weight (\(unit.rawValue))")
                    TextField(unit == .lb ? "170" : "77", text: $goal).keyboardType(.decimalPad).fieldStyle()
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily protein").font(.system(size: 15, weight: .heavy))
                    Text("Change it anytime").font(.footnote).foregroundStyle(Palette.muted)
                }
                Spacer()
                StepperView(value: $protein, unit: String(localized: "g"), step: 5, range: 40...200)
            }
            .card()
            VStack(spacing: 0) {
                let time = doseTime.formatted(date: .omitted, time: .shortened)
                toggle("Tablet reminder", "Every day at \(time)", $remindTablet)
                toggle("Wait is over", "Tells you when you can eat", $remindWaitOver)
                toggle("Protein check", "At 3 PM", $remindProtein)
            }
            .card()
            Button("Finish setup", action: finish).buttonStyle(FilledButtonStyle())
        }
    }

    private func finish() {
        let repo = Repository(context: context)
        let p = repo.profile()
        let time = Calendar.current.dateComponents([.hour, .minute], from: doseTime)
        p.medication = medication
        p.doseLabel = dose.trimmingCharacters(in: .whitespaces)
        p.doseHour = time.hour ?? 7
        p.doseMinute = time.minute ?? 0
        p.waitMinutes = wait
        p.weightUnit = unit
        p.proteinTarget = protein
        p.startWeight = Logic.parsePositive(weight)
        p.goalWeight = Logic.parsePositive(goal)
        p.remindTablet = remindTablet
        p.remindWaitOver = remindWaitOver
        p.remindProtein = remindProtein
        let today = DayKey.today()
        if let start = p.startWeight { context.insert(WeightEntry(day: today, value: start)) }
        if !p.doseLabel.isEmpty { context.insert(DoseChange(label: "\(p.doseLabel) daily", from: today)) }
        p.onboarded = true
        repo.save()
    }

    private func title(_ text: LocalizedStringKey, _ sub: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.system(size: 28, weight: .heavy)).foregroundStyle(Palette.ink)
            Text(sub).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
        }
    }

    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.subheadline.weight(.bold)).foregroundStyle(Palette.inkSoft)
    }

    private func toggle(_ label: LocalizedStringKey, _ sub: LocalizedStringKey, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 15, weight: .bold))
                Text(sub).font(.footnote).foregroundStyle(Palette.muted)
            }
        }
        .frame(minHeight: 56)
    }
}
