import Foundation

// Pure Foundation. No UIKit, no SwiftUI, no localisation lookups: the UI layer
// maps the enums below to display strings.

/// The payload types from docs/qr-types.md, in classification order.
enum QRType: String, Codable, CaseIterable {
    case paylink, url, epc, emv, upi, crypto, wifi, contact, event, email, phone, sms, geo, otp, applink, text
}

// MARK: - Typed payloads

/// A web link that belongs to a payment app (see `PaymentApps`).
struct PayLink: Equatable {
    /// Name shown as the card title, e.g. "Bancontact (Payconiq)".
    var provider: String
    /// Display amount ("12.50 EUR"), or empty.
    var amount: String
    var description: String
    var reference: String
}

struct EPCPayment: Equatable {
    var bic: String
    var name: String
    /// Spaces removed, upper-cased.
    var iban: String
    /// Amount as written in the code, without the currency prefix ("25.00").
    var amount: String
    var currency: String
    var purpose: String
    var reference: String
    var message: String
    var information: String

    var isIBANValid: Bool { IBAN.isValid(iban) }
    var groupedIBAN: String { IBAN.grouped(iban) }
    var displayAmount: String {
        if amount.isEmpty { return "" }
        return currency.isEmpty ? amount : amount + " " + currency
    }
}

struct EMVPayment: Equatable {
    var merchant: String
    var city: String
    var country: String
    var amount: String
    /// ISO 4217 numeric code as found in tag 53.
    var currencyCode: String
    /// Alphabetic code when known ("THB"), otherwise the numeric code.
    var currency: String
}

struct UPIPayment: Equatable {
    var payeeName: String
    var payeeAddress: String
    var amount: String
    var currency: String
    var note: String
}

struct CryptoPayment: Equatable {
    var scheme: String
    var network: String
    var address: String
    var amount: String
    var label: String
    var message: String
}

struct WiFiNetwork: Equatable {
    var ssid: String
    var security: String
    var password: String
    /// nil when the code does not say.
    var hidden: Bool?

    var isOpen: Bool {
        let value = security.trimmingCharacters(in: .whitespaces).lowercased()
        return value.isEmpty || value == "nopass"
    }
}

struct ContactCard: Equatable {
    var name: String
    var phones: [String]
    var emails: [String]
    var organisation: String
    var address: String
    var url: String
}

struct CalendarEvent: Equatable {
    var title: String
    var start: String
    var end: String
    var location: String
    var details: String
}

struct EmailMessage: Equatable {
    var to: String
    var subject: String
    var body: String
}

struct SMSMessage: Equatable {
    var number: String
    var message: String

    /// 3 to 6 digits: a short code that may be premium rate.
    var isShortCode: Bool {
        let digits = number.trimmingCharacters(in: .whitespaces)
        guard (3...6).contains(digits.count) else { return false }
        return digits.allSatisfy { QRText.isASCIIDigit($0) }
    }
}

struct GeoLocation: Equatable {
    var latitude: String
    var longitude: String
    var label: String
}

/// Deliberately has no field for the secret: it is never kept in the model.
struct OTPAuth: Equatable {
    var issuer: String
    var account: String
    var type: String
}

enum QRContent: Equatable {
    case paylink(PayLink)
    case url(URL)
    case epc(EPCPayment)
    case emv(EMVPayment)
    case upi(UPIPayment)
    case crypto(CryptoPayment)
    case wifi(WiFiNetwork)
    case contact(ContactCard)
    case event(CalendarEvent)
    case email(EmailMessage)
    case phone(String)
    case sms(SMSMessage)
    case geo(GeoLocation)
    case otp(OTPAuth)
    case applink(scheme: String)
    case text
}

// MARK: - Presentation model (still UI-framework free)

enum QRFieldLabel: String {
    case beneficiary, iban, bic, amount, reference, message
    case merchant, city, country, currency
    case payeeName, payeeAddress, note
    case network, address, label
    case security, password, hidden
    case name, phone, email, organisation, url
    case title, start, end, location, details
    case to, subject, body
    case number
    case latitude, longitude
    case issuer, account, type
    case scheme, content
}

enum QRFieldValue: Equatable {
    /// Ordinary text.
    case text(String)
    /// An identifier (IBAN, address, number …): shown in monospace.
    case mono(String)
    /// Masked until the user reveals it.
    case secret(String)
    case yes
    case no
    /// "None", e.g. a Wi-Fi network without security.
    case none
}

struct QRField: Equatable {
    var label: QRFieldLabel
    var value: QRFieldValue
}

