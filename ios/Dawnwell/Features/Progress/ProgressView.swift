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
    @State private var healthOn = HealthWeight.isEnabled
    @State private var healthNote: String?
    @FocusState private var focused: Bool

    private var repo: Repository { Repository(context: context) }

    var body: some View {
        let stats = ProgressStats.make(from: repo.snapshot())
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    Text("Progress").font(.system(size: 28, weight: .heavy)).foregroundStyle(Palette.ink)
                    weightCard(stats)
                    proteinCard(stats)
                    tabletCard(stats)
                    noiseCard(stats)
                }
                .padding(Metrics.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .toolbar(.hidden, for: .navigationBar)
        }
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
                        Text("Logged \(short(l.day))").font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let c = s.changeSinceStart, abs(c) >= 0.05 {
                        Text("\(c > 0 ? "−" : "+")\(VisitSummary.num(abs(c))) \(s.unit.rawValue) since start")
                            .font(.footnote.weight(.heavy))
                            .foregroundStyle(Palette.accentDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Palette.accentSoft, in: Capsule())
                    }
                    if let g = s.toGoal, g > 0 {
                        Text("\(VisitSummary.num(g)) \(s.unit.rawValue) to goal").font(.footnote).foregroundStyle(Palette.muted)
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
                TextField("Today's weight, \(s.unit.rawValue)", text: $input)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .fieldStyle()
                    .accessibilityLabel("Today's weight in \(s.unit == .kg ? "kilograms" : "pounds")")
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
                    Label(healthNote ?? "Weight from Apple Health is added here automatically.", systemImage: "heart.fill")
                        .font(.footnote).foregroundStyle(Palette.muted)
                } else {
                    Button {
                        Task {
                            let added = await HealthWeight.connect(repo: repo)
                            healthOn = HealthWeight.isEnabled
                            healthNote = added > 0 ? "Added \(added) day\(added == 1 ? "" : "s") from Apple Health." : nil
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
                        .accessibilityLabel("\(short(d.day)): \(d.mark == .taken ? "taken" : d.mark == .skipped ? "skipped" : "not logged")")
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

    private func legend(_ c: Color, _ label: String) -> some View {
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
                    Text(now < before ? "Quieter than the week before (\(VisitSummary.num(before)))."
                         : now > before ? "Louder than the week before (\(VisitSummary.num(before)))."
                         : "About the same as the week before.")
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
