import Foundation
import SwiftData

/// First stored shape of Dawnwell data.
///
/// Rules that keep data safe:
/// - Never edit a shipped schema. Add `SchemaV2` with a copy of the models and a stage in `DawnwellMigrationPlan`.
/// - Every property has a default and nothing is unique, so the store can later sync through the user's own iCloud.
/// - No relationships: entries point at their day by key, so a damaged or duplicated day never takes entries with it.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Profile.self, DayLog.self, FoodEntry.self, SymptomEntry.self, WeightEntry.self, DoseChange.self]
    }

    @Model
    final class Profile {
        var createdAt: Date = Date()
        var onboarded: Bool = false
        var medicationRaw: String = Medication.oralSemaglutide.rawValue
        var doseLabel: String = ""
        var doseHour: Int = 7
        var doseMinute: Int = 0
        var waitMinutes: Int = 30
        var proteinTarget: Int = 100
        var fiberTarget: Int = 25
        var waterTarget: Int = 8
        var weightUnitRaw: String = WeightUnit.lb.rawValue
        var startWeight: Double? = nil
        var goalWeight: Double? = nil
        var tabletsLeft: Int? = nil
        var remindTablet: Bool = true
        var remindWaitOver: Bool = true
        var remindProtein: Bool = true
        var remindRefill: Bool = false
        var questions: String = ""

        init() {}

        var medication: Medication {
            get { Medication(rawValue: medicationRaw) ?? .other }
            set { medicationRaw = newValue.rawValue }
        }

        var weightUnit: WeightUnit {
            get { WeightUnit(rawValue: weightUnitRaw) ?? .lb }
            set { weightUnitRaw = newValue.rawValue }
        }
    }

    @Model
    final class DayLog {
        var day: String = ""
        var takenAt: Date? = nil
        var skipped: Bool = false
        var water: Int = 0
        var fiber: Int = 0
        var foodNoise: Int? = nil
        var strength: Int = 0
        var updatedAt: Date = Date()

        init(day: String) { self.day = day }
    }

    @Model
    final class FoodEntry {
        var entryID: UUID = UUID()
        var day: String = ""
        var name: String = ""
        var protein: Int = 0
        var mealRaw: String = Meal.snack.rawValue
        var at: Date = Date()

        init(day: String, name: String, protein: Int, meal: Meal, at: Date = Date()) {
            self.day = day
            self.name = name
            self.protein = protein
            self.mealRaw = meal.rawValue
            self.at = at
        }

        var meal: Meal { Meal(rawValue: mealRaw) ?? .snack }
    }

    @Model
    final class SymptomEntry {
        var day: String = ""
        var kindRaw: String = SymptomKind.nausea.rawValue
        var severity: Int = 2
        var triggers: [String] = []
        var note: String = ""
        var at: Date = Date()

        init(day: String, kind: SymptomKind, severity: Int = 2, triggers: [String] = [], note: String = "", at: Date = Date()) {
            self.day = day
            self.kindRaw = kind.rawValue
            self.severity = severity
            self.triggers = triggers
            self.note = note
            self.at = at
        }

        var kind: SymptomKind { SymptomKind(rawValue: kindRaw) ?? .nausea }
    }

    @Model
    final class WeightEntry {
        var day: String = ""
        var value: Double = 0
        var at: Date = Date()

        init(day: String, value: Double, at: Date = Date()) {
            self.day = day
            self.value = value
            self.at = at
        }
    }

    @Model
    final class DoseChange {
        var label: String = ""
        var from: String = ""
        var at: Date = Date()

        init(label: String, from: String, at: Date = Date()) {
            self.label = label
            self.from = from
            self.at = at
        }
    }
}

typealias Profile = SchemaV1.Profile
typealias DayLog = SchemaV1.DayLog
typealias FoodEntry = SchemaV1.FoodEntry
typealias SymptomEntry = SchemaV1.SymptomEntry
typealias WeightEntry = SchemaV1.WeightEntry
typealias DoseChange = SchemaV1.DoseChange

enum DawnwellMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