enum QRNoticeLevel: String, Equatable {
    case neutral, caution, danger
}

enum QRNoticeMessage: String, Equatable {
    case paymentRequest
    case paymentRequestInApp
    case scanWithBankingApp
    case cryptoIrreversible
    case invalidIBAN
    case signInSecret
    case openNetwork
    case shortCode
    case opensOtherApp
    case readOnDevice
}

struct QRNotice: Equatable {
    var level: QRNoticeLevel
    var messages: [QRNoticeMessage]
}

enum QRAction: String, Equatable {
    /// Hand the original scanned text, unchanged, to the system.
    case openInApp
    /// The same hand-off, worded for a payment-app link.
    case openInPaymentApp
    case copy
    case copyAll
    case copyIBAN
    case copyAddress
    case copyPassword
}

// MARK: - Scanned payload

struct ScannedPayload: Equatable {
    /// The scanned text with surrounding whitespace removed.
    let raw: String
    let content: QRContent

    var type: QRType {
        switch content {
        case .paylink: return .paylink
        case .url: return .url
        case .epc: return .epc
        case .emv: return .emv
        case .upi: return .upi
        case .crypto: return .crypto
        case .wifi: return .wifi
        case .contact: return .contact
        case .event: return .event
        case .email: return .email
        case .phone: return .phone
        case .sms: return .sms
        case .geo: return .geo
        case .otp: return .otp
        case .applink: return .applink
        case .text: return .text
        }
    }

    /// Label/value rows for the card. Empty values are left out.
    var fields: [QRField] {
        var rows: [QRField] = []
        func add(_ label: QRFieldLabel, _ value: String, mono: Bool = false) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            rows.append(QRField(label: label, value: mono ? .mono(trimmed) : .text(trimmed)))
        }

