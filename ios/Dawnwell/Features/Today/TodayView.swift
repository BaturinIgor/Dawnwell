import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query private var days: [DayLog]
    @Query private var foods: [FoodEntry]
    @Query private var symptoms: [SymptomEntry]

    private let key: String
    @State private var showFood = false
    @State private var symptomDetail: SymptomKind?

    init(day: String = DayKey.today()) {
        key = day
        _foods = Query(filter: #Predicate<FoodEntry> { $0.day == day }, sort: \.at)
        _symptoms = Query(filter: #Predicate<SymptomEntry> { $0.day == day }, sort: \.at)
    }

    private var repo: Repository { Repository(context: context) }
    private var profile: Profile? { profiles.first }
    private var today: DayLog? { days.first { $0.day == key } }
    private var protein: Int { foods.reduce(0) { $0 + $1.protein } }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { route in
                    if route == "medication" { MedicationView() }
                    if route == "data" { DataView() }
                }
                .sheet(isPresented: $showFood) { LogFoodView(day: key) }
                .sheet(item: $symptomDetail) { kind in SymptomDetailView(day: key, initial: kind) }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.gap) {
                header
                WeekStrip(taken: Set(days.filter { $0.takenAt != nil }.map(\.day)))
                if let profile {
                    if profile.remindRefill, let left = profile.tabletsLeft, left <= Catalog.refillAt {
                        NavigationLink(value: "medication") {
                            HStack {
                                Text("\(left) tablets left. Time to ask for a refill.").font(.subheadline.weight(.bold))
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(Palette.warmInk)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .background(Palette.warmSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    TabletCard(profile: profile, day: today, onTake: take, onUndo: undo, onSkip: skip)
                    proteinCard(target: profile.proteinTarget)
                    HStack(spacing: 12) {
                        MiniCounter(title: "Water", value: today?.water ?? 0, goal: profile.waterTarget, unit: "glasses") { delta in
                            repo.updateDay(key) { $0.water = max(0, $0.water + delta) }
                        }
                        MiniCounter(title: "Fiber", value: today?.fiber ?? 0, goal: profile.fiberTarget, unit: "g", step: 5) { delta in
                            repo.updateDay(key) { $0.fiber = max(0, $0.fiber + delta) }
                        }
                    }
                    MiniCounter(title: "Strength", value: today?.strength ?? 0, goal: nil, unit: "min", step: 10) { delta in
                        repo.updateDay(key) { $0.strength = max(0, $0.strength + delta) }
                    }
                }
                noiseCard
                symptomsCard
            }
            .padding(Metrics.gutter)
        }
        .background(Palette.bg)
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                Text(Logic.greeting()).font(.system(size: 28, weight: .heavy)).foregroundStyle(Palette.ink)
            }
            Spacer()
            let streak = Logic.streak(takenDays: Set(days.filter { $0.takenAt != nil }.map(\.day)))
            Text("\(streak)-day streak")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Palette.accentDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.accentSoft, in: Capsule())
            NavigationLink(value: "medication") {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Palette.card, in: Circle())
            }
            .accessibilityLabel("Medication and reminders")
        }
    }

    private func proteinCard(target: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                RingView(progress: Double(protein) / Double(max(1, target))) {
                    VStack(spacing: 0) {
                        Text("\(protein)").font(.system(size: 26, weight: .heavy)).foregroundStyle(Palette.ink)
                        Text("of \(target) g").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protein today").font(.subheadline.weight(.bold)).foregroundStyle(Palette.inkSoft)
                    Text(protein >= target ? "Target reached. Nice work." : "\(target - protein) g to go. Protein helps you keep muscle.")
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            FlowLayout {
                ForEach(Catalog.quickFoods) { f in
                    Button {
                        repo.addFood(f, meal: Meal.at(Date()), day: key)
                    } label: {
                        HStack(spacing: 6) {
                            Text("+\(f.protein) g").font(.system(size: 14, weight: .heavy)).foregroundStyle(Palette.warmDark)
                            Text(f.shortName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Palette.warmSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.warmLight, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(f.shortName), \(f.protein) grams protein")
                }
            }
            Button("Search all foods") { showFood = true }.buttonStyle(FilledButtonStyle(kind: .secondary))
        }
        .card()
    }

    private var noiseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Food noise").font(.system(size: 17, weight: .heavy))
                Spacer()
                if let n = today?.foodNoise {
                    Text(Catalog.noiseWords[n]).font(.subheadline.weight(.bold)).foregroundStyle(Palette.muted)
                }
            }
            Text("How loud are thoughts about food today?").font(.footnote).foregroundStyle(Palette.muted)
            ScaleView(value: today?.foodNoise, words: Catalog.noiseWords) { n in
                repo.updateDay(key) { $0.foodNoise = n }
            }
        }
        .card()
    }

    private var symptomsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("How do you feel?").font(.system(size: 17, weight: .heavy))
                Spacer()
                Button("Add details") {
                    symptomDetail = symptoms.first { $0.kind != .good }?.kind ?? .nausea
                }
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
            }
            FlowLayout {
                ForEach(SymptomKind.allCases) { kind in
                    ChipView(label: kind.label, selected: symptoms.contains { $0.kind == kind }, warm: kind != .good) {
                        repo.toggleSymptom(kind, day: key)
                    }
                }
            }
        }
        .card()
    }

    // MARK: Actions

    private func take() {
        let now = Date()
        repo.updateDay(key) {
            $0.takenAt = now
            $0.skipped = false
        }
        if let p = profile, let left = p.tabletsLeft { p.tabletsLeft = max(0, left - 1); repo.save() }
        if let p = profile { WaitActivityController.start(takenAt: now, waitMinutes: p.waitMinutes, medication: p.medication.label) }
    }

    private func undo() {
        repo.updateDay(key) { $0.takenAt = nil }
        if let p = profile, let left = p.tabletsLeft { p.tabletsLeft = left + 1; repo.save() }
        WaitActivityController.end()
    }

    private func skip() {
        repo.updateDay(key) { $0.skipped = true }
    }
}

