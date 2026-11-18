import Foundation

/// Copies of all data kept on the phone: one a day for a week, plus one before every restore.
struct LocalCopies {
    enum Reason: String, Codable {
        case daily
        case beforeRestore = "before-restore"

        var label: String { self == .daily ? "Daily copy" : "Before a restore" }
    }

    struct Copy: Identifiable, Equatable {
        let url: URL
        let reason: Reason
        let takenAt: Date
        var id: URL { url }
    }

    static let keepDaily = 7
    static let keepOther = 5

    let directory: URL

    static var standard: LocalCopies {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return LocalCopies(directory: base.appendingPathComponent("Copies", isDirectory: true))
    }

    func list() -> [Copy] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.compactMap(Self.parse).sorted { $0.takenAt > $1.takenAt }
    }

    func hasDailyCopy(for day: String) -> Bool {
        list().contains { $0.reason == .daily && DayKey.of($0.takenAt) == day }
    }

    @discardableResult
    func save(_ snapshot: Snapshot, reason: Reason, at date: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ms = Int(date.timeIntervalSince1970 * 1000)
        let url = directory.appendingPathComponent("\(reason.rawValue)_\(ms).json")
        try BackupFile.encode(snapshot, at: date).write(to: url, options: [.atomic, .completeFileProtection])
        prune()
        return url
    }

    func read(_ copy: Copy) throws -> Snapshot {
        try BackupFile.decode(Data(contentsOf: copy.url)).data
    }

    /// Which copies to delete so that only the newest `keepDaily` daily and `keepOther` other copies remain.
    static func toDelete(_ copies: [Copy]) -> [Copy] {
        let sorted = copies.sorted { $0.takenAt > $1.takenAt }
        let daily = sorted.filter { $0.reason == .daily }
        let other = sorted.filter { $0.reason != .daily }
        return Array(daily.dropFirst(keepDaily)) + Array(other.dropFirst(keepOther))
    }

    private func prune() {
        for c in Self.toDelete(list()) { try? FileManager.default.removeItem(at: c.url) }
    }

    static func parse(_ url: URL) -> Copy? {
        let name = url.deletingPathExtension().lastPathComponent
        let parts = name.split(separator: "_")
        guard url.pathExtension == "json", parts.count == 2,
              let reason = Reason(rawValue: String(parts[0])), let ms = Double(parts[1]) else { return nil }
        return Copy(url: url, reason: reason, takenAt: Date(timeIntervalSince1970: ms / 1000))
    }
}
