import Foundation

enum Medication: String, CaseIterable, Identifiable, Codable {
    case oralSemaglutide = "oral-semaglutide"
    case orforglipron
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oralSemaglutide: return String(localized: "Oral semaglutide")
        case .orforglipron: return String(localized: "Orforglipron")
        case .other: return String(localized: "Another GLP-1 tablet")
        }
    }
}

enum Meal: String, CaseIterable, Identifiable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }

    /// The raw value is stored, so it stays English. This is what the user sees.
    var label: String {
        switch self {
        case .breakfast: return String(localized: "Breakfast")
        case .lunch: return String(localized: "Lunch")
        case .dinner: return String(localized: "Dinner")
        case .snack: return String(localized: "Snack")
        }
    }

    /// The meal that fits the time of day, used as the default when logging food.
    static func at(_ date: Date, calendar: Calendar = .current) -> Meal {
        let hour = calendar.component(.hour, from: date)
        if hour < 11 { return .breakfast }
        if hour < 16 { return .lunch }
        if hour < 21 { return .dinner }
        return .snack
    }
}

enum SymptomKind: String, CaseIterable, Identifiable, Codable {
    case nausea
    case constipation
    case heartburn
    case fatigue
    case noAppetite = "no-appetite"
    case good

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nausea: return String(localized: "Nausea")
        case .constipation: return String(localized: "Constipation")
        case .heartburn: return String(localized: "Heartburn")
        case .fatigue: return String(localized: "Tired")
        case .noAppetite: return String(localized: "No appetite")
        case .good: return String(localized: "Feeling good")
        }
    }
}

enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case lb
    case kg

    var id: String { rawValue }
}

struct Food: Identifiable, Hashable {
    let name: String
    let portion: String
    let protein: Int
    var short: String? = nil

    var id: String { name }
    /// `name` is stored with each entry, so it stays English. These are for display.
    var displayName: String { Loc.text(name) }
    var displayPortion: String { Loc.text(portion) }
    var shortName: String { Loc.text(short ?? name) }
}

enum Catalog {
    /// Typical protein per common portion (USDA values, rounded).
    static let foods: [Food] = [
        Food(name: "Greek yogurt, plain", portion: "3/4 cup · 170 g", protein: 17, short: "Greek yogurt"),
        Food(name: "Eggs", portion: "2 large", protein: 12, short: "2 eggs"),
        Food(name: "Protein shake", portion: "1 bottle", protein: 30),
        Food(name: "Cottage cheese", portion: "1/2 cup", protein: 14),
        Food(name: "Chicken breast", portion: "3 oz cooked", protein: 26),
        Food(name: "Tuna, canned", portion: "1 can · 5 oz", protein: 27),
        Food(name: "Salmon", portion: "3 oz cooked", protein: 22),
        Food(name: "Firm tofu", portion: "1/2 cup", protein: 11),
        Food(name: "Lentils", portion: "1/2 cup cooked", protein: 9),
        Food(name: "String cheese", portion: "1 stick", protein: 7),
        Food(name: "Turkey slices", portion: "2 oz", protein: 10),
        Food(name: "Edamame", portion: "1/2 cup", protein: 9),
    ]

    static let quickFoods: [Food] = ["Greek yogurt, plain", "Eggs", "Protein shake", "Chicken breast"]
        .compactMap { name in foods.first { $0.name == name } }

    /// Stored with each symptom in English. Show them with `Loc.text`.
    static let triggers = ["Fatty food", "Ate late", "Big portion", "Ate too soon after tablet", "Alcohol", "Not sure"]
    static var severityWords: [String] {
        ["", String(localized: "Barely there"), String(localized: "Mild"), String(localized: "Moderate"),
         String(localized: "Strong"), String(localized: "Severe")]
    }
    static var noiseWords: [String] {
        ["", String(localized: "Quiet"), String(localized: "Low"), String(localized: "Some"),
         String(localized: "Loud"), String(localized: "Constant")]
    }

    /// Show the refill heads-up at or below this many tablets.
    static let refillAt = 7
}
