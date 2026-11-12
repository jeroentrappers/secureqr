import Foundation

// Pure Foundation. No UIKit, no SwiftUI, no localisation lookups: the UI layer
// maps the enums below to display strings.

/// The payload types from docs/qr-types.md, in classification order.
enum QRType: String, Codable, CaseIterable {
    case login, chat, paylink, url, epc, swissqr, spd, emv, upi, crypto, wifi, contact, event, email, phone, sms, geo
    case otp, otpexport, esim, device, healthcert, unsafe, applink, text
}

// MARK: - Typed payloads

/// A chat link of a messaging service.
struct ChatLink: Equatable {
    var service: String
    /// Phone number with a leading `+`, or empty.
    var number: String
    /// `@name` for Telegram, the page name for Messenger, or empty.
    var handle: String
    /// True for a Telegram invite: there is no handle to show.
    var isInvite: Bool
    var message: String
}

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
    /// "Pix" for a Brazilian Pix code, otherwise empty.
    var provider: String
    var merchant: String
    var city: String
    var country: String
    var amount: String
    /// ISO 4217 numeric code as found in tag 53.
    var currencyCode: String
    /// Alphabetic code when known ("THB"), otherwise the numeric code.
    var currency: String
    /// The Pix key or payment link, otherwise empty.
    var payeeAddress: String
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

/// A `DTSTART` / `DTEND` value that parsed. A date without a time is an
/// all-day date, kept as midnight local time.
struct EventDate: Equatable {
    var date: Date
    var isAllDay: Bool
}

struct CalendarEvent: Equatable {
    var title: String
    var start: String
    var end: String
    var location: String
    var details: String
    /// Nil when the code has no start date or it does not parse.
    var startDate: EventDate?
    var endDate: EventDate?

    /// Start and end for the system's new-event screen. Nil when the start
    /// date does not parse: the event can then not be added.
    var schedule: (start: Date, end: Date, isAllDay: Bool)? {
        guard let start = startDate else { return nil }
        if start.isAllDay {
            // An all-day DTEND is the day after the last day.
            if let end = endDate, end.isAllDay, end.date > start.date,
               let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: end.date) {
                return (start.date, max(lastDay, start.date), true)
            }
            return (start.date, start.date, true)
        }
        if let end = endDate, !end.isAllDay, end.date > start.date {
            return (start.date, end.date, false)
        }
        return (start.date, start.date.addingTimeInterval(3600), false)
    }
}

struct EmailMessage: Equatable {
    var to: String
    var subject: String
    var body: String
}

/// Checks on the number of a `tel:` code.
enum PhoneNumber {
    static let premiumPatterns = [
        "^(\\+|00)(32|31|49|43|41)90\\d",
        "^090\\d",
        "^(\\+|00)449\\d",
        "^09[018]\\d",
        "^(\\+?1)?900\\d{7}$"
    ]

    /// `*` or `#`: a code for the phone network, not a number to call.
    static func isServiceCode(_ number: String) -> Bool {
        return number.contains("*") || number.contains("#")
    }