struct TabletCard: View {
    let profile: Profile
    let day: DayLog?
    let onTake: () -> Void
    let onUndo: () -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = TabletState.of(
                takenAt: day?.takenAt, skipped: day?.skipped ?? false, waitMinutes: profile.waitMinutes,
                doseHour: profile.doseHour, doseMinute: profile.doseMinute, now: context.date
            )
            content(state, now: context.date)
        }
    }

    @ViewBuilder
    private func content(_ state: TabletState, now: Date) -> some View {
        switch state {
        case .pending(let overdue):
            VStack(alignment: .leading, spacing: 12) {
                Text(overdue ? "Due at \(Logic.clock(hour: profile.doseHour, minute: profile.doseMinute)) · not logged" : "Today's tablet")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(overdue ? Palette.warmInk : Color.white.opacity(0.85))
                Text(overdue ? "Did you take your tablet this morning?" : "Take it on an empty stomach")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(overdue ? Palette.ink : Color.white)
                Text(overdue
                     ? "If you missed it, follow the missed-dose instructions on your label. Don't take two to catch up."
                     : "With a small sip of water, then wait \(profile.waitMinutes) min before food, drinks or other medicines.")
                    .font(.system(size: 15))
                    .foregroundStyle(overdue ? Palette.inkSoft : Color.white.opacity(0.9))
                Button(overdue ? "Yes, I took it" : "I took it", action: onTake)
                    .buttonStyle(FilledButtonStyle(kind: overdue ? .primary : .light))
                if overdue {
                    Button("I skipped today", action: onSkip).buttonStyle(FilledButtonStyle(kind: .secondary))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(overdue ? Palette.card : Palette.accent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(overdue ? Palette.warm : Color.clear, lineWidth: 2))

        case .skipped:
            VStack(alignment: .leading, spacing: 8) {
                Text("Skipped today").font(.system(size: 20, weight: .heavy)).foregroundStyle(Palette.ink)
                Text("Logged as skipped. Your visit summary will show it.").foregroundStyle(Palette.inkSoft)
                Button("Actually, I took it", action: onTake).buttonStyle(FilledButtonStyle(kind: .secondary))
            }
            .card()

        case .waiting(let until):
            let total = TimeInterval(profile.waitMinutes * 60)
            let remaining = until.timeIntervalSince(now)
            VStack(alignment: .leading, spacing: 16) {
                if let taken = day?.takenAt {
                    Text("Taken at \(taken.formatted(date: .omitted, time: .shortened)) · empty-stomach wait")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                HStack(spacing: 20) {
                    RingView(progress: 1 - remaining / max(1, total), size: 120, stroke: 10, color: .white, track: .white.opacity(0.2)) {
                        VStack(spacing: 0) {
                            Text(Logic.countdown(remaining))
                                .font(.system(size: 28, weight: .heavy).monospacedDigit())
                                .foregroundStyle(.white)
                            Text("left").font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Breakfast at").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        Text(until.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("No food, coffee or other medicines yet.").font(.footnote).foregroundStyle(.white.opacity(0.85))
                    }
                }
                Button("Logged by mistake? Undo", action: onUndo)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .underline()
                    .frame(minHeight: 44)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

        case .clear:
            VStack(alignment: .leading, spacing: 8) {
                Text("You're clear to eat").font(.system(size: 22, weight: .heavy)).foregroundStyle(.white)
                Text("Start with protein: about 30 g at breakfast helps protect muscle.").foregroundStyle(.white.opacity(0.9))
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}

struct WeekStrip: View {
    let taken: Set<String>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DayKey.last(7), id: \.self) { d in
                let key = DayKey.of(d)
                let isToday = key == DayKey.today()
                VStack(spacing: 4) {
                    Text(d.formatted(.dateTime.weekday(.abbreviated)).prefix(2))
                        .font(.system(size: 12, weight: .semibold))
                    Text(d.formatted(.dateTime.day()))
                        .font(.system(size: 17, weight: .heavy))
                    Circle()
                        .fill(taken.contains(key) ? Palette.warm : (isToday ? Palette.onInk.opacity(0.4) : Palette.line))
                        .frame(width: 6, height: 6)
                }
                .foregroundStyle(isToday ? Palette.onInk : Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 68)
                .background(isToday ? Palette.ink : Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(d.formatted(date: .complete, time: .omitted)), tablet \(taken.contains(key) ? "taken" : "not logged")")
            }
        }
    }
}

struct MiniCounter: View {
    let title: String
    let value: Int
    let goal: Int?
    let unit: String
    var step = 1
    let change: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Palette.inkSoft)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)").font(.system(size: 26, weight: .heavy)).foregroundStyle(Palette.ink)
                Text(goal.map { "/ \($0) \(unit)" } ?? unit).font(.footnote).foregroundStyle(Palette.muted)
            }
            HStack(spacing: 8) {
                counterButton("minus", "Less \(title.lowercased())") { change(-step) }
                counterButton("plus", "More \(title.lowercased())") { change(step) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
    }

    private func counterButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Palette.neutralSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
