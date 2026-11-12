import Foundation

/// Small string helpers shared by the parsers.
enum QRText {
    static func isASCIIDigit(_ ch: Character) -> Bool {
        return ch >= "0" && ch <= "9"
    }

    static func isASCIILetter(_ ch: Character) -> Bool {
        return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z")
    }

    static func trimmed(_ value: String) -> String {
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Case-insensitive prefix test. `prefix` must be lower-case ASCII.
    static func hasPrefix(_ text: String, _ prefix: String) -> Bool {
        return text.prefix(prefix.count).lowercased() == prefix
    }

    static func dropPrefix(_ text: String, _ prefix: String) -> String {
        return String(text.dropFirst(prefix.count))
    }

    /// Splits on `\n`, `\r\n` or a lone `\r`.
    static func lines(_ text: String) -> [String] {
        let normalised = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalised.components(separatedBy: "\n")
    }

    /// Lines of a vCard / iCalendar body with folded lines joined again
    /// (a continuation line starts with a space or a tab).
    static func unfoldedLines(_ text: String) -> [String] {
        var result: [String] = []
        for line in lines(text) {
            if let first = line.first, first == " " || first == "\t", !result.isEmpty {
                result[result.count - 1] += String(line.dropFirst())
            } else {
                result.append(line)
            }
        }
        return result
    }

    static func percentDecoded(_ value: String) -> String {
        return value.removingPercentEncoding ?? value
    }

    /// Splits a URI body on the first `?`.
    static func splitQuery(_ body: String) -> (path: String, query: String) {
        guard let index = body.firstIndex(of: "?") else { return (body, "") }
        return (String(body[..<index]), String(body[body.index(after: index)...]))
    }

    /// Query items with lower-cased keys and percent-decoded values.
    /// The first occurrence of a key wins.
    static func queryItems(_ query: String) -> [String: String] {
        var items: [String: String] = [:]
        for pair in query.components(separatedBy: "&") where !pair.isEmpty {
            let key: String
            let value: String
            if let index = pair.firstIndex(of: "=") {
                key = String(pair[..<index])
                value = String(pair[pair.index(after: index)...])
            } else {
                key = pair
                value = ""
            }
            let normalisedKey = percentDecoded(key).lowercased()
            if items[normalisedKey] == nil {
                items[normalisedKey] = percentDecoded(value)
            }
        }
        return items
    }

    /// Parses `K:value;K:value;;` as used by WIFI:, MECARD: and MATMSG:.
    /// A backslash makes the next character literal (`\;`, `\:`, `\,`, `\\`).
    /// Keys are upper-cased.
    static func keyedFields(_ body: String) -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = []
        var current = ""
        var key: String?
        var escaped = false

        for ch in body {
            if escaped {
                current.append(ch)
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == ":" && key == nil {
                key = trimmed(current).uppercased()
                current = ""
            } else if ch == ";" {
                if let found = key {
                    result.append((key: found, value: current))
                }
                key = nil
                current = ""
            } else {
                current.append(ch)
            }
        }
        if let found = key, !current.isEmpty {
            result.append((key: found, value: current))
        }
        return result
    }

    /// Escapes a value for `K:value;` syntax.
    static func escapeKeyedValue(_ value: String) -> String {
        var result = ""
        for ch in value {
            if ch == "\\" || ch == ";" || ch == ":" || ch == "," {
                result.append("\\")
            }
            result.append(ch)
        }
        return result
    }

    /// Splits a vCard / iCalendar value on unescaped separators and removes
    /// the escapes (`\n` becomes a line break).
    static func splitEscaped(_ value: String, separator: Character) -> [String] {
        var parts: [String] = [""]
        var escaped = false
        for ch in value {
            if escaped {
                if ch == "n" || ch == "N" {
                    parts[parts.count - 1].append("\n")
                } else {
                    parts[parts.count - 1].append(ch)
                }
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == separator {
                parts.append("")
            } else {
                parts[parts.count - 1].append(ch)
            }
        }
        return parts
    }

    /// Removes vCard / iCalendar escapes without splitting.
    static func unescaped(_ value: String) -> String {
        var result = ""
        var escaped = false
        for ch in value {
            if escaped {
                result.append((ch == "n" || ch == "N") ? "\n" : ch)
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else {
                result.append(ch)
            }
        }
        return result
    }

    static func joinNonEmpty(_ parts: [String], separator: String) -> String {
        return parts
            .map { trimmed($0) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }
}

/// IBAN helpers (ISO 13616 mod-97 check).
enum IBAN {
    static func normalised(_ value: String) -> String {
        return value
            .filter { !$0.isWhitespace }
            .uppercased()
    }

    static func isValid(_ value: String) -> Bool {
        let iban = normalised(value)
        guard iban.count >= 15, iban.count <= 34 else { return false }
        guard iban.allSatisfy({ QRText.isASCIIDigit($0) || QRText.isASCIILetter($0) }) else { return false }

        let rearranged = iban.dropFirst(4) + iban.prefix(4)
        var remainder = 0
        for ch in rearranged {
            guard let ascii = ch.asciiValue else { return false }
            if QRText.isASCIIDigit(ch) {
                remainder = (remainder * 10 + Int(ascii) - 48) % 97
            } else {
                // "A" (65) maps to 10 … "Z" to 35: always two digits.
                remainder = (remainder * 100 + Int(ascii) - 55) % 97
            }
        }
        return remainder == 1
    }

    /// Groups of four, separated by spaces.
    static func grouped(_ value: String) -> String {
        let chars = Array(normalised(value))
        var groups: [String] = []
        var index = 0
        while index < chars.count {
            let end = min(index + 4, chars.count)
            groups.append(String(chars[index..<end]))
            index = end
        }
        return groups.joined(separator: " ")
    }
}

/// Removes secrets from payloads before they are displayed raw or stored.
enum QRRedaction {
    /// Drops the `secret` query item from an `otpauth://` URI.
    static func otpWithoutSecret(_ raw: String) -> String {
        let parts = QRText.splitQuery(raw)
        guard !parts.query.isEmpty else { return parts.path }
        let kept = parts.query.components(separatedBy: "&").filter { pair in
            let key = pair.components(separatedBy: "=").first ?? ""
            return QRText.percentDecoded(key).lowercased() != "secret"
        }
        if kept.isEmpty { return parts.path }
        return parts.path + "?" + kept.joined(separator: "&")
    }

    static let ellipsis = "…"

    /// The first `length` characters, followed by `…`.
    static func prefixOnly(_ raw: String, length: Int) -> String {
        return String(raw.prefix(length)) + ellipsis
    }

    /// A sign-in code keeps only what names the service: a web link up to
    /// and including the `/` after the host, another link its scheme, and
    /// anything else nothing at all.
    static func loginWithoutCode(_ raw: String) -> String {
        if let scheme = raw.range(of: "://"), QRText.hasPrefix(raw, "http") {
            if let slash = raw[scheme.upperBound...].firstIndex(of: "/") {
                return String(raw[...slash]) + ellipsis
            }
            return String(raw[..<scheme.upperBound]) + ellipsis
        }
        if QRClassifier.appLinkScheme(raw) != nil, let colon = raw.firstIndex(of: ":") {
            let rest = raw[raw.index(after: colon)...]
            return String(raw[...colon]) + (rest.hasPrefix("//") ? "//" : "") + ellipsis
        }
        return ellipsis
    }

    /// `LPA:1$<address>$…`: the activation code and anything after it go.
    static func esimWithoutActivationCode(_ raw: String) -> String {
        let parts = raw.components(separatedBy: "$")
        return parts.prefix(2).joined(separator: "$") + "$" + ellipsis
    }

    /// Rebuilds a `WIFI:` payload without the `P` field.
    static func wifiWithoutPassword(_ network: WiFiNetwork) -> String {
        var text = "WIFI:"
        if !network.security.isEmpty {
            text += "T:" + QRText.escapeKeyedValue(network.security) + ";"
        }
        text += "S:" + QRText.escapeKeyedValue(network.ssid) + ";"
        if let hidden = network.hidden {
            text += "H:" + (hidden ? "true" : "false") + ";"
        }
        text += ";"
        return text
    }
}
