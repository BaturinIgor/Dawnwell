import Charts
import SwiftData
import SwiftUI

/// Named `ProgressScreen` so it does not clash with SwiftUI's `ProgressView`.
struct ProgressScreen: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @Query private var days: [DayLog]
    @Query private var foods: [FoodEntry]
    @Query private var weights: [WeightEntry]

    @State private var input = ""
    @State private var health = HealthWeight.shared
    @State private var healthOn = HealthWeight.isEnabled
    @State private var healthNote: String?
    @State private var store = PlusStore.shared
    @State private var paywall: Plus.Source?
    @FocusState private var focused: Bool

    private var repo: Repository { Repository(context: context) }

    var body: some View {
        let snapshot = HealthImport.adding(health.entries, to: repo.snapshot())
        let stats = ProgressStats.make(from: snapshot)
        let insights = Insights.make(from: snapshot)
        let week = WeekSummary.make(from: snapshot)
        let doses = DoseHistory.make(from: snapshot)
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    Text("Progress").font(.system(size: 28, weight: .heavy)).foregroundStyle(Palette.ink)
                    weekCard(week).id("week")
                    weightCard(stats)
                    proteinCard(stats).id("protein")
                    doseCard(doses).id("doses")
                    insightsCard(insights).id("insights")
                    tabletCard(stats)
                    noiseCard(stats)
                }
                .padding(Metrics.gutter)
            }
            .task {
                // App Store screenshots (debug builds only): open on one card.
                guard let target = DesignFlags.argument("-design-scroll") else { return }
                try? await Task.sleep(for: .milliseconds(300))
                proxy.scrollTo(target, anchor: .top)
            }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $paywall) { PaywallView(source: $0) }
        }
    }

    // MARK: Insights (Plus)

    private func insightsCard(_ i: Insights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Insights").font(.system(size: 17, weight: .heavy))
                Spacer()
                if !store.isPlus {
                    Image(systemName: "lock.fill").foregroundStyle(Palette.muted).accessibilityHidden(true)
                }
            }
            if !i.hasEnoughData {
                let need = Insights.minimumDays, logged = i.loggedDays
                Text("Insights appear after \(need) days of logs. You have \(logged) so far.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            } else if !store.isPlus {
                let found = i.findings.count
                Group {
                    if found > 0 {
                        Text("\(found) patterns found in your logs.")
                    } else {
                        Text("See which foods and habits line up with your symptoms.")
                    }
                }
                .font(.subheadline).foregroundStyle(Palette.inkSoft)
                if found > 0 {
                    // The real findings, blurred: people see there is something about them under there.
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(i.findings.prefix(2).enumerated()), id: \.offset) { _, f in
                            Label { Text(f.text).font(.subheadline) } icon: { Image(systemName: "sparkle") }
                        }
                    }
                    .blur(radius: 6)
                    .accessibilityHidden(true)
                }
                Button { paywall = .insights } label: { Text("See insights with Plus") }
                    .buttonStyle(FilledButtonStyle(kind: .secondary))
                    .accessibilityIdentifier("plus-insights")
            } else {
                if i.findings.isEmpty {
                    Text("No clear patterns yet. Keep logging food and symptoms.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                ForEach(Array(i.findings.enumerated()), id: \.offset) { _, f in
                    Label {
                        Text(f.text).font(.subheadline).foregroundStyle(Palette.ink)
                    } icon: {
                        Image(systemName: "sparkle").foregroundStyle(Palette.accentText)
                    }
                }
                if i.symptomWeeks.contains(where: { $0 > 0 }) {
                    Text("Days with symptoms, last 4 weeks").font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(i.symptomWeeks.enumerated()), id: \.offset) { _, count in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Palette.warmSoft)
                                    .frame(height: CGFloat(max(count, 0)) * 6 + 4)
                                Text(verbatim: "\(count)").font(.caption2.weight(.bold)).foregroundStyle(Palette.inkSoft)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: i.symptomWeeks.map(String.init).joined(separator: ", ")))
                }
            }
            Text("Patterns in your own logs, not medical advice. Talk to your care team before changing anything.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Week (Plus)

    private func weekCard(_ w: WeekSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your week").font(.system(size: 17, weight: .heavy))
                Spacer()
                Text(verbatim: "\(short(w.start)) – \(short(w.end))").font(.footnote.weight(.bold)).foregroundStyle(Palette.muted)
            }
            if w.now.trackedDays == 0 {
                Text("Your first week shows here once you start logging.").font(.footnote).foregroundStyle(Palette.muted)
            } else {
                PlusPreview(isPlus: store.isPlus, unlock: "See your week with Plus", action: { paywall = .weekSummary }) {
                    VStack(alignment: .leading, spacing: 10) {
                        let total = w.now.trackedDays
                        weekRow("pills.fill", Text("Tablet"), count: w.now.taken, total: total, before: w.before.taken, higherIsBetter: true)
                        weekRow("fork.knife", Text("Protein goal"), count: w.now.proteinHitDays, total: total, before: w.before.proteinHitDays, higherIsBetter: true)
                        weekRow("drop.fill", Text("Water goal"), count: w.now.waterHitDays, total: total, before: w.before.waterHitDays, higherIsBetter: true)
                        weekRow("waveform.path.ecg", Text("Days with symptoms"), count: w.now.symptomDays, total: total, before: w.before.symptomDays, higherIsBetter: false)
                        if let top = w.now.topSymptom {
                            let name = top.label
                            Text("Most logged: \(name)").font(.footnote).foregroundStyle(Palette.muted)
                        }
                        if let c = w.weightChange, abs(c) >= 0.05 {
                            let amount = "\(c > 0 ? "+" : "−")\(VisitSummary.num(abs(c))) \(w.unit.rawValue)"
                            Label { Text("Weight \(amount) this week") } icon: { Image(systemName: "scalemass.fill").foregroundStyle(Palette.accentText) }
                                .font(.subheadline.weight(.semibold))
                        }
                        if w.notLogged > 0 {
                            let n = w.notLogged
                            Text("\(n) days without a tablet logged.").font(.footnote).foregroundStyle(Palette.muted)
                        }
                    }
                }
                .accessibilityIdentifier("plus-week")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func weekRow(_ symbol: String, _ title: Text, count: Int, total: Int, before: Int, higherIsBetter: Bool) -> some View {
        let better = higherIsBetter ? count > before : count < before
        let worse = higherIsBetter ? count < before : count > before
        return HStack {
            Image(systemName: symbol).foregroundStyle(Palette.accentText).frame(width: 24)
            title.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            Spacer()
            Text("\(count) of \(total) days").font(.subheadline.weight(.heavy)).foregroundStyle(Palette.ink)
            if better || worse {
                Image(systemName: count > before ? "arrow.up" : "arrow.down")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(better ? Palette.accentText : Palette.warmDark)
                    .accessibilityLabel(better ? Text("Better than the week before") : Text("Worse than the week before"))
            }
        }
    }

    // MARK: Doses and symptoms (Plus)

    private func doseCard(_ h: DoseHistory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Doses and symptoms").font(.system(size: 17, weight: .heavy))
            if h.periods.isEmpty {
                Text("Add your dose in Medication. Each time it changes, you will see how you felt on it here.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            } else {
                PlusPreview(isPlus: store.isPlus, unlock: "See your doses with Plus", action: { paywall = .doseHistory }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Chart {
                            ForEach(h.weeks, id: \.start) { w in
                                BarMark(x: .value("Week", DayKey.date(w.start) ?? Date(), unit: .weekOfYear), y: .value("Days with symptoms", w.symptomDays))
                                    .foregroundStyle(Palette.warmMark)
                                    .cornerRadius(4)
                                if let label = w.doseChange {
                                    RuleMark(x: .value("Dose change", DayKey.date(w.start) ?? Date(), unit: .weekOfYear))
                                        .foregroundStyle(Palette.accent)
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 3]))
                                        .annotation(position: .top, alignment: .leading) {
                                            // Just the dose ("7 mg"): labels of changes a few weeks apart must not overlap.
                                            Text(label).font(.caption2.weight(.bold)).foregroundStyle(Palette.accentText)
                                        }
                                }
                            }
                        }
                        .chartYScale(domain: 0...7)
                        .chartYAxis { AxisMarks(values: [0, 7]) }
                        .chartXAxis(.hidden)
                        .frame(height: 130)
                        // Room for the dose labels above the plot, clear of the card title.
                        .padding(.top, 18)
                        .accessibilityLabel("Days with symptoms each week, with dose changes marked")
                        Text("Days with symptoms per week, last 12 weeks. Lines mark a new dose.")
                            .font(.caption).foregroundStyle(Palette.muted)
                        ForEach(Array(h.periods.prefix(4).enumerated()), id: \.offset) { i, p in
                            doseRow(p, current: i == 0)
                        }
                    }
                }
                .accessibilityIdentifier("plus-doses")
            }
            Text("A record of your own logs, not medical advice. Your prescriber decides your dose.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func doseRow(_ p: DoseHistory.Period, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(Loc.doseDaily(p.label)).font(.subheadline.weight(.heavy)).foregroundStyle(Palette.ink)
                Spacer()
                let days = p.days
                Group { if current { Text("Day \(days)") } else { Text("\(days) days") } }
                    .font(.footnote.weight(.bold)).foregroundStyle(Palette.muted)
            }
            let d = p.symptomDays, w = p.nauseaDays
            Group {
                if d == 0 { Text("No symptoms logged") } else { Text("Symptoms on \(d) days, nausea on \(w)") }
            }
            .font(.footnote).foregroundStyle(Palette.inkSoft)
        }
        .padding(.vertical, 4)
    }

    // MARK: Weight

    private func weightCard(_ s: ProgressStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                    Text(s.latest.map { "\(VisitSummary.num($0.value)) \(s.unit.rawValue)" } ?? "–")
                        .font(.system(size: 30, weight: .heavy))
                    if let l = s.latest {
                        let date = short(l.day)
                        Text("Logged \(date)").font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let c = s.changeSinceStart, abs(c) >= 0.05 {
                        let amount = "\(c > 0 ? "−" : "+")\(VisitSummary.num(abs(c))) \(s.unit.rawValue)"
                        Text("\(amount) since start")
                            .font(.footnote.weight(.heavy))
                            .foregroundStyle(Palette.accentDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Palette.accentSoft, in: Capsule())
                    }
                    if let g = s.toGoal, g > 0 {
                        let amount = "\(VisitSummary.num(g)) \(s.unit.rawValue)"
                        Text("\(amount) to goal").font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
            }
            if s.weights.isEmpty {
                Text("Log your weight once a week, same time of day, to see your trend.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            } else {
                weightChart(s)
            }
            HStack {
                let unitName = s.unit.rawValue
                TextField("Today's weight, \(unitName)", text: $input)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .fieldStyle()
                    .accessibilityLabel(s.unit == .kg ? Text("Today's weight in kilograms") : Text("Today's weight in pounds"))
                Button("Log") {
                    if let v = Logic.parsePositive(input) {
                        repo.logWeight(v)
                        input = ""
                        focused = false
                    }
                }
                .buttonStyle(FilledButtonStyle())
                .frame(width: 88)
                .disabled(Logic.parsePositive(input) == nil)
            }
            if HealthWeight.isAvailable {
                if healthOn {
                    Label(healthNote ?? String(localized: "Weight from Apple Health shows here. It stays in Health and is not copied to iCloud."), systemImage: "heart.fill")
                        .font(.footnote).foregroundStyle(Palette.muted)
                } else {
                    Button {
                        Task {
                            let found = await health.connect(unit: repo.profile().weightUnit)
                            healthOn = HealthWeight.isEnabled
                            healthNote = found > 0 ? String(localized: "Showing \(found) days from Apple Health.") : nil
                        }
                    } label: {
                        Label("Get weight from Apple Health", systemImage: "heart.fill")
                    }
                    .buttonStyle(FilledButtonStyle(kind: .secondary))
                }
            }
        }
        .card()
    }

    private func weightChart(_ s: ProgressStats) -> some View {
        let points = Array(s.weights.suffix(12))
        let values = points.map(\.value) + (s.goalWeight.map { [$0] } ?? [])
        let low = (values.min() ?? 0) - 1, high = (values.max() ?? 0) + 1
        return Chart {
            if let g = s.goalWeight {
                RuleMark(y: .value("Goal", g))
                    .foregroundStyle(Palette.accent.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
            }
            ForEach(points, id: \.day) { p in
                LineMark(x: .value("Day", DayKey.date(p.day) ?? Date()), y: .value("Weight", p.value))
                    .foregroundStyle(Palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Day", DayKey.date(p.day) ?? Date()), y: .value("Weight", p.value))
                    .foregroundStyle(Palette.accent)
                    .symbolSize(p.day == points.last?.day ? 70 : 30)
            }
        }
        .chartYScale(domain: low...high)
        .chartXAxis(.hidden)
        .frame(height: 140)
        .accessibilityLabel("Weight trend")
    }

    // MARK: Protein

    private func proteinCard(_ s: ProgressStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Protein this week").font(.system(size: 17, weight: .heavy))
                Spacer()
                Text("\(s.proteinHitDays) of 7 days at \(s.proteinTarget) g").font(.footnote.weight(.bold)).foregroundStyle(Palette.muted)
            }
            Chart {
                RuleMark(y: .value("Target", s.proteinTarget))
                    .foregroundStyle(Palette.muted.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 5]))
                ForEach(s.proteinWeek, id: \.day) { d in
                    BarMark(x: .value("Day", weekday(d.day)), y: .value("Protein", d.grams))
                        .foregroundStyle(d.grams >= s.proteinTarget ? Palette.accent : d.grams > 0 ? Palette.warmMark : Palette.lineSoft)
                        .cornerRadius(8)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 140)
            Text("Enough protein helps you keep muscle while you lose weight.").font(.footnote).foregroundStyle(Palette.muted)
        }
        .card()
    }

    // MARK: Tablet

    private func tabletCard(_ s: ProgressStats) -> some View {
        let today = DayKey.today()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tablet, last 4 weeks").font(.system(size: 17, weight: .heavy))
                Spacer()
                Text("\(s.takenCount) of 28").font(.footnote.weight(.bold)).foregroundStyle(Palette.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(s.tabletGrid, id: \.day) { d in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color(d.mark))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if d.day == today {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Palette.ink, lineWidth: 2)
                            }
                        }
                        .accessibilityElement()
                        .accessibilityLabel(markLabel(d))
                }
            }
            HStack(spacing: 16) {
                legend(Palette.accent, "Taken")
                legend(Palette.warmMark, "Skipped")
                legend(Palette.lineSoft, "Not logged")
            }
        }
        .card()
    }

    private func color(_ m: ProgressStats.TabletMark) -> Color {
        switch m {
        case .taken: return Palette.accent
        case .skipped: return Palette.warmMark
        case .none: return Palette.lineSoft
        }
    }

    private func markLabel(_ d: ProgressStats.TabletDay) -> Text {
        let date = short(d.day)
        switch d.mark {
        case .taken: return Text("\(date): taken")
        case .skipped: return Text("\(date): skipped")
        case .none: return Text("\(date): not logged")
        }
    }

    private func legend(_ c: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(c).frame(width: 12, height: 12)
            Text(label).font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    // MARK: Food noise

    private func noiseCard(_ s: ProgressStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Food noise").font(.system(size: 17, weight: .heavy))
            if let now = s.noiseNow {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(VisitSummary.num(now)).font(.system(size: 30, weight: .heavy))
                    Text("of 5, recent average").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                }
                if let before = s.noiseBefore {
                    let past = VisitSummary.num(before)
                    Group {
                        if now < before {
                            Text("Quieter than the week before (\(past)).")
                        } else if now > before {
                            Text("Louder than the week before (\(past)).")
                        } else {
                            Text("About the same as the week before.")
                        }
                    }
                    .font(.footnote).foregroundStyle(Palette.muted)
                }
            } else {
                Text("Rate your food noise on Today. After a few days you will see the trend here.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func short(_ key: String) -> String {
        DayKey.date(key).map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? key
    }

    private func weekday(_ key: String) -> String {
        DayKey.date(key).map { $0.formatted(.dateTime.weekday(.abbreviated)) } ?? key
    }
}
