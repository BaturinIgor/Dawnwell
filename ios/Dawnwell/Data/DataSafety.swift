import Foundation

/// The steps that replace or copy all data. Kept apart from the views so they can be tested.
@MainActor
enum DataSafety {
    /// Take today's local copy once. Returns true when a copy was written.
    @discardableResult
    static func takeDailyCopy(repo: Repository, copies: LocalCopies, now: Date = Date()) -> Bool {
        guard !copies.hasDailyCopy(for: DayKey.of(now)) else { return false }
        let s = repo.snapshot()
        guard !s.isEmpty else { return false }
        return (try? copies.save(s, reason: .daily, at: now)) != nil
    }

    /// Replace all data with `next`. The current data is copied first; if that copy fails, nothing is replaced.
    static func restore(_ next: Snapshot, repo: Repository, copies: LocalCopies, now: Date = Date()) throws {
        let current = repo.snapshot()
        if !current.isEmpty { try copies.save(current, reason: .beforeRestore, at: now) }
        try repo.replaceAll(with: next)
    }

    /// Write a backup file to a temporary folder, for the share sheet.
    static func exportFile(repo: Repository, now: Date = Date()) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(BackupFile.fileName(for: now))
        try BackupFile.encode(repo.snapshot(), at: now).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
