import Foundation
import Combine

/// Past scans, newest first. Stored as a JSON file in Application Support
/// and nowhere else. Use from the main thread.
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry]

    private let fileURL: URL

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("SecureQR", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    init(fileURL: URL = HistoryStore.defaultFileURL) {
        self.fileURL = fileURL
        self.entries = HistoryFile.load(from: fileURL)
    }

    /// Records a scan and returns the id of its entry. Secrets are removed
    /// by `HistoryEntry` before anything is written.
    @discardableResult
    func record(_ payload: ScannedPayload) -> UUID {
        let entry = HistoryEntry(payload: payload)
        entries.insert(entry, at: 0)
        if entries.count > HistoryFile.maximumEntries {
            entries.removeLast(entries.count - HistoryFile.maximumEntries)
        }
        save()
        return entry.id
    }

    func setVerdict(_ level: VerdictLevel, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].verdict = level
        entries[index].checkFailed = false
        save()
    }

    /// Marks a link as "could not be checked". An earlier verdict is dropped:
    /// it no longer describes the latest attempt.
    func markCheckFailed(for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].verdict = nil
        entries[index].checkFailed = true
        save()
    }

    func remove(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries.remove(at: index)
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func save() {
        do {
            try HistoryFile.save(entries, to: fileURL)
        } catch {
            // History is a convenience; a failed write must not get in the way.
        }
    }
}
