import SwiftData
import SwiftUI

struct LearnView: View {
    @Environment(\.modelContext) private var context
    @Query private var days: [DayLog]
    @Query private var doses: [DoseChange]
    @State private var open: String?

    var body: some View {
        let start = LearnContent.startDay(Repository(context: context).snapshot())
        let day = LearnContent.dayNumber(start: start)
        let stage = LearnContent.stage(for: day)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    Text("Learn").font(.system(size: 28, weight: .heavy)).foregroundStyle(Palette.ink)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Day \(day)").font(.system(size: 13, weight: .heavy)).foregroundStyle(Palette.sandInk)
                        Text(stage.title).font(.system(size: 22, weight: .heavy)).foregroundStyle(Palette.ink)
                        Text(stage.tip).font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(Palette.sand)

                    ForEach(LearnContent.articles) { a in
                        let on = open == a.id
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { open = on ? nil : a.id }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(a.title).fontWeight(.bold).foregroundStyle(Palette.ink)
                                        Text("\(a.minutes) min read").font(.footnote).foregroundStyle(Palette.muted)
                                    }
                                    Spacer()
                                    Image(systemName: on ? "minus" : "plus").foregroundStyle(Palette.muted)
                                }
                                if on {
                                    Text(a.body).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityHint(on ? "Collapses the article" : "Opens the article")
                    }

                    Text("General information, not medical advice. Your medication guide and your care team come first.")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.bg)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
