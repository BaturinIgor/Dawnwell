import Foundation
import SwiftData

/// Plain copies of every stored record, used for backup files and local copies.
/// Pure Codable values, so they can be compared and tested without a store.
struct Snapshot: Codable, Equatable {
    struct ProfileData: Codable, Equatable {
        var createdAt: Date
        var onboarded: Bool
        var medication: String
        var doseLabel: String
        var doseHour: Int
        var doseMinute: Int
        var waitMinutes: Int
        var proteinTarget: Int
        var fiberTarget: Int
        var waterTarget: Int
        var weightUnit: String
        var startWeight: Double?
        var goalWeight: Double?
        var tabletsLeft: Int?
        var remindTablet: Bool
        var remindWaitOver: Bool
        var remindProtein: Bool
        var remindRefill: Bool
        var questions: String
    }
    struct DayData: Codable, Equatable {
        var day: String
        var takenAt: Date?
        var skipped: Bool
        var water: Int
        var fiber: Int
        var foodNoise: Int?
        var strength: Int
        var updatedAt: Date
    }
    struct FoodData: Codable, Equatable {
        var day: String
        var name: String
        var protein: Int
        var meal: String
        var at: Date
    }
    struct SymptomData: Codable, Equatable {
        var day: String
        var kind: String
        var severity: Int
        var triggers: [String]
        var note: String
        var at: Date
    }
    struct WeightData: Codable, Equatable {
        var day: String
        var value: Double
        var at: Date
    }
    struct DoseData: Codable, Equatable {
        var label: String
        var from: String
        var at: Date
    }

    var profile: ProfileData?
    var days: [DayData]
    var foods: [FoodData]
    var symptoms: [SymptomData]
    var weights: [WeightData]
    var doses: [DoseData]

    var isEmpty: Bool { profile?.onboarded != true && days.isEmpty && weights.isEmpty }

    var summary: String {
        let d = days.count, w = weights.count
        return "\(d) day\(d == 1 ? "" : "s") of logs, \(w) weight entr\(w == 1 ? "y" : "ies")"
    }
}

struct BackupFile: Codable {
    static let mark = "dawnwell-backup"
    static let currentVersion = 2

    var format: String = BackupFile.mark
    var formatVersion: Int = BackupFile.currentVersion
    var exportedAt: Date
    var data: Snapshot

    static func encode(_ snapshot: Snapshot, at date: Date = Date()) throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(BackupFile(exportedAt: date, data: snapshot))
    }

    enum ReadError: LocalizedError, Equatable {
        case notABackup, newerVersion, damaged
        var errorDescription: String? {
            switch self {
            case .notABackup: return "This file isn't a Dawnwell backup."
            case .newerVersion: return "This backup was made by a newer version of Dawnwell. Update the app, then try again."
            case .damaged: return "This backup file is damaged and can't be read."
            }
        }
    }

    static func decode(_ data: Data) throws -> BackupFile {
        struct Header: Decodable { var format: String?; var formatVersion: Int? }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let header = try? dec.decode(Header.self, from: data), header.format == mark else { throw ReadError.notABackup }
        if (header.formatVersion ?? 0) > currentVersion { throw ReadError.newerVersion }
        do { return try dec.decode(BackupFile.self, from: data) } catch { throw ReadError.damaged }
    }

    static func fileName(for date: Date = Date()) -> String { "dawnwell-backup-\(DayKey.of(date)).json" }
}

