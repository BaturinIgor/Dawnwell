import SwiftData
import SwiftUI

struct LogFoodView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let day: String
    @State private var meal = Meal.at(Date())
    @State private var query = ""
    @State private var picked: Set<String> = []
    @State private var customName = ""
    @State private var customGrams = ""

    private var list: [Food] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return Catalog.foods
            .filter { q.isEmpty || $0.name.lowercased().contains(q) }
            .sorted { $0.protein > $1.protein }
    }

    private var chosen: [Food] { Catalog.foods.filter { picked.contains($0.name) } }
    private var custom: (name: String, protein: Int)? {
        let name = customName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let g = Int(customGrams), g > 0 else { return nil }
        return (name, g)
    }
    private var total: Int { chosen.reduce(0) { $0 + $1.protein } + (custom?.protein ?? 0) }
    private var count: Int { chosen.count + (custom == nil ? 0 : 1) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Meal", selection: $meal) {
                        ForEach(Meal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    Text("Smaller, protein-first meals are often easier on your stomach.")
                        .font(.footnote)
                        .foregroundStyle(Palette.warmInk)
                        .listRowBackground(Palette.warmSoft)
                }
                Section {
                    ForEach(list) { f in
                        let on = picked.contains(f.name)
                        Button {
                            if on { picked.remove(f.name) } else { picked.insert(f.name) }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                                    Text(f.portion).font(.footnote).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Text("\(f.protein) g").font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.warmDark)
                                Image(systemName: on ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Palette.accent)
                            }
                            .frame(minHeight: 52)
                        }
                        .accessibilityLabel("\(on ? "Remove" : "Add") \(f.name), \(f.protein) grams protein")
                    }
                }
                Section("Something else") {
                    TextField("Food", text: $customName)
                    TextField("Protein in grams", text: $customGrams).keyboardType(.numberPad)
                }
            }
            .searchable(text: $query, prompt: "Search foods")
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(count) item\(count == 1 ? "" : "s") · \(meal.rawValue)").font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
                        Text("+\(total) g protein").font(.system(size: 20, weight: .heavy)).foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    Button("Add") {
                        Repository(context: context).addFoods(chosen, custom: custom, meal: meal, day: day)
                        dismiss()
                    }
                    .buttonStyle(FilledButtonStyle())
                    .frame(width: 120)
                    .disabled(count == 0)
                    .opacity(count == 0 ? 0.5 : 1)
                }
                .padding(Metrics.gutter)
                .background(.bar)
            }
        }
    }
}