    static func isPremiumRate(_ number: String) -> Bool {
        if isServiceCode(number) { return false }
        let compact = number.filter { !" -.()[]".contains($0) }
        return premiumPatterns.contains { compact.range(of: $0, options: .regularExpression) != nil }
    }
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

/// An eSIM activation code (`LPA:`).
struct ESIMProfile: Equatable {
    /// The provider's server.
    var address: String
    var activationCode: String
}

enum QRContent: Equatable {
    case login(service: String)
    case chat(ChatLink)
    case paylink(PayLink)
    case url(URL)
    case epc(EPCPayment)
    /// Swiss QR-bill and Czech SPD carry the same fields as an EPC code.
    case swissqr(EPCPayment)
    case spd(EPCPayment)
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
    case otpexport
    case esim(ESIMProfile)
    /// `kind` is "Matter", "HomeKit" or "Wi-Fi Easy Connect".
    case device(kind: String)
    case healthcert
    case unsafe(scheme: String)
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
    case service, handle, provider, activationCode
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
    /// "Invite link": a chat invitation without a handle.
    case inviteLink
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
    case signsInOtherDevice
    case chatWithStranger
    case authenticatorExport
    case installESIM
    case mobilePlan
    case deviceSetupCode
    case healthCertificate
    case unsafeLink
    case serviceCode
    case premiumNumber
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
    /// Wi-Fi: ask the system to join the network. The system asks the user first.
    case joinWiFi
    /// Open the system's new-contact screen, filled in. The user saves there.
    case addToContacts
    /// Open the system's new-event screen, filled in. The user saves there.
    case addToCalendar
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
        case .login: return .login
        case .chat: return .chat
        case .paylink: return .paylink
        case .url: return .url
        case .epc: return .epc
        case .swissqr: return .swissqr
        case .spd: return .spd
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
        case .otpexport: return .otpexport
        case .esim: return .esim
        case .device: return .device
        case .healthcert: return .healthcert
        case .unsafe: return .unsafe
        case .applink: return .applink
        case .text: return .text
        }
    }

    /// The bank transfer of an `epc`, `swissqr` or `spd` code.
    var bankTransfer: EPCPayment? {
        switch content {
        case .epc(let p), .swissqr(let p), .spd(let p): return p
        default: return nil
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
        case .login(let service):
            add(.service, service)
        case .chat(let c):
            add(.service, c.service)
            add(.number, c.number, mono: true)
            if c.isInvite {
                rows.append(QRField(label: .handle, value: .inviteLink))
            } else {
                add(.handle, c.handle, mono: true)
            }
            add(.message, c.message)
        case .paylink(let p):
            add(.amount, p.amount)
            add(.details, p.description)
            add(.reference, p.reference, mono: true)
        case .url(let url):
            add(.url, url.absoluteString, mono: true)
        case .epc(let p), .swissqr(let p), .spd(let p):
            add(.beneficiary, p.name)
            add(.iban, p.groupedIBAN, mono: true)
            add(.bic, p.bic, mono: true)
            add(.amount, p.displayAmount)
            add(.reference, p.reference, mono: true)
            add(.message, p.message)
        case .emv(let p):
            add(.provider, p.provider)
            add(.merchant, p.merchant)
            add(.city, p.city)
            add(.country, p.country)
            add(.amount, p.amount)
            add(.currency, p.currency)
            add(.payeeAddress, p.payeeAddress, mono: true)
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
        case .otpexport, .healthcert:
            break
        case .esim(let e):
            add(.address, e.address, mono: true)
            if !e.activationCode.isEmpty {
                rows.append(QRField(label: .activationCode, value: .secret(e.activationCode)))
            }
        case .device(let kind):
            add(.type, kind)
        case .unsafe(let scheme), .applink(let scheme):
            add(.scheme, scheme, mono: true)
            add(.content, raw, mono: true)
        case .text:
            add(.content, raw)
        }
        return rows
    }

    var notice: QRNotice {
        switch content {
        case .login:
            return QRNotice(level: .danger, messages: [.signsInOtherDevice])
        case .chat:
            return QRNotice(level: .caution, messages: [.chatWithStranger])
        case .otpexport:
            return QRNotice(level: .danger, messages: [.authenticatorExport])
        case .esim:
            return QRNotice(level: .caution, messages: [.mobilePlan])
        case .device:
            return QRNotice(level: .caution, messages: [.deviceSetupCode])
        case .healthcert:
            return QRNotice(level: .caution, messages: [.healthCertificate])
        case .unsafe:
            return QRNotice(level: .danger, messages: [.unsafeLink])
        case .phone(let number):
            if PhoneNumber.isServiceCode(number) {
                return QRNotice(level: .danger, messages: [.serviceCode])
            }
            if PhoneNumber.isPremiumRate(number) {
                return QRNotice(level: .caution, messages: [.premiumNumber])
            }
            return QRNotice(level: .neutral, messages: [.readOnDevice])
        case .epc(let p), .swissqr(let p), .spd(let p):
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
        case .url, .contact, .event, .email, .geo, .text:
            return QRNotice(level: .neutral, messages: [.readOnDevice])
        }
    }

    /// What the user should do with this code, shown first on the card.
    var instruction: QRNoticeMessage? {
        switch content {
        // A bank transfer is plain text, not a link: there is nothing to open.
        case .epc, .swissqr, .spd: return .scanWithBankingApp
        case .esim: return .installESIM
        default: return nil
        }
    }

    /// Display title when it is not simply the type's name.
    var providerTitle: String? {
        if case .paylink(let link) = content { return link.provider }
        return nil
    }

    var actions: [QRAction] {
        switch content {
        // Never opened and never copied.
        case .login, .otpexport, .device, .healthcert: return []
        case .chat: return [.openInApp, .copy]
        case .paylink: return [.openInPaymentApp, .copy]
        case .url: return [.copy]
        case .epc, .swissqr, .spd: return [.copyIBAN, .copyAll]
        case .emv: return [.copyAll]
        case .upi: return [.openInApp, .copy]
        case .crypto: return [.openInApp, .copyAddress]
        case .wifi(let w):
            // Without a name there is nothing to join.
            return (w.ssid.isEmpty ? [] : [.joinWiFi]) + (w.password.isEmpty ? [] : [.copyPassword])
        case .contact: return [.addToContacts, .copyAll]
        case .event(let e):
            // Without a start date there is nothing to put in a calendar.
            return (e.schedule == nil ? [] : [.addToCalendar]) + [.copyAll]
        case .phone(let number):
            // A service code is never dialled from here.
            return PhoneNumber.isServiceCode(number) ? [.copy] : [.openInApp, .copy]
        case .email, .sms, .geo: return [.openInApp, .copy]
        case .otp, .esim, .unsafe: return [.copy]
        case .applink: return [.openInApp, .copy]
        case .text: return [.copy]
        }
    }

    /// True when the scanned text carries something that must never be shown
    /// in the raw section or written to history (OTP secret, Wi-Fi password,
    /// a sign-in or setup code, an eSIM activation code, a health certificate).
    var containsSecret: Bool {
        switch content {
        case .otp, .login, .otpexport, .esim, .device, .healthcert: return true
        case .wifi(let w): return !w.password.isEmpty
        default: return false
        }
    }

    /// The scanned text with secrets removed. Safe to display and to store.
    var redactedRaw: String {
        switch content {
        case .otp: return QRRedaction.otpWithoutSecret(raw)
        case .wifi(let w): return QRRedaction.wifiWithoutPassword(w)
        case .login: return QRRedaction.loginWithoutCode(raw)
        case .otpexport: return QRRedaction.prefixOnly(raw, length: "otpauth-migration://".count)
        case .esim: return QRRedaction.esimWithoutActivationCode(raw)
        case .device, .healthcert: return QRRedaction.prefixOnly(raw, length: QRClassifier.codePrefixLength(raw))
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
        case .login(let service): return service
        case .chat(let c): return firstNonEmpty(c.number, c.handle, c.service)
        case .paylink(let p): return firstNonEmpty(p.description, p.amount, p.provider)
        case .url(let url): return url.host ?? url.absoluteString
        case .epc(let p), .swissqr(let p), .spd(let p): return firstNonEmpty(p.name, p.groupedIBAN)
        case .emv(let p): return firstNonEmpty(p.merchant, p.city, p.provider)
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
        case .otpexport, .healthcert: return ""
        case .esim(let e): return e.address
        case .device(let kind): return kind
        case .unsafe(let scheme), .applink(let scheme): return scheme
        case .text: return String(raw.prefix(80))
        }
    }
}