        switch content {
        case .paylink(let p):
            add(.amount, p.amount)
            add(.details, p.description)
            add(.reference, p.reference, mono: true)
        case .url(let url):
            add(.url, url.absoluteString, mono: true)
        case .epc(let p):
            add(.beneficiary, p.name)
            add(.iban, p.groupedIBAN, mono: true)
            add(.bic, p.bic, mono: true)
            add(.amount, p.displayAmount)
            add(.reference, p.reference, mono: true)
            add(.message, p.message)
        case .emv(let p):
            add(.merchant, p.merchant)
            add(.city, p.city)
            add(.country, p.country)
            add(.amount, p.amount)
            add(.currency, p.currency)
        case .upi(let p):
            add(.payeeName, p.payeeName)
            add(.payeeAddress, p.payeeAddress, mono: true)
            add(.amount, p.amount)
            add(.currency, p.currency)
            add(.note, p.note)
        case .crypto(let p):
            add(.network, p.network)
            add(.address, p.address, mono: true)
            add(.amount, p.amount)
            add(.label, p.label)
            add(.message, p.message)
        case .wifi(let w):
            add(.network, w.ssid)
            if w.isOpen {
                rows.append(QRField(label: .security, value: QRFieldValue.none))
            } else {
                add(.security, w.security)
            }
            if !w.password.isEmpty {
                rows.append(QRField(label: .password, value: .secret(w.password)))
            }
            if let hidden = w.hidden {
                rows.append(QRField(label: .hidden, value: hidden ? .yes : .no))
            }
        case .contact(let c):
            add(.name, c.name)
            for phone in c.phones { add(.phone, phone, mono: true) }
            for email in c.emails { add(.email, email, mono: true) }
            add(.organisation, c.organisation)
            add(.address, c.address)
            add(.url, c.url, mono: true)
        case .event(let e):
            add(.title, e.title)
            add(.start, e.start)
            add(.end, e.end)
            add(.location, e.location)
            add(.details, e.details)
        case .email(let m):
            add(.to, m.to, mono: true)
            add(.subject, m.subject)
            add(.body, m.body)
        case .phone(let number):
            add(.number, number, mono: true)
        case .sms(let s):
            add(.number, s.number, mono: true)
            add(.message, s.message)
        case .geo(let g):
            add(.latitude, g.latitude, mono: true)
            add(.longitude, g.longitude, mono: true)
            add(.label, g.label)
        case .otp(let o):
            add(.issuer, o.issuer)
            add(.account, o.account)
            add(.type, o.type)
        case .applink(let scheme):
            add(.scheme, scheme, mono: true)
            add(.content, raw, mono: true)
        case .text:
            add(.content, raw)
        }
        return rows
    }

    var notice: QRNotice {
        switch content {
        case .epc(let p):
            if !p.isIBANValid {
                return QRNotice(level: .danger, messages: [.invalidIBAN, .paymentRequest])
            }
            return QRNotice(level: .caution, messages: [.paymentRequest])
        case .emv, .upi:
            return QRNotice(level: .caution, messages: [.paymentRequest])
        case .paylink:
            return QRNotice(level: .caution, messages: [.paymentRequestInApp])
        case .crypto:
            return QRNotice(level: .caution, messages: [.paymentRequest, .cryptoIrreversible])
        case .otp:
            return QRNotice(level: .danger, messages: [.signInSecret])
        case .wifi(let w):
            if w.isOpen {
                return QRNotice(level: .caution, messages: [.openNetwork])
            }
            return QRNotice(level: .neutral, messages: [.readOnDevice])
        case .sms(let s):
            if s.isShortCode {
                return QRNotice(level: .caution, messages: [.shortCode])
            }
            return QRNotice(level: .neutral, messages: [.readOnDevice])
        case .applink:
            return QRNotice(level: .caution, messages: [.opensOtherApp])
        case .url, .contact, .event, .email, .phone, .geo, .text:
            return QRNotice(level: .neutral, messages: [.readOnDevice])
        }
    }

    /// What the user should do with this code, shown first on the card.
    var instruction: QRNoticeMessage? {
        // A bank transfer is plain text, not a link: there is nothing to open.
        if case .epc = content { return .scanWithBankingApp }
        return nil
    }

    /// Display title when it is not simply the type's name.
    var providerTitle: String? {
        if case .paylink(let link) = content { return link.provider }
        return nil
    }

    var actions: [QRAction] {
        switch content {
        case .paylink: return [.openInPaymentApp, .copy]
        case .url: return [.copy]
        case .epc: return [.copyIBAN, .copyAll]
        case .emv: return [.copyAll]
        case .upi: return [.openInApp, .copy]
        case .crypto: return [.openInApp, .copyAddress]
        case .wifi(let w): return w.password.isEmpty ? [] : [.copyPassword]
        case .contact, .event: return [.copyAll]
        case .email, .phone, .sms, .geo: return [.openInApp, .copy]
        case .otp: return [.copy]
        case .applink: return [.openInApp, .copy]
        case .text: return [.copy]
        }
    }

    /// True when the scanned text carries something that must never be shown
    /// in the raw section or written to history (OTP secret, Wi-Fi password).
    var containsSecret: Bool {
        switch content {
        case .otp: return true
        case .wifi(let w): return !w.password.isEmpty
        default: return false
        }
    }

    /// The scanned text with secrets removed. Safe to display and to store.
    var redactedRaw: String {
        switch content {
        case .otp: return QRRedaction.otpWithoutSecret(raw)
        case .wifi(let w): return QRRedaction.wifiWithoutPassword(w)
        default: return raw
        }
    }

    /// What the "Copy" action puts on the clipboard. For a sign-in secret
    /// this is the issuer and account only, never the secret.
    var copyText: String {
        if case .otp(let otp) = content {
            return [otp.issuer, otp.account].filter { !$0.isEmpty }.joined(separator: "\n")
        }
        return raw
    }

    /// Host for links, nil otherwise.
    var host: String? {
        if case .url(let url) = content { return url.host }
        return nil
    }

    /// One short line that identifies the scan in a list. Never a secret.
    var summary: String {
        func firstNonEmpty(_ values: String...) -> String {
            for value in values where !value.isEmpty { return value }
            return ""
        }
        switch content {
        case .paylink(let p): return firstNonEmpty(p.description, p.amount, p.provider)
        case .url(let url): return url.host ?? url.absoluteString
        case .epc(let p): return firstNonEmpty(p.name, p.groupedIBAN)
        case .emv(let p): return firstNonEmpty(p.merchant, p.city)
        case .upi(let p): return firstNonEmpty(p.payeeName, p.payeeAddress)
        case .crypto(let p): return firstNonEmpty(p.address, p.network)
        case .wifi(let w): return w.ssid
        case .contact(let c): return firstNonEmpty(c.name, c.phones.first ?? "", c.emails.first ?? "")
        case .event(let e): return firstNonEmpty(e.title, e.start)
        case .email(let m): return m.to
        case .phone(let number): return number
        case .sms(let s): return s.number
        case .geo(let g): return firstNonEmpty(g.label, g.latitude + ", " + g.longitude)
        case .otp(let o): return firstNonEmpty(o.issuer, o.account)
        case .applink(let scheme): return scheme
        case .text: return String(raw.prefix(80))
        }
    }
}
