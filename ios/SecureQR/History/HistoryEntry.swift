import Foundation

/// One past scan. Kept on the device only. Foundation only.
struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    /// The scanned text with secrets removed (see `ScannedPayload.redactedRaw`).
    let payload: String
    let type: QRType
    /// Host of the scanned link; nil for anything that is not a link.
    let host: String?
    /// Nil until the server has answered, and for anything that is not a link.
    var verdict: VerdictLevel?
    /// True for a link whose last check failed ("could not be checked").
    var checkFailed: Bool
    var date: Date
    /// True when a password or sign-in secret was removed from `payload`.
    let redacted: Bool

    private enum CodingKeys: String, CodingKey {
        case id, payload, type, host, verdict, checkFailed, date, redacted
    }

    init(id: UUID = UUID(), payload: ScannedPayload, date: Date = Date()) {
        self.id = id
        self.payload = payload.redactedRaw
        self.type = payload.type
        self.host = payload.host
        self.verdict = nil
        self.checkFailed = false
        // Whole seconds: that is what the file keeps, so an entry is equal
        // to itself after a reload.
        self.date = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
        self.redacted = payload.containsSecret
    }

    // Written out so that files from before `checkFailed` still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        payload = try container.decode(String.self, forKey: .payload)
        type = try container.decode(QRType.self, forKey: .type)
        host = try container.decodeIfPresent(String.self, forKey: .host)
        verdict = try container.decodeIfPresent(VerdictLevel.self, forKey: .verdict)
        checkFailed = try container.decodeIfPresent(Bool.self, forKey: .checkFailed) ?? false
        date = try container.decode(Date.self, forKey: .date)
        redacted = try container.decodeIfPresent(Bool.self, forKey: .redacted) ?? false
    }
}

/// Reads and writes the history file.
enum HistoryFile {
    static let maximumEntries = 500

    static func encode(_ entries: [HistoryEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    static func decode(_ data: Data) throws -> [HistoryEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([HistoryEntry].self, from: data)
    }

    /// An unreadable or missing file yields an empty history.
    static func load(from url: URL) -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? decode(data) else {
            return []
        }
        return entries
    }

    static func save(_ entries: [HistoryEntry], to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(entries).write(to: url, options: [.atomic])
    }
}
