import Foundation

/// Classifies scanned text per docs/qr-types.md. First match wins.
enum QRClassifier {
    static func classify(_ input: String) -> ScannedPayload {
        let raw = QRText.trimmed(input)
        return ScannedPayload(raw: raw, content: content(for: raw))
    }

    static let cryptoNetworks: [(scheme: String, name: String)] = [
        ("bitcoin", "Bitcoin"),
        ("ethereum", "Ethereum"),
        ("litecoin", "Litecoin"),
        ("bitcoincash", "Bitcoin Cash"),
        ("lightning", "Lightning")
    ]

    static let emvCurrencies: [String: String] = [
        "978": "EUR", "840": "USD", "826": "GBP", "756": "CHF",
        "356": "INR", "702": "SGD", "764": "THB", "986": "BRL"
    ]

    /// Sign-in links on the web: host (or a subdomain of it) and path prefix.
    static let loginHosts: [(host: String, path: String, service: String)] = [
        ("discord.com", "/ra/", "Discord"),
        ("discordapp.com", "/ra/", "Discord"),
        ("s.team", "/q/", "Steam"),
        ("login.weixin.qq.com", "/l/", "WeChat")
    ]

    /// Setup codes of smart-home devices.
    static let devicePrefixes: [(prefix: String, kind: String)] = [
        ("mt:", "Matter"),
        ("x-hm://", "HomeKit"),
        ("dpp:", "Wi-Fi Easy Connect")
    ]

    static let healthCertificatePrefixes = ["hc1:", "shc:/"]

    /// Schemes that can run code or open files. Never handed to the system.
    static let unsafeSchemes: Set<String> = [
        "javascript", "data", "vbscript", "file", "blob", "content",
        "intent", "android-app", "chrome", "about", "view-source", "jar"
    ]

    /// A past scan as it was stored. A sign-in code is stored without the
    /// code, so the text alone no longer says what it was: the stored type
    /// does. Such an entry must never be taken for a link.
    static func classify(stored text: String, as type: QRType) -> ScannedPayload {
        let payload = classify(text)
        if type == .login, payload.type != .login {
            return ScannedPayload(raw: payload.raw, content: .login(service: storedLoginService(payload.raw)))
        }
        return payload
    }

