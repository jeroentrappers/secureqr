import Foundation

/// Looks up a user-facing string in Localizable.strings.
func L(_ key: String) -> String {
    return String(localized: String.LocalizationValue(key))
}

/// Looks up a format string and fills in its arguments.
func LF(_ key: String, _ arguments: CVarArg...) -> String {
    return String(format: L(key), locale: Locale.current, arguments: arguments)
}

// Display strings for the framework-free models. Every raw value used here
// has an entry in Localizable.strings.

extension QRType {
    var title: String { return L("qr.type." + rawValue) }

    var symbolName: String {
        switch self {
        case .paylink: return "creditcard"
        case .url: return "link"
        case .epc: return "building.columns"
        case .emv: return "creditcard"
        case .upi: return "indianrupeesign.circle"
        case .crypto: return "bitcoinsign.circle"
        case .wifi: return "wifi"
        case .contact: return "person.crop.circle"
        case .event: return "calendar"
        case .email: return "envelope"
        case .phone: return "phone"
        case .sms: return "message"
        case .geo: return "mappin.and.ellipse"
        case .otp: return "key"
        case .applink: return "arrow.up.forward.app"
        case .text: return "text.alignleft"
        }
    }
}

extension QRFieldLabel {
    var title: String { return L("qr.field." + rawValue) }
}

extension QRNoticeMessage {
    var text: String { return L("qr.notice." + rawValue) }
}

extension QRAction {
    var title: String { return L("qr.action." + rawValue) }

    var symbolName: String {
        switch self {
        case .openInApp, .openInPaymentApp: return "arrow.up.forward.app"
        case .joinWiFi: return "wifi"
        case .copy, .copyAll, .copyIBAN, .copyAddress, .copyPassword: return "doc.on.doc"
        }
    }
}

extension QRFieldValue {
    /// Plain text for copying. Secrets are included only on request.
    func plainText(includingSecrets: Bool) -> String? {
        switch self {
        case .text(let value), .mono(let value): return value
        case .secret(let value): return includingSecrets ? value : nil
        case .yes: return L("common.yes")
        case .no: return L("common.no")
        case .none: return L("common.none")
        }
    }
}

extension VerdictLevel {
    /// Banner headline. "ok" is never worded as "safe".
    var headline: String {
        switch self {
        case .ok: return L("verdict.ok")
        case .caution: return L("verdict.caution")
        case .danger: return L("verdict.danger")
        }
    }

    var symbolName: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }
}

extension QRNoticeLevel {
    var symbolName: String {
        switch self {
        case .neutral: return "lock.shield"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }
}

extension HopKind {
    var title: String {
        switch self {
        case .start: return L("hop.start")
        case .http: return L("hop.http")
        case .client: return L("hop.client")
        case .unknown: return L("hop.unknown")
        }
    }
}

extension PreviewFailure {
    var title: String {
        switch self {
        case .offline: return L("failure.offline.title")
        case .timedOut: return L("failure.timeout.title")
        case .server(let code, _):
            if PreviewFailure.knownCodes.contains(code) {
                return L("failure.server." + code + ".title")
            }
            return L("failure.generic.title")
        case .cancelled, .unexpected:
            return L("failure.generic.title")
        }
    }

    /// The server's own message when there is one.
    var message: String {
        switch self {
        case .offline: return L("failure.offline.message")
        case .timedOut: return L("failure.timeout.message")
        case .server(let code, let message):
            if !message.isEmpty { return message }
            if PreviewFailure.knownCodes.contains(code) {
                return L("failure.server." + code + ".message")
            }
            return L("failure.generic.message")
        case .cancelled, .unexpected:
            return L("failure.generic.message")
        }
    }

    var symbolName: String {
        switch self {
        case .offline: return "wifi.slash"
        case .server(code: "unauthorized", _): return "arrow.down.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
}
