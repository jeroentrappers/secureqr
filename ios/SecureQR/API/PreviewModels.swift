import Foundation

// Models for the preview API (docs/api.md). Foundation only.
// Decoding is tolerant: unknown JSON fields are ignored, unknown enum values
// map to a safe default, and optional parts may be missing.

enum VerdictLevel: String, Codable, Equatable {
    case ok, caution, danger

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        // An unknown level is never treated as "ok".
        self = VerdictLevel(rawValue: value) ?? .caution
    }
}

struct VerdictReason: Decodable, Equatable {
    /// Stable identifier. Unknown codes are fine: only `message` is shown.
    let code: String
    let message: String

    private enum CodingKeys: String, CodingKey {
        case code, message
    }

    init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decodeIfPresent(String.self, forKey: .code)) ?? ""
        message = (try? container.decodeIfPresent(String.self, forKey: .message)) ?? ""
    }
}

struct Verdict: Decodable, Equatable {
    let level: VerdictLevel
    let reasons: [VerdictReason]

    private enum CodingKeys: String, CodingKey {
        case level, reasons
    }

    init(level: VerdictLevel, reasons: [VerdictReason]) {
        self.level = level
        self.reasons = reasons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = try container.decode(VerdictLevel.self, forKey: .level)
        let decoded = (try? container.decodeIfPresent([VerdictReason].self, forKey: .reasons)) ?? nil
        reasons = (decoded ?? []).filter { !$0.message.isEmpty }
    }
}

enum HopKind: String, Equatable {
    case start, http, client, unknown
}

struct Hop: Decodable, Equatable {
    let url: String
    let host: String
    let status: Int?
    let kind: HopKind

    private enum CodingKeys: String, CodingKey {
        case url, host, status, kind
    }

    init(url: String, host: String, status: Int?, kind: HopKind) {
        self.url = url
        self.host = host
        self.status = status
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        host = ((try? container.decodeIfPresent(String.self, forKey: .host)) ?? nil) ?? ""
        status = (try? container.decodeIfPresent(Int.self, forKey: .status)) ?? nil
        let rawKind = ((try? container.decodeIfPresent(String.self, forKey: .kind)) ?? nil) ?? ""
        kind = HopKind(rawValue: rawKind) ?? .unknown
    }
}

struct Reputation: Decodable, Equatable {
    /// Blocklist services that answered.
    let checked: [String]
    /// Services that list a host in the chain as malicious.
    let flaggedBy: [String]
    let flaggedHost: String?

    enum Status: Equatable {
        case flagged
        case clean
        /// Nothing could be checked: show no chip.
        case unknown
    }

    var status: Status {
        if !flaggedBy.isEmpty { return .flagged }
        if !checked.isEmpty { return .clean }
        return .unknown
    }

    private enum CodingKeys: String, CodingKey {
        case checked, flaggedBy, flaggedHost
    }

    init(checked: [String], flaggedBy: [String], flaggedHost: String?) {
        self.checked = checked
        self.flaggedBy = flaggedBy
        self.flaggedHost = flaggedHost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checked = ((try? container.decodeIfPresent([String].self, forKey: .checked)) ?? nil) ?? []
        flaggedBy = ((try? container.decodeIfPresent([String].self, forKey: .flaggedBy)) ?? nil) ?? []
        flaggedHost = (try? container.decodeIfPresent(String.self, forKey: .flaggedHost)) ?? nil
    }
}

struct PreviewResult: Decodable, Equatable {
    let id: String
    let requestedUrl: String
    let finalUrl: String
    let finalHost: String
    /// Registrable domain of `finalHost`; highlighted in the UI.
    let finalDomain: String
    let title: String
    let https: Bool
    let hops: [Hop]
    /// Relative to the API base URL. Nil when the page could not be rendered.
    let screenshotUrl: String?
    /// Optional: absent on older servers.
    let reputation: Reputation?
    let verdict: Verdict
    let durationMs: Int
    /// True when the server reused an answer from the last ten minutes.
    let cached: Bool
    /// When the link was actually visited. Optional.
    let checkedAt: Date?