    private static func content(for raw: String) -> QRContent {
        // login, chat, paylink, url
        if QRText.hasPrefix(raw, "http:") || QRText.hasPrefix(raw, "https:") {
            if let url = webURL(raw) {
                // These come before url: such links never go to the server.
                let components = URLComponents(string: url.absoluteString)
                let host = components?.host ?? url.host ?? ""
                let path = components?.path ?? url.path
                if let service = loginService(host: host, path: path) {
                    return .login(service: service)
                }
                if let chat = parseChatLink(raw, host: host, path: path) {
                    return .chat(chat)
                }
                if let link = parsePayLink(raw, url: url) {
                    return .paylink(link)
                }
                return .url(url)
            }
            // Looks like a link but is not a usable one. It must not be
            // handed to the system as an app link: show it as text.
            return .text
        }
        // login
        if let service = loginService(raw) {
            return .login(service: service)
        }
        // chat
        if let chat = parseChatScheme(raw) {
            return .chat(chat)
        }
        // epc
        if let payment = parseEPC(raw) {
            return .epc(payment)
        }
        // swissqr
        if let payment = parseSwissQR(raw) {
            return .swissqr(payment)
        }
        // spd
        if QRText.hasPrefix(raw, "spd*") {
            return .spd(parseSPD(raw))
        }
        // emv
        if raw.hasPrefix("000201") {
            if let payment = parseEMV(raw) {
                return .emv(payment)
            }
            return .text
        }
        // upi
        if QRText.hasPrefix(raw, "upi://pay") {
            return .upi(parseUPI(raw))
        }
        // crypto
        for network in cryptoNetworks where QRText.hasPrefix(raw, network.scheme + ":") {
            return .crypto(parseCrypto(raw, scheme: network.scheme, network: network.name))
        }
        // wifi
        if QRText.hasPrefix(raw, "wifi:") {
            return .wifi(parseWiFi(raw))
        }
        // contact
        if QRText.hasPrefix(raw, "begin:vcard") {
            return .contact(parseVCard(raw))
        }
        if QRText.hasPrefix(raw, "mecard:") {
            return .contact(parseMECARD(raw))
        }
        // event
        if QRText.hasPrefix(raw, "begin:vevent") || QRText.hasPrefix(raw, "begin:vcalendar") {
            return .event(parseEvent(raw))
        }
        // email
        if QRText.hasPrefix(raw, "mailto:") {
            return .email(parseMailto(raw))
        }
        if QRText.hasPrefix(raw, "matmsg:") {
            return .email(parseMATMSG(raw))
        }
        // phone
        if QRText.hasPrefix(raw, "tel:") {
            let number = QRText.trimmed(QRText.percentDecoded(QRText.dropPrefix(raw, "tel:")))
            return .phone(number)
        }
        // sms
        if QRText.hasPrefix(raw, "smsto:") {
            return .sms(parseSMS(QRText.dropPrefix(raw, "smsto:")))
        }
        if QRText.hasPrefix(raw, "sms:") {
            return .sms(parseSMS(QRText.dropPrefix(raw, "sms:")))
        }
        // geo
        if QRText.hasPrefix(raw, "geo:") {
            return .geo(parseGeo(raw))
        }
        // otp
        if QRText.hasPrefix(raw, "otpauth://") {
            return .otp(parseOTP(raw))
        }
        // otpexport
        if QRText.hasPrefix(raw, "otpauth-migration://") {
            return .otpexport
        }
        // esim
        if QRText.hasPrefix(raw, "lpa:") {
            return .esim(parseESIM(raw))
        }
        // device
        for device in devicePrefixes where QRText.hasPrefix(raw, device.prefix) {
            return .device(kind: device.kind)
        }
        // healthcert
        for prefix in healthCertificatePrefixes where QRText.hasPrefix(raw, prefix) {
            return .healthcert
        }
        // unsafe, applink
        if let scheme = appLinkScheme(raw) {
            return unsafeSchemes.contains(scheme) ? .unsafe(scheme: scheme) : .applink(scheme: scheme)
        }
        return .text
    }

    // MARK: - login

    /// True for the listed host itself or any subdomain of it.
    static func host(_ host: String, isOrIsUnder domain: String) -> Bool {
        var name = host.lowercased()
        while name.hasSuffix(".") {
            name.removeLast()
        }
        return name == domain || name.hasSuffix("." + domain)
    }

    /// The scheme and, for `scheme://host…`, the host. Both lower-cased.
    static func schemeAndHost(_ raw: String) -> (scheme: String, host: String)? {
        guard let scheme = appLinkScheme(raw), let colon = raw.firstIndex(of: ":") else { return nil }
        let rest = raw[raw.index(after: colon)...]
        guard rest.hasPrefix("//") else { return (scheme, "") }
        let host = rest.dropFirst(2).prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        return (scheme, host.lowercased())
    }

    /// The service for a sign-in link on the web.
    static func loginService(host: String, path: String) -> String? {
        let lowerPath = path.lowercased()
        for entry in loginHosts where QRClassifier.host(host, isOrIsUnder: entry.host) && lowerPath.hasPrefix(entry.path) {
            return entry.service
        }
        return nil
    }

    /// The service for a sign-in code that is not a web link.
    static func loginService(_ raw: String) -> String? {
        if let link = schemeAndHost(raw) {
            if link.scheme == "tg", link.host == "login" { return "Telegram" }
            if link.scheme == "sgnl", link.host == "linkdevice" { return "Signal" }
            if link.scheme == "tsdevice" { return "Signal" }
        }
        let whatsApp = "^[12]@[A-Za-z0-9+/=_-]{16,}(,[A-Za-z0-9+/=_-]{16,}){2,}$"
        if raw.range(of: whatsApp, options: .regularExpression) != nil {
            return "WhatsApp"
        }
        return nil
    }