extension Repository {
    func snapshot() -> Snapshot {
        let ctx = context
        let p = (try? ctx.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])))?.first
        return Snapshot(
            profile: p.map {
                .init(createdAt: $0.createdAt, onboarded: $0.onboarded, medication: $0.medicationRaw, doseLabel: $0.doseLabel,
                      doseHour: $0.doseHour, doseMinute: $0.doseMinute, waitMinutes: $0.waitMinutes,
                      proteinTarget: $0.proteinTarget, fiberTarget: $0.fiberTarget, waterTarget: $0.waterTarget,
                      weightUnit: $0.weightUnitRaw, startWeight: $0.startWeight, goalWeight: $0.goalWeight,
                      tabletsLeft: $0.tabletsLeft, remindTablet: $0.remindTablet, remindWaitOver: $0.remindWaitOver,
                      remindProtein: $0.remindProtein, remindRefill: $0.remindRefill, questions: $0.questions)
            },
            days: ((try? ctx.fetch(FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.day)]))) ?? []).map {
                .init(day: $0.day, takenAt: $0.takenAt, skipped: $0.skipped, water: $0.water, fiber: $0.fiber,
                      foodNoise: $0.foodNoise, strength: $0.strength, updatedAt: $0.updatedAt)
            },
            foods: ((try? ctx.fetch(FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.at)]))) ?? []).map {
                .init(day: $0.day, name: $0.name, protein: $0.protein, meal: $0.mealRaw, at: $0.at)
            },
            symptoms: ((try? ctx.fetch(FetchDescriptor<SymptomEntry>(sortBy: [SortDescriptor(\.at)]))) ?? []).map {
                .init(day: $0.day, kind: $0.kindRaw, severity: $0.severity, triggers: $0.triggers, note: $0.note, at: $0.at)
            },
            weights: ((try? ctx.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.day)]))) ?? []).map {
                .init(day: $0.day, value: $0.value, at: $0.at)
            },
            doses: ((try? ctx.fetch(FetchDescriptor<DoseChange>(sortBy: [SortDescriptor(\.at)]))) ?? []).map {
                .init(label: $0.label, from: $0.from, at: $0.at)
            }
        )
    }

    /// Replace everything with a snapshot in one save. Callers keep a copy of the current data first.
    func replaceAll(with s: Snapshot) throws {
        do {
            try insertAll(s)
        } catch {
            // Leave the store exactly as it was.
            context.rollback()
            throw error
        }
    }

    private func insertAll(_ s: Snapshot) throws {
        let ctx = context
        try ctx.delete(model: Profile.self)
        try ctx.delete(model: DayLog.self)
        try ctx.delete(model: FoodEntry.self)
        try ctx.delete(model: SymptomEntry.self)
        try ctx.delete(model: WeightEntry.self)
        try ctx.delete(model: DoseChange.self)
        if let p = s.profile {
            let m = Profile()
            m.createdAt = p.createdAt
            m.onboarded = p.onboarded
            m.medicationRaw = p.medication
            m.doseLabel = p.doseLabel
            m.doseHour = p.doseHour
            m.doseMinute = p.doseMinute
            m.waitMinutes = p.waitMinutes
            m.proteinTarget = p.proteinTarget
            m.fiberTarget = p.fiberTarget
            m.waterTarget = p.waterTarget
            m.weightUnitRaw = p.weightUnit
            m.startWeight = p.startWeight
            m.goalWeight = p.goalWeight
            m.tabletsLeft = p.tabletsLeft
            m.remindTablet = p.remindTablet
            m.remindWaitOver = p.remindWaitOver
            m.remindProtein = p.remindProtein
            m.remindRefill = p.remindRefill
            m.questions = p.questions
            ctx.insert(m)
        }
        for d in s.days {
            let m = DayLog(day: d.day)
            m.takenAt = d.takenAt
            m.skipped = d.skipped
            m.water = d.water
            m.fiber = d.fiber
            m.foodNoise = d.foodNoise
            m.strength = d.strength
            m.updatedAt = d.updatedAt
            ctx.insert(m)
        }
        for f in s.foods {
            ctx.insert(FoodEntry(day: f.day, name: f.name, protein: f.protein, meal: Meal(rawValue: f.meal) ?? .snack, at: f.at))
        }
        for x in s.symptoms {
            let m = SymptomEntry(day: x.day, kind: SymptomKind(rawValue: x.kind) ?? .nausea, severity: x.severity,
                                 triggers: x.triggers, note: x.note, at: x.at)
            ctx.insert(m)
        }
        for w in s.weights { ctx.insert(WeightEntry(day: w.day, value: w.value, at: w.at)) }
        for d in s.doses { ctx.insert(DoseChange(label: d.label, from: d.from, at: d.at)) }
        try ctx.save()
    }
}