    /// Number of redirects: every hop after the scanned URL.
    var redirectCount: Int {
        return max(hops.count - 1, 0)
    }

    var reputationStatus: Reputation.Status {
        return reputation?.status ?? .unknown
    }

    private enum CodingKeys: String, CodingKey {
        case id, requestedUrl, finalUrl, finalHost, finalDomain, title, https
        case hops, screenshotUrl, reputation, verdict, durationMs, cached, checkedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func string(_ key: CodingKeys) -> String? {
            return (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil
        }

        // The essentials must be there.
        finalUrl = try container.decode(String.self, forKey: .finalUrl)
        finalHost = try container.decode(String.self, forKey: .finalHost)
        verdict = try container.decode(Verdict.self, forKey: .verdict)

        id = string(.id) ?? ""
        requestedUrl = string(.requestedUrl) ?? ""
        finalDomain = string(.finalDomain) ?? finalHost
        title = string(.title) ?? ""
        let isHTTPS = (try? container.decodeIfPresent(Bool.self, forKey: .https)) ?? nil
        https = isHTTPS ?? finalUrl.lowercased().hasPrefix("https://")
        hops = ((try? container.decodeIfPresent([Hop].self, forKey: .hops)) ?? nil) ?? []
        let screenshot = string(.screenshotUrl) ?? ""
        screenshotUrl = screenshot.isEmpty ? nil : screenshot
        reputation = (try? container.decodeIfPresent(Reputation.self, forKey: .reputation)) ?? nil
        durationMs = ((try? container.decodeIfPresent(Int.self, forKey: .durationMs)) ?? nil) ?? 0
        cached = ((try? container.decodeIfPresent(Bool.self, forKey: .cached)) ?? nil) ?? false
        checkedAt = PreviewDecoding.date(fromISO8601: string(.checkedAt) ?? "")
    }

    /// Whole minutes since a reused answer was produced; nil for a fresh
    /// answer or when the server did not say when it checked.
    func minutesSinceChecked(now: Date = Date()) -> Int? {
        guard cached, let checkedAt = checkedAt else { return nil }
        return max(0, Int(now.timeIntervalSince(checkedAt) / 60))
    }
}

/// Why a preview could not be shown.
enum PreviewFailure: Error, Equatable {
    /// The server answered with an error. `message` is safe to display.
    case server(code: String, message: String)
    /// The phone has no connection, or the server cannot be reached.
    case offline
    /// The request ran into the client timeout.
    case timedOut
    case cancelled
    case unexpected

    static let knownCodes: Set<String> = [
        "invalid_url", "blocked_target", "unreachable", "rate_limited", "timeout", "internal"
    ]

    /// Retrying cannot help when the link itself was refused.
    var isRetryable: Bool {
        switch self {
        case .server(let code, _):
            return code != "invalid_url" && code != "blocked_target"
        case .offline, .timedOut, .unexpected:
            return true
        case .cancelled:
            return false
        }
    }
}

enum PreviewDecoding {
    private struct ErrorBody: Decodable {
        struct Detail: Decodable {
            let code: String?
            let message: String?
        }
        let error: Detail
    }

    /// Parses an ISO 8601 timestamp, with or without fractional seconds.
    static func date(fromISO8601 text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }

    /// Turns an HTTP answer into a result, or throws a `PreviewFailure`.
    static func decode(status: Int, data: Data) throws -> PreviewResult {
        if (200...299).contains(status) {
            do {
                return try JSONDecoder().decode(PreviewResult.self, from: data)
            } catch {
                throw PreviewFailure.unexpected
            }
        }

        let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
        let code = body?.error.code ?? fallbackCode(forStatus: status)
        let message = body?.error.message ?? ""
        throw PreviewFailure.server(code: code, message: message)
    }

    /// Used when an error response has no readable body.
    static func fallbackCode(forStatus status: Int) -> String {
        switch status {
        case 400: return "invalid_url"
        case 422: return "unreachable"
        case 429: return "rate_limited"
        case 504: return "timeout"
        default: return "internal"
        }
    }
}