    /// The service of a sign-in code from history (see `QRRedaction.loginWithoutCode`).
    static func storedLoginService(_ stored: String) -> String {
        if QRText.hasPrefix(stored, "http"), let scheme = stored.range(of: "://") {
            var host = String(stored[scheme.upperBound...].prefix { $0 != "/" })
            if let at = host.lastIndex(of: "@") {
                host = String(host[host.index(after: at)...])
            }
            if let colon = host.firstIndex(of: ":") {
                host = String(host[..<colon])
            }
            for entry in loginHosts where QRClassifier.host(host, isOrIsUnder: entry.host) {
                return entry.service
            }
            return ""
        }
        if let link = schemeAndHost(stored) {
            switch link.scheme {
            case "tg": return "Telegram"
            case "sgnl", "tsdevice": return "Signal"
            default: return ""
            }
        }
        return "WhatsApp"
    }

    // MARK: - chat

    /// `+` and digits, or empty when the text is not a phone number.
    private static func chatNumber(_ text: String) -> String {
        var digits = QRText.percentDecoded(text).filter { !" -()".contains($0) }
        if digits.hasPrefix("+") {
            digits.removeFirst()
        }
        guard !digits.isEmpty, digits.allSatisfy({ QRText.isASCIIDigit($0) }) else { return "" }
        return "+" + digits
    }

    private static func chatQuery(_ raw: String) -> [String: String] {
        return QRText.queryItems(QRText.splitQuery(raw).query.components(separatedBy: "#")[0])
    }

    /// A chat link on the web, when the host is one of the chat services.
    static func parseChatLink(_ raw: String, host: String, path: String) -> ChatLink? {
        func under(_ domain: String) -> Bool { return QRClassifier.host(host, isOrIsUnder: domain) }
        let segments = path.components(separatedBy: "/").filter { !$0.isEmpty }
        let first = QRText.trimmed(segments.first ?? "")
        let items = chatQuery(raw)
        var chat = ChatLink(service: "", number: "", handle: "", isInvite: false, message: QRText.trimmed(items["text"] ?? ""))

        if under("wa.me") {
            chat.service = "WhatsApp"
            chat.number = chatNumber(first)
        } else if under("api.whatsapp.com") {
            guard first.lowercased() == "send", segments.count == 1 else { return nil }
            chat.service = "WhatsApp"
            chat.number = chatNumber(items["phone"] ?? "")
        } else if under("t.me") || under("telegram.me") {
            chat.service = "Telegram"
            if first.hasPrefix("+") || first.lowercased() == "joinchat" {
                chat.isInvite = true
            } else if !first.isEmpty {
                chat.handle = first.hasPrefix("@") ? first : "@" + first
            }
        } else if under("m.me") {
            chat.service = "Messenger"
            chat.handle = first
        } else if under("signal.me") {
            chat.service = "Signal"
        } else {
            return nil
        }
        return chat
    }

    /// `whatsapp://send`, `tg://resolve`, `viber://chat` and `viber://add`.
    static func parseChatScheme(_ raw: String) -> ChatLink? {
        guard let link = schemeAndHost(raw) else { return nil }
        let items = chatQuery(raw)
        var chat = ChatLink(service: "", number: "", handle: "", isInvite: false, message: QRText.trimmed(items["text"] ?? ""))
        switch (link.scheme, link.host) {
        case ("whatsapp", "send"):
            chat.service = "WhatsApp"
            chat.number = chatNumber(items["phone"] ?? "")
        case ("tg", "resolve"):
            chat.service = "Telegram"
            let domain = QRText.trimmed(items["domain"] ?? "")
            if !domain.isEmpty {
                chat.handle = domain.hasPrefix("@") ? domain : "@" + domain
            }
        case ("viber", "chat"), ("viber", "add"):
            chat.service = "Viber"
            chat.number = QRText.trimmed(items["number"] ?? "")
        default:
            return nil
        }
        return chat
    }

    // MARK: - url

    /// An http(s) URL with a host, or nil.
    static func webURL(_ raw: String) -> URL? {
        guard QRText.hasPrefix(raw, "http://") || QRText.hasPrefix(raw, "https://") else { return nil }
        if let url = strictWebURL(raw) {
            return url
        }
        // Codes in the wild contain spaces and other characters that need
        // encoding. Encode those and try once more.
        var allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        allowed.insert(charactersIn: "-._~:/?#[]@!$&'()*+,;=%")
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) {
            return strictWebURL(encoded)
        }
        return nil
    }

    private static func strictWebURL(_ text: String) -> URL? {
        guard let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty else {
            return nil
        }
        // The link as it was written, not a re-assembled copy.
        return URL(string: text) ?? components.url
    }

    // MARK: - paylink

    /// A payment-app link, when the host is in the `PaymentApps` table.
    static func parsePayLink(_ raw: String, url: URL) -> PayLink? {
        guard let host = URLComponents(string: url.absoluteString)?.host ?? url.host,
              let provider = PaymentApps.provider(forHost: host) else {
            return nil
        }
        // Payconiq: D = description, A = amount in euro cents, R = reference.
        let items = QRText.queryItems(QRText.splitQuery(raw).query.components(separatedBy: "#")[0])
        return PayLink(
            provider: provider,
            amount: PaymentApps.euros(fromCents: items["a"] ?? ""),
            description: QRText.trimmed(items["d"] ?? ""),
            reference: QRText.trimmed(items["r"] ?? "")
        )
    }

    // MARK: - epc

    static func parseEPC(_ raw: String) -> EPCPayment? {
        let lines = QRText.lines(raw)
        guard lines.count >= 4,
              QRText.trimmed(lines[0]).uppercased() == "BCD",
              QRText.trimmed(lines[3]).uppercased() == "SCT" else {
            return nil
        }
        func line(_ index: Int) -> String {
            return index < lines.count ? QRText.trimmed(lines[index]) : ""
        }

        var amount = line(7)
        var currency = ""
        if amount.count >= 3, amount.prefix(3).allSatisfy({ QRText.isASCIILetter($0) }) {
            currency = amount.prefix(3).uppercased()
            amount = QRText.trimmed(String(amount.dropFirst(3)))
        }

        return EPCPayment(
            bic: line(4),
            name: line(5),
            iban: IBAN.normalised(line(6)),
            amount: amount,
            currency: currency,
            purpose: line(8),
            reference: line(9),
            message: line(10),
            information: line(11)
        )
    }

    // MARK: - swissqr

    /// Swiss QR-bill: lines as for EPC, first line `SPC`.
    static func parseSwissQR(_ raw: String) -> EPCPayment? {
        let lines = QRText.lines(raw)
        guard QRText.trimmed(lines[0]).uppercased() == "SPC" else { return nil }
        func line(_ index: Int) -> String {
            return index < lines.count ? QRText.trimmed(lines[index]) : ""
        }
        return EPCPayment(
            bic: "",
            name: line(5),
            iban: IBAN.normalised(line(3)),
            amount: line(18),
            currency: line(19).uppercased(),
            purpose: "",
            reference: line(28),
            message: line(29),
            information: ""
        )
    }

    // MARK: - spd

    /// Czech payment code: `SPD*1.0*KEY:value*KEY:value`.
    static func parseSPD(_ raw: String) -> EPCPayment {
        var values: [String: String] = [:]
        for part in raw.components(separatedBy: "*").dropFirst(2) {
            guard let colon = part.firstIndex(of: ":") else { continue }
            let key = QRText.trimmed(String(part[..<colon])).uppercased()
            if values[key] == nil {
                values[key] = QRText.trimmed(QRText.percentDecoded(String(part[part.index(after: colon)...])))
            }
        }
        // ACC is the IBAN, optionally followed by `+` and the BIC.
        let account = (values["ACC"] ?? "").components(separatedBy: "+")[0]
        return EPCPayment(
            bic: "",
            name: values["RN"] ?? "",
            iban: IBAN.normalised(account),
            amount: values["AM"] ?? "",
            currency: (values["CC"] ?? "").uppercased(),
            purpose: "",
            reference: values["X-VS"] ?? "",
            message: values["MSG"] ?? "",
            information: ""
        )
    }

    // MARK: - emv

    /// Parses `TT LL value` items. Nil unless the whole string is consumed.
    static func parseTLV(_ text: String) -> [(tag: String, value: String)]? {
        let chars = Array(text)
        var items: [(tag: String, value: String)] = []
        var index = 0
        while index < chars.count {
            guard index + 4 <= chars.count else { return nil }
            let header = chars[index..<(index + 4)]
            guard header.allSatisfy({ QRText.isASCIIDigit($0) }) else { return nil }
            let tag = String(chars[index..<(index + 2)])
            guard let length = Int(String(chars[(index + 2)..<(index + 4)])) else { return nil }
            let start = index + 4
            let end = start + length
            guard end <= chars.count else { return nil }
            items.append((tag: tag, value: String(chars[start..<end])))
            index = end
        }
        return items.isEmpty ? nil : items
    }

    static func parseEMV(_ raw: String) -> EMVPayment? {
        guard raw.hasPrefix("000201"), let items = parseTLV(raw) else { return nil }
        func value(_ tag: String) -> String {
            for item in items where item.tag == tag {
                return QRText.trimmed(item.value)
            }
            return ""
        }
        // Pix: a merchant account template (26 to 51) that names the Pix
        // scheme. Sub-tag 01 is the key, 25 the payment link.
        var provider = ""
        var payeeAddress = ""
        for item in items {
            guard let tag = Int(item.tag), (26...51).contains(tag), let template = parseTLV(item.value),
                  template.contains(where: { $0.tag == "00" && $0.value.lowercased() == "br.gov.bcb.pix" }) else {
                continue
            }
            provider = "Pix"
            let key = template.first(where: { $0.tag == "01" })?.value ?? ""
            payeeAddress = QRText.trimmed(key.isEmpty ? template.first(where: { $0.tag == "25" })?.value ?? "" : key)
            break
        }
        let code = value("53")
        return EMVPayment(
            provider: provider,
            merchant: value("59"),
            city: value("60"),
            country: value("58"),
            amount: value("54"),
            currencyCode: code,
            currency: emvCurrencies[code] ?? code,
            payeeAddress: payeeAddress
        )
    }

    // MARK: - upi

    static func parseUPI(_ raw: String) -> UPIPayment {
        let items = QRText.queryItems(QRText.splitQuery(raw).query)
        return UPIPayment(
            payeeName: items["pn"] ?? "",
            payeeAddress: items["pa"] ?? "",
            amount: items["am"] ?? "",
            currency: items["cu"] ?? "",
            note: items["tn"] ?? ""
        )
    }

    // MARK: - crypto

    static func parseCrypto(_ raw: String, scheme: String, network: String) -> CryptoPayment {
        var body = QRText.dropPrefix(raw, scheme + ":")
        if body.hasPrefix("//") {
            body = String(body.dropFirst(2))
        }
        let parts = QRText.splitQuery(body)
        let items = QRText.queryItems(parts.query)
        return CryptoPayment(
            scheme: scheme,
            network: network,
            address: QRText.percentDecoded(parts.path),
            amount: items["amount"] ?? items["value"] ?? "",
            label: items["label"] ?? "",
            message: items["message"] ?? ""
        )
    }

    // MARK: - wifi

    static func parseWiFi(_ raw: String) -> WiFiNetwork {
        var network = WiFiNetwork(ssid: "", security: "", password: "", hidden: nil)
        for field in QRText.keyedFields(QRText.dropPrefix(raw, "wifi:")) {
            switch field.key {
            case "S": network.ssid = field.value
            case "T": network.security = QRText.trimmed(field.value)
            case "P": network.password = field.value
            case "H": network.hidden = QRText.trimmed(field.value).lowercased() == "true"
            default: break
            }
        }
        return network
    }

    // MARK: - contact

    static func parseMECARD(_ raw: String) -> ContactCard {
        var card = ContactCard(name: "", phones: [], emails: [], organisation: "", address: "", url: "")
        for field in QRText.keyedFields(QRText.dropPrefix(raw, "mecard:")) {
            let value = QRText.trimmed(field.value)
            if value.isEmpty { continue }
            switch field.key {
            case "N":
                if card.name.isEmpty {
                    // "Family,Given" → "Given Family"
                    let parts = value.components(separatedBy: ",")
                    card.name = QRText.joinNonEmpty(Array(parts.dropFirst()) + [parts[0]], separator: " ")
                }
            case "TEL", "TEL-AV": card.phones.append(value)
            case "EMAIL": card.emails.append(value)
            case "ORG": if card.organisation.isEmpty { card.organisation = value }
            case "ADR":
                if card.address.isEmpty {
                    card.address = QRText.joinNonEmpty(value.components(separatedBy: ","), separator: ", ")
                }
            case "URL": if card.url.isEmpty { card.url = value }
            default: break
            }
        }
        return card
    }

    /// Splits a content line into its property name (parameters and group
    /// prefix removed, upper-cased) and its value.
    private static func property(_ line: String) -> (name: String, value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        var name = String(line[..<colon])
        let value = String(line[line.index(after: colon)...])
        if let semicolon = name.firstIndex(of: ";") {
            name = String(name[..<semicolon])
        }
        if let dot = name.lastIndex(of: ".") {
            name = String(name[name.index(after: dot)...])
        }
        return (QRText.trimmed(name).uppercased(), value)
    }

    static func parseVCard(_ raw: String) -> ContactCard {
        var card = ContactCard(name: "", phones: [], emails: [], organisation: "", address: "", url: "")
        var formattedName = ""
        var structuredName = ""

        for line in QRText.unfoldedLines(raw) {
            guard let prop = property(line) else { continue }
            let value = QRText.trimmed(prop.value)
            if value.isEmpty { continue }
            switch prop.name {
            case "FN":
                if formattedName.isEmpty { formattedName = QRText.trimmed(QRText.unescaped(value)) }
            case "N":
                if structuredName.isEmpty {
                    // family;given;additional;prefix;suffix
                    let parts = QRText.splitEscaped(value, separator: ";")
                    func part(_ index: Int) -> String { return index < parts.count ? parts[index] : "" }
                    structuredName = QRText.joinNonEmpty([part(3), part(1), part(2), part(0), part(4)], separator: " ")
                }
            case "TEL":
                var number = QRText.unescaped(value)
                if QRText.hasPrefix(number, "tel:") { number = QRText.dropPrefix(number, "tel:") }
                card.phones.append(QRText.trimmed(number))
            case "EMAIL":
                card.emails.append(QRText.trimmed(QRText.unescaped(value)))
            case "ORG":
                if card.organisation.isEmpty {
                    card.organisation = QRText.joinNonEmpty(QRText.splitEscaped(value, separator: ";"), separator: ", ")
                }
            case "ADR":
                if card.address.isEmpty {
                    let parts = QRText.splitEscaped(value, separator: ";")
                        .map { $0.replacingOccurrences(of: "\n", with: ", ") }
                    card.address = QRText.joinNonEmpty(parts, separator: ", ")
                }
            case "URL":
                if card.url.isEmpty { card.url = QRText.trimmed(QRText.unescaped(value)) }
            default:
                break
            }
        }
        card.name = formattedName.isEmpty ? structuredName : formattedName
        return card
    }

    // MARK: - event

    static func parseEvent(_ raw: String) -> CalendarEvent {
        var event = CalendarEvent(title: "", start: "", end: "", location: "", details: "", startDate: nil, endDate: nil)
        let allLines = QRText.unfoldedLines(raw)

        // Only look inside the first VEVENT when there is one, so that a
        // VTIMEZONE block's DTSTART is not mistaken for the event's.
        var lines = allLines
        if let begin = allLines.firstIndex(where: { QRText.trimmed($0).uppercased() == "BEGIN:VEVENT" }) {
            let rest = allLines[(begin + 1)...]
            if let end = rest.firstIndex(where: { QRText.trimmed($0).uppercased() == "END:VEVENT" }) {
                lines = Array(allLines[(begin + 1)..<end])
            } else {
                lines = Array(rest)
            }
        }

        for line in lines {
            guard let prop = property(line) else { continue }
            let value = QRText.trimmed(prop.value)
            if value.isEmpty { continue }
            switch prop.name {
            case "SUMMARY": if event.title.isEmpty { event.title = QRText.unescaped(value) }
            case "DTSTART":
                if event.start.isEmpty {
                    event.start = formatDate(value)
                    event.startDate = parseEventDate(value)
                }
            case "DTEND":
                if event.end.isEmpty {
                    event.end = formatDate(value)
                    event.endDate = parseEventDate(value)
                }
            case "LOCATION": if event.location.isEmpty { event.location = QRText.unescaped(value) }
            case "DESCRIPTION": if event.details.isEmpty { event.details = QRText.unescaped(value) }
            default: break
            }
        }
        return event
    }

    /// `20261111T143000Z` → `2026-11-11 14:30 UTC`; `20261111` → `2026-11-11`.
    /// Anything else is returned unchanged.
    static func formatDate(_ value: String) -> String {
        let chars = Array(QRText.trimmed(value))
        guard chars.count >= 8, chars[0..<8].allSatisfy({ QRText.isASCIIDigit($0) }) else {
            return String(chars)
        }
        var text = String(chars[0..<4]) + "-" + String(chars[4..<6]) + "-" + String(chars[6..<8])
        if chars.count >= 13, chars[8] == "T" || chars[8] == "t",
           chars[9..<13].allSatisfy({ QRText.isASCIIDigit($0) }) {
            text += " " + String(chars[9..<11]) + ":" + String(chars[11..<13])
            if let last = chars.last, last == "Z" || last == "z" {
                text += " UTC"
            }
        }
        return text
    }

    /// `YYYYMMDD` (an all-day date) or `YYYYMMDDTHHMM[SS][Z]`. A time
    /// without `Z` is local time. Nil for anything else.
    static func parseEventDate(_ value: String) -> EventDate? {
        var chars = Array(QRText.trimmed(value))
        var timeZone = TimeZone.current
        if chars.count > 8, let last = chars.last, last == "Z" || last == "z" {
            guard let utc = TimeZone(secondsFromGMT: 0) else { return nil }
            timeZone = utc
            chars.removeLast()
        }
        func number(_ range: Range<Int>) -> Int? {
            guard chars[range].allSatisfy({ QRText.isASCIIDigit($0) }) else { return nil }
            return Int(String(chars[range]))
        }
        guard chars.count == 8 || chars.count == 13 || chars.count == 15,
              let year = number(0..<4), let month = number(4..<6), let day = number(6..<8) else {
            return nil
        }
        var parts = DateComponents(year: year, month: month, day: day, hour: 0, minute: 0, second: 0)
        let isAllDay = chars.count == 8
        if !isAllDay {
            guard chars[8] == "T" || chars[8] == "t", let hour = number(9..<11), let minute = number(11..<13) else {
                return nil
            }
            parts.hour = hour
            parts.minute = minute
            if chars.count == 15 {
                guard let second = number(13..<15) else { return nil }
                parts.second = second
            }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        // Rejects dates that do not exist, such as month 13 or 30 February.
        guard parts.isValidDate(in: calendar), let date = calendar.date(from: parts) else { return nil }
        return EventDate(date: date, isAllDay: isAllDay)
    }

    // MARK: - email

    static func parseMailto(_ raw: String) -> EmailMessage {
        let parts = QRText.splitQuery(QRText.dropPrefix(raw, "mailto:"))
        let items = QRText.queryItems(parts.query)
        let recipients = [QRText.percentDecoded(parts.path), items["to"] ?? ""]
        return EmailMessage(
            to: QRText.joinNonEmpty(recipients, separator: ", "),
            subject: items["subject"] ?? "",
            body: items["body"] ?? ""
        )
    }

    static func parseMATMSG(_ raw: String) -> EmailMessage {
        var message = EmailMessage(to: "", subject: "", body: "")
        for field in QRText.keyedFields(QRText.dropPrefix(raw, "matmsg:")) {
            switch field.key {
            case "TO": message.to = QRText.trimmed(field.value)
            case "SUB": message.subject = field.value
            case "BODY": message.body = field.value
            default: break
            }
        }
        return message
    }

    // MARK: - sms

    /// `body` is the text after `sms:` / `smsto:`.
    /// Accepts `number`, `number:message` and `number?body=message`.
    static func parseSMS(_ body: String) -> SMSMessage {
        var rest = body
        if rest.hasPrefix("//") {
            rest = String(rest.dropFirst(2))
        }
        if rest.contains("?") {
            let parts = QRText.splitQuery(rest)
            let items = QRText.queryItems(parts.query)
            return SMSMessage(
                number: QRText.trimmed(QRText.percentDecoded(parts.path)),
                message: items["body"] ?? ""
            )
        }
        if let colon = rest.firstIndex(of: ":") {
            return SMSMessage(
                number: QRText.trimmed(QRText.percentDecoded(String(rest[..<colon]))),
                message: String(rest[rest.index(after: colon)...])
            )
        }
        return SMSMessage(number: QRText.trimmed(QRText.percentDecoded(rest)), message: "")
    }

    // MARK: - geo

    static func parseGeo(_ raw: String) -> GeoLocation {
        let parts = QRText.splitQuery(QRText.dropPrefix(raw, "geo:"))
        let items = QRText.queryItems(parts.query)
        // Drop `;crs=…;u=…` parameters, keep `lat,lon[,alt]`.
        let coordinates = parts.path.components(separatedBy: ";")[0].components(separatedBy: ",")
        return GeoLocation(
            latitude: coordinates.count > 0 ? QRText.trimmed(coordinates[0]) : "",
            longitude: coordinates.count > 1 ? QRText.trimmed(coordinates[1]) : "",
            label: items["q"] ?? ""
        )
    }

    // MARK: - otp

    /// The `secret` parameter is deliberately not read.
    static func parseOTP(_ raw: String) -> OTPAuth {
        let parts = QRText.splitQuery(QRText.dropPrefix(raw, "otpauth://"))
        let items = QRText.queryItems(parts.query)

        var type = parts.path
        var label = ""
        if let slash = parts.path.firstIndex(of: "/") {
            type = String(parts.path[..<slash])
            label = QRText.percentDecoded(String(parts.path[parts.path.index(after: slash)...]))
        }

        var issuer = ""
        var account = label
        if let colon = label.firstIndex(of: ":") {
            issuer = String(label[..<colon])
            account = String(label[label.index(after: colon)...])
        }
        if let named = items["issuer"], !named.isEmpty {
            issuer = named
        }
        return OTPAuth(
            issuer: QRText.trimmed(issuer),
            account: QRText.trimmed(account),
            type: QRText.trimmed(type).uppercased()
        )
    }

    // MARK: - esim

    /// `LPA:1$<address>$<activation code>[$…]`.
    static func parseESIM(_ raw: String) -> ESIMProfile {
        let parts = raw.components(separatedBy: "$")
        var code = parts.count > 2 ? QRText.trimmed(parts[2]) : ""
        // A past scan: the activation code was not kept.
        if code == QRRedaction.ellipsis {
            code = ""
        }
        return ESIMProfile(address: parts.count > 1 ? QRText.trimmed(parts[1]) : "", activationCode: code)
    }

    // MARK: - device, healthcert

    /// Length of the prefix that names a device setup code or a health
    /// certificate; 0 for anything else.
    static func codePrefixLength(_ raw: String) -> Int {
        for prefix in devicePrefixes.map({ $0.prefix }) + healthCertificatePrefixes where QRText.hasPrefix(raw, prefix) {
            return prefix.count
        }
        return 0
    }

    // MARK: - applink

    /// The lower-cased scheme if the text starts with `^[a-z][a-z0-9+.-]{1,31}:`
    /// (case-insensitive). http and https never count as app links.
    static func appLinkScheme(_ raw: String) -> String? {
        guard let colon = raw.firstIndex(of: ":") else { return nil }
        let scheme = raw[..<colon].lowercased()
        guard scheme.count >= 2, scheme.count <= 32 else { return nil }
        guard let first = scheme.first, first >= "a", first <= "z" else { return nil }
        let rest = scheme.dropFirst()
        let valid = rest.allSatisfy { ch in
            return (ch >= "a" && ch <= "z") || QRText.isASCIIDigit(ch) || ch == "+" || ch == "." || ch == "-"
        }
        guard valid, scheme != "http", scheme != "https" else { return nil }
        return scheme
    }
}
