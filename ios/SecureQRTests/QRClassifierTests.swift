import Contacts
import XCTest
@testable import SecureQR

/// Covers every shared vector in docs/qr-types.md, plus parser edge cases.
final class QRClassifierTests: XCTestCase {

    // MARK: - Shared vectors

    func testPayLinkInvoice() {
        let text = "https://payconiq.com/t/1/5f2a9c0e1b?D=Invoice%2042&A=1250&R=INV42"
        let payload = QRClassifier.classify(text)
        XCTAssertEqual(payload.type, .paylink)
        XCTAssertEqual(payload.content, .paylink(PayLink(
            provider: "Bancontact (Payconiq)", amount: "12.50 EUR", description: "Invoice 42", reference: "INV42"
        )))
        XCTAssertEqual(payload.providerTitle, "Bancontact (Payconiq)")
        XCTAssertEqual(payload.fields, [
            QRField(label: .amount, value: .text("12.50 EUR")),
            QRField(label: .details, value: .text("Invoice 42")),
            QRField(label: .reference, value: .mono("INV42"))
        ])
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.paymentRequestInApp]))
        XCTAssertEqual(payload.actions, [.openInPaymentApp, .copy])
        // What is handed to the system is the scanned text, unchanged.
        XCTAssertEqual(payload.raw, text)
        XCTAssertEqual(payload.copyText, text)
        // Not a link for the server.
        XCTAssertNil(payload.host)
        XCTAssertNil(payload.instruction)
    }

    func testPayLinkStickerUppercase() {
        let text = "HTTPS://PAYCONIQ.COM/L/1/5F2A9C0E1B/POS01"
        let payload = QRClassifier.classify(text)
        XCTAssertEqual(payload.type, .paylink)
        XCTAssertEqual(payload.content, .paylink(PayLink(
            provider: "Bancontact (Payconiq)", amount: "", description: "", reference: ""
        )))
        XCTAssertEqual(payload.fields, [])
        XCTAssertEqual(payload.raw, text)
    }

    func testPayLinkLookAlikeHostIsAnOrdinaryLink() {
        let payload = QRClassifier.classify("https://payconiq.com.evil.example/t/1/x")
        XCTAssertEqual(payload.type, .url)
        XCTAssertEqual(payload.host, "payconiq.com.evil.example")
    }

    func testPayLinkHostMatching() {
        XCTAssertEqual(QRClassifier.classify("https://www.payconiq.com/t/1/x").type, .paylink)
        XCTAssertEqual(QRClassifier.classify("http://Portal.Payconiq.COM/l/1/a/b").type, .paylink)
        XCTAssertEqual(QRClassifier.classify("https://a.b.payconiq.com:443/t/1/x?A=5").type, .paylink)
        XCTAssertEqual(QRClassifier.classify("https://payconiq.com./t/1/x").type, .paylink)

        let lookAlikes = [
            "https://payconiq.com.evil.example/t/1/x",
            "https://evilpayconiq.com/t/1/x",
            "https://payconiq.com-pay.example/t/1/x",
            "https://payconiq.co/t/1/x",
            "https://example.com/payconiq.com/t/1/x",
            "https://example.com/?next=https://payconiq.com/t/1/x",
            "https://payconiq.com@evil.example/t/1/x",
            "https://evil.example#payconiq.com"
        ]
        for text in lookAlikes {
            XCTAssertEqual(QRClassifier.classify(text).type, .url, text)
        }

        XCTAssertEqual(PaymentApps.provider(forHost: "PAYCONIQ.COM"), "Bancontact (Payconiq)")
        XCTAssertEqual(PaymentApps.provider(forHost: "app.payconiq.com"), "Bancontact (Payconiq)")
        XCTAssertNil(PaymentApps.provider(forHost: "payconiq.com.evil.example"))
        XCTAssertNil(PaymentApps.provider(forHost: "notpayconiq.com"))
        XCTAssertNil(PaymentApps.provider(forHost: ""))
    }

    func testPayLinkAmounts() {
        XCTAssertEqual(PaymentApps.euros(fromCents: "1250"), "12.50 EUR")
        XCTAssertEqual(PaymentApps.euros(fromCents: "5"), "0.05 EUR")
        XCTAssertEqual(PaymentApps.euros(fromCents: "100"), "1.00 EUR")
        XCTAssertEqual(PaymentApps.euros(fromCents: "0"), "0.00 EUR")
        XCTAssertEqual(PaymentApps.euros(fromCents: ""), "")
        XCTAssertEqual(PaymentApps.euros(fromCents: "12.50"), "")
        XCTAssertEqual(PaymentApps.euros(fromCents: "-5"), "")
        XCTAssertEqual(PaymentApps.euros(fromCents: "abc"), "")
    }

    func testHTTPSURL() {
        let payload = QRClassifier.classify("https://example.com/a")
        XCTAssertEqual(payload.type, .url)
        XCTAssertEqual(payload.host, "example.com")
    }

    func testUppercaseHTTPURL() {
        let payload = QRClassifier.classify("HTTP://EXAMPLE.COM")
        XCTAssertEqual(payload.type, .url)
        XCTAssertEqual(payload.raw, "HTTP://EXAMPLE.COM")
    }

    func testEPCValid() {
        let payload = QRClassifier.classify("BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00\n\n\nGift\n")
        XCTAssertEqual(payload.type, .epc)
        guard case .epc(let payment) = payload.content else {
            return XCTFail("expected epc")
        }
        XCTAssertEqual(payment.name, "Rode Kruis")
        XCTAssertEqual(payment.amount, "25.00")
        XCTAssertEqual(payment.currency, "EUR")
        XCTAssertEqual(payment.displayAmount, "25.00 EUR")
        XCTAssertEqual(payment.bic, "GKCCBEBB")
        XCTAssertEqual(payment.iban, "BE72000000001616")
        XCTAssertEqual(payment.groupedIBAN, "BE72 0000 0000 1616")
        XCTAssertEqual(payment.message, "Gift")
        XCTAssertEqual(payment.reference, "")
        XCTAssertTrue(payment.isIBANValid)
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.paymentRequest]))
        XCTAssertEqual(payload.instruction, .scanWithBankingApp)
        XCTAssertEqual(payload.actions, [.copyIBAN, .copyAll])
    }

    func testEPCInvalidIBAN() {
        let payload = QRClassifier.classify("BCD\n002\n1\nSCT\n\nX\nBE72000000001617\nEUR1\n")
        XCTAssertEqual(payload.type, .epc)
        guard case .epc(let payment) = payload.content else {
            return XCTFail("expected epc")
        }
        XCTAssertEqual(payment.name, "X")
        XCTAssertEqual(payment.amount, "1")
        XCTAssertEqual(payment.currency, "EUR")
        XCTAssertFalse(payment.isIBANValid)
        XCTAssertEqual(payload.notice.level, .danger)
        XCTAssertEqual(payload.notice.messages.first, .invalidIBAN)
        XCTAssertEqual(payload.actions, [.copyIBAN, .copyAll])
    }

    func testEMV() {
        let payload = QRClassifier.classify("00020101021129370016A000000677010111011300660000000005802TH530376454031005913Test Merchant6007Bangkok6304ABCD")
        XCTAssertEqual(payload.type, .emv)
        guard case .emv(let payment) = payload.content else {
            return XCTFail("expected emv")
        }
        XCTAssertEqual(payment.merchant, "Test Merchant")
        XCTAssertEqual(payment.city, "Bangkok")
        XCTAssertEqual(payment.country, "TH")
        XCTAssertEqual(payment.amount, "100")
        XCTAssertEqual(payment.currency, "THB")
        XCTAssertEqual(payment.currencyCode, "764")
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.paymentRequest]))
    }

    func testUPI() {
        let payload = QRClassifier.classify("upi://pay?pa=shop@bank&pn=Corner%20Shop&am=120.50&cu=INR")
        XCTAssertEqual(payload.type, .upi)
        guard case .upi(let payment) = payload.content else {
            return XCTFail("expected upi")
        }
        XCTAssertEqual(payment.payeeName, "Corner Shop")
        XCTAssertEqual(payment.payeeAddress, "shop@bank")
        XCTAssertEqual(payment.amount, "120.50")
        XCTAssertEqual(payment.currency, "INR")
        XCTAssertEqual(payload.notice.level, .caution)
        XCTAssertEqual(payload.actions, [.openInApp, .copy])
    }

    func testBitcoin() {
        let payload = QRClassifier.classify("bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01")
        XCTAssertEqual(payload.type, .crypto)
        guard case .crypto(let payment) = payload.content else {
            return XCTFail("expected crypto")
        }
        XCTAssertEqual(payment.network, "Bitcoin")
        XCTAssertEqual(payment.address, "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
        XCTAssertEqual(payment.amount, "0.01")
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.paymentRequest, .cryptoIrreversible]))
        XCTAssertEqual(payload.actions, [.openInApp, .copyAddress])
    }

    func testWiFiEscapes() {
        let payload = QRClassifier.classify("WIFI:T:WPA;S:Cafe\\;Bar;P:p\\:ss;;")
        XCTAssertEqual(payload.type, .wifi)
        guard case .wifi(let network) = payload.content else {
            return XCTFail("expected wifi")
        }
        XCTAssertEqual(network.ssid, "Cafe;Bar")
        XCTAssertEqual(network.password, "p:ss")
        XCTAssertEqual(network.security, "WPA")
        XCTAssertNil(network.hidden)
        XCTAssertEqual(payload.notice.level, .neutral)
        XCTAssertEqual(payload.actions, [.joinWiFi, .copyPassword])
    }

    func testWiFiOpenNetwork() {
        let payload = QRClassifier.classify("WIFI:T:nopass;S:Open;;")
        XCTAssertEqual(payload.type, .wifi)
        guard case .wifi(let network) = payload.content else {
            return XCTFail("expected wifi")
        }
        XCTAssertEqual(network.ssid, "Open")
        XCTAssertTrue(network.isOpen)
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.openNetwork]))
        XCTAssertEqual(payload.actions, [.joinWiFi])
    }

    func testMECARD() {
        let payload = QRClassifier.classify("MECARD:N:Doe,John;TEL:+3212345678;;")
        XCTAssertEqual(payload.type, .contact)
        guard case .contact(let card) = payload.content else {
            return XCTFail("expected contact")
        }
        XCTAssertEqual(card.name, "John Doe")
        XCTAssertEqual(card.phones, ["+3212345678"])
        XCTAssertEqual(payload.notice, QRNotice(level: .neutral, messages: [.readOnDevice]))
        XCTAssertEqual(payload.actions, [.addToContacts, .copyAll])
    }

    func testEventWithStartCanBeAdded() {
        let payload = QRClassifier.classify("BEGIN:VEVENT\nSUMMARY:Team lunch\nDTSTART:20261203T120000Z\nDTEND:20261203T130000Z\nLOCATION:Canteen\nEND:VEVENT")
        XCTAssertEqual(payload.type, .event)
        XCTAssertEqual(payload.actions, [.addToCalendar, .copyAll])
        guard case .event(let event) = payload.content, let schedule = event.schedule else {
            return XCTFail("expected an event with a start date")
        }
        XCTAssertEqual(event.title, "Team lunch")
        XCTAssertEqual(event.location, "Canteen")
        // 2026-12-03 12:00:00 UTC
        XCTAssertEqual(schedule.start, Date(timeIntervalSince1970: 1_796_299_200))
        XCTAssertEqual(schedule.end, Date(timeIntervalSince1970: 1_796_302_800))
        XCTAssertFalse(schedule.isAllDay)
    }

    func testEventWithoutStartCannotBeAdded() {
        let payload = QRClassifier.classify("BEGIN:VEVENT\nSUMMARY:No date\nEND:VEVENT")
        XCTAssertEqual(payload.type, .event)
        XCTAssertEqual(payload.actions, [.copyAll])
    }

    func testTel() {
        let payload = QRClassifier.classify("tel:+3212345678")
        XCTAssertEqual(payload.type, .phone)
        XCTAssertEqual(payload.content, .phone("+3212345678"))
        XCTAssertEqual(payload.notice, QRNotice(level: .neutral, messages: [.readOnDevice]))
        XCTAssertEqual(payload.actions, [.openInApp, .copy])
    }

    func testTelServiceCode() {
        let payload = QRClassifier.classify("tel:*21*0032475000000%23")
        XCTAssertEqual(payload.type, .phone)
        XCTAssertEqual(payload.content, .phone("*21*0032475000000#"))
        XCTAssertEqual(payload.notice, QRNotice(level: .danger, messages: [.serviceCode]))
        XCTAssertEqual(payload.actions, [.copy])
    }

    func testTelPremiumNumbers() {
        for text in ["tel:090312345", "tel:+32 903 12 345"] {
            let payload = QRClassifier.classify(text)
            XCTAssertEqual(payload.type, .phone, text)
            XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.premiumNumber]), text)
            XCTAssertEqual(payload.actions, [.openInApp, .copy], text)
        }
        let premium = ["0032 (903) 12.345", "+31900123456", "+49900123", "+449012345678", "0900123", "0901-123", "0908123", "19005551234", "+1 900 555 1234", "900-555-1234"]
        for number in premium {
            XCTAssertTrue(PhoneNumber.isPremiumRate(number), number)
        }
        let ordinary = ["+3212345678", "012345678", "+32475000000", "+15551234567", "9005551", "*900#"]
        for number in ordinary {
            XCTAssertFalse(PhoneNumber.isPremiumRate(number), number)
        }
    }

    func testLoginCodes() {
        let samples: [(String, String, String)] = [
            ("https://discord.com/ra/AbCdEf123456", "Discord", "https://discord.com/…"),
            ("https://s.team/q/1/1234567890", "Steam", "https://s.team/…"),
            ("tg://login?token=abc", "Telegram", "tg://…"),
            ("2@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl,MnOpQrStUvWxYzAb,CdEfGhIjKlMnOpQr", "WhatsApp", "…")
        ]
        for (text, service, redacted) in samples {
            let payload = QRClassifier.classify(text)
            XCTAssertEqual(payload.type, .login, text)
            XCTAssertEqual(payload.content, .login(service: service), text)
            XCTAssertEqual(payload.fields, [QRField(label: .service, value: .text(service))], text)
            XCTAssertEqual(payload.notice, QRNotice(level: .danger, messages: [.signsInOtherDevice]), text)
            XCTAssertEqual(payload.actions, [], text)
            // Never a link for the server, never kept in full.
            XCTAssertNil(payload.host, text)
            XCTAssertTrue(payload.containsSecret, text)
            XCTAssertEqual(payload.redactedRaw, redacted, text)
            XCTAssertEqual(payload.summary, service, text)
        }
    }

    func testLoginVariants() {
        let samples: [(String, String)] = [
            ("HTTPS://DISCORD.COM/RA/AbC", "Discord"),
            ("https://ptb.discordapp.com/ra/abc", "Discord"),
            ("http://s.team/q/1/2", "Steam"),
            ("https://login.weixin.qq.com/l/abcdef", "WeChat"),
            ("TG://LOGIN?token=abc", "Telegram"),
            ("sgnl://linkdevice?uuid=abc&pub_key=def", "Signal"),
            ("tsdevice:/?uuid=abc&pub_key=def", "Signal"),
            ("1@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl,MnOpQrStUvWxYzAb", "WhatsApp")
        ]
        for (text, service) in samples {
            XCTAssertEqual(QRClassifier.classify(text).content, .login(service: service), text)
        }
        XCTAssertEqual(QRClassifier.classify("https://discord.com/invite/abc").type, .url)
        XCTAssertEqual(QRClassifier.classify("https://discord.com.evil.example/ra/abc").type, .url)
        XCTAssertEqual(QRClassifier.classify("https://example.com/ra/abc").type, .url)
        XCTAssertEqual(QRClassifier.classify("https://s.team/p/abc").type, .url)
        XCTAssertEqual(QRClassifier.classify("tg://loginx?token=abc").type, .applink)
        XCTAssertEqual(QRClassifier.classify("3@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl,MnOpQrStUvWxYzAb").type, .text)
        XCTAssertEqual(QRClassifier.classify("2@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl").type, .text)
    }

    func testChatWhatsApp() {
        let text = "https://wa.me/3212345678?text=Hi%20there"
        let payload = QRClassifier.classify(text)
        XCTAssertEqual(payload.type, .chat)
        XCTAssertEqual(payload.content, .chat(ChatLink(
            service: "WhatsApp", number: "+3212345678", handle: "", isInvite: false, message: "Hi there"
        )))
        XCTAssertEqual(payload.fields, [
            QRField(label: .service, value: .text("WhatsApp")),
            QRField(label: .number, value: .mono("+3212345678")),
            QRField(label: .message, value: .text("Hi there"))
        ])
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.chatWithStranger]))
        XCTAssertEqual(payload.actions, [.openInApp, .copy])
        // Replayed unchanged, and not a link for the server.
        XCTAssertEqual(payload.raw, text)
        XCTAssertEqual(payload.copyText, text)
        XCTAssertNil(payload.host)
        XCTAssertFalse(payload.containsSecret)
    }

    func testChatTelegram() {
        let web = QRClassifier.classify("https://t.me/some_shop")
        XCTAssertEqual(web.type, .chat)
        XCTAssertEqual(web.content, .chat(ChatLink(
            service: "Telegram", number: "", handle: "@some_shop", isInvite: false, message: ""
        )))
        let app = QRClassifier.classify("tg://resolve?domain=some_shop")
        XCTAssertEqual(app.type, .chat)
        XCTAssertEqual(app.content, web.content)
        XCTAssertEqual(app.fields, [
            QRField(label: .service, value: .text("Telegram")),
            QRField(label: .handle, value: .mono("@some_shop"))
        ])
    }

    func testChatVariants() {
        func chat(_ text: String) -> ChatLink? {
            if case .chat(let link) = QRClassifier.classify(text).content { return link }
            XCTFail("expected a chat link: \(text)")
            return nil
        }
        XCTAssertEqual(chat("https://api.whatsapp.com/send?phone=%2B32%2012%20345678&text=Hi")?.number, "+3212345678")
        XCTAssertEqual(chat("whatsapp://send?phone=3212345678")?.number, "+3212345678")
        XCTAssertEqual(chat("https://wa.me/qr/ABCDEF")?.number, "")
        XCTAssertEqual(chat("https://telegram.me/some_shop")?.handle, "@some_shop")
        for invite in ["https://t.me/+AbCdEf123", "https://t.me/joinchat/AbCdEf123"] {
            let payload = QRClassifier.classify(invite)
            XCTAssertEqual(payload.fields, [
                QRField(label: .service, value: .text("Telegram")),
                QRField(label: .handle, value: .inviteLink)
            ], invite)
        }
        XCTAssertEqual(chat("https://m.me/some.page"), ChatLink(
            service: "Messenger", number: "", handle: "some.page", isInvite: false, message: ""
        ))
        // Neither number nor handle: still the card.
        XCTAssertEqual(chat("https://signal.me/#p/+3212345678"), ChatLink(
            service: "Signal", number: "", handle: "", isInvite: false, message: ""
        ))
        XCTAssertEqual(chat("viber://chat?number=%2B3212345678")?.number, "+3212345678")
        XCTAssertEqual(chat("viber://add?number=3212345678")?.service, "Viber")

        XCTAssertEqual(QRClassifier.classify("https://api.whatsapp.com/other").type, .url)
        XCTAssertEqual(QRClassifier.classify("https://wa.me.evil.example/32123").type, .url)
        XCTAssertEqual(QRClassifier.classify("https://example.com/?next=https://wa.me/32123").type, .url)
        XCTAssertEqual(QRClassifier.classify("viber://pa?chatURI=x").type, .applink)
        XCTAssertEqual(QRClassifier.classify("tg://join?invite=x").type, .applink)
    }

    func testSwissQRBill() {
        let payload = QRClassifier.classify("SPC\n0200\n1\nCH4431999123000889012\nS\nRobert Schneider AG\nRue du Lac\n1268\n2501\nBiel\nCH\n\n\n\n\n\n\n\n1949.75\nCHF\n\n\n\n\n\n\n\nQRR\n210000000003139471430009017\nOrder 42\nEPD")
        XCTAssertEqual(payload.type, .swissqr)
        guard case .swissqr(let payment) = payload.content else {
            return XCTFail("expected swissqr")
        }
        XCTAssertEqual(payment.name, "Robert Schneider AG")
        XCTAssertEqual(payment.displayAmount, "1949.75 CHF")
        XCTAssertEqual(payment.iban, "CH4431999123000889012")
        XCTAssertTrue(payment.isIBANValid)
        XCTAssertEqual(payment.reference, "210000000003139471430009017")
        XCTAssertEqual(payment.message, "Order 42")
        XCTAssertEqual(payload.fields, [
            QRField(label: .beneficiary, value: .text("Robert Schneider AG")),
            QRField(label: .iban, value: .mono("CH44 3199 9123 0008 8901 2")),
            QRField(label: .amount, value: .text("1949.75 CHF")),
            QRField(label: .reference, value: .mono("210000000003139471430009017")),
            QRField(label: .message, value: .text("Order 42"))
        ])
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.paymentRequest]))
        XCTAssertEqual(payload.instruction, .scanWithBankingApp)
        XCTAssertEqual(payload.actions, [.copyIBAN, .copyAll])
        XCTAssertEqual(payload.bankTransfer?.iban, "CH4431999123000889012")

        let invalid = QRClassifier.classify("SPC\r\n0200\r\n1\r\nCH4431999123000889013\r\nS\r\nX")
        XCTAssertEqual(invalid.type, .swissqr)
        XCTAssertEqual(invalid.notice, QRNotice(level: .danger, messages: [.invalidIBAN, .paymentRequest]))
    }

    func testSPD() {
        let payload = QRClassifier.classify("SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK*MSG:Platba%20za%20zbozi*RN:Jan Novak*X-VS:1234567890")
        XCTAssertEqual(payload.type, .spd)
        guard case .spd(let payment) = payload.content else {
            return XCTFail("expected spd")
        }
        XCTAssertEqual(payment.name, "Jan Novak")
        XCTAssertEqual(payment.displayAmount, "480.50 CZK")
        XCTAssertEqual(payment.iban, "CZ5855000000001265098001")
        XCTAssertTrue(payment.isIBANValid)
        XCTAssertEqual(payment.message, "Platba za zbozi")
        XCTAssertEqual(payment.reference, "1234567890")
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.paymentRequest]))
        XCTAssertEqual(payload.instruction, .scanWithBankingApp)
        XCTAssertEqual(payload.actions, [.copyIBAN, .copyAll])

        // IBAN+BIC, lower-case prefix, invalid IBAN.
        guard case .spd(let withBIC) = QRClassifier.classify("spd*1.0*ACC:CZ5855000000001265098001+RZBCCZPP*AM:1").content else {
            return XCTFail("expected spd")
        }
        XCTAssertEqual(withBIC.iban, "CZ5855000000001265098001")
        XCTAssertEqual(QRClassifier.classify("SPD*1.0*ACC:CZ5855000000001265098002").notice.level, .danger)
    }

    func testPix() {
        let payload = QRClassifier.classify("00020126360014br.gov.bcb.pix0114+5561999999999520400005303986540510.005802BR5908Loja Sul6008Brasilia6304ABCD")
        XCTAssertEqual(payload.type, .emv)
        guard case .emv(let payment) = payload.content else {
            return XCTFail("expected emv")
        }
        XCTAssertEqual(payment.provider, "Pix")
        XCTAssertEqual(payment.payeeAddress, "+5561999999999")
        XCTAssertEqual(payment.merchant, "Loja Sul")
        XCTAssertEqual(payment.amount, "10.00")
        XCTAssertEqual(payment.currency, "BRL")
        XCTAssertEqual(payload.fields, [
            QRField(label: .provider, value: .text("Pix")),
            QRField(label: .merchant, value: .text("Loja Sul")),
            QRField(label: .city, value: .text("Brasilia")),
            QRField(label: .country, value: .text("BR")),
            QRField(label: .amount, value: .text("10.00")),
            QRField(label: .currency, value: .text("BRL")),
            QRField(label: .payeeAddress, value: .mono("+5561999999999"))
        ])
        XCTAssertEqual(payload.actions, [.copyAll])

        // The payment link (sub-tag 25) when there is no key; upper-case scheme name.
        guard case .emv(let dynamic) = QRClassifier.classify("00020126390014BR.GOV.BCB.PIX2517pix.example/qr/ab5802BR").content else {
            return XCTFail("expected emv")
        }
        XCTAssertEqual(dynamic.provider, "Pix")
        XCTAssertEqual(dynamic.payeeAddress, "pix.example/qr/ab")
    }

    func testOTPExport() {
        let payload = QRClassifier.classify("otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU")
        XCTAssertEqual(payload.type, .otpexport)
        XCTAssertEqual(payload.content, .otpexport)
        XCTAssertEqual(payload.fields, [])
        XCTAssertEqual(payload.notice, QRNotice(level: .danger, messages: [.authenticatorExport]))
        XCTAssertEqual(payload.actions, [])
        XCTAssertTrue(payload.containsSecret)
        XCTAssertEqual(payload.redactedRaw, "otpauth-migration://…")
        XCTAssertEqual(payload.summary, "")
    }

    func testESIM() {
        let payload = QRClassifier.classify("LPA:1$smdp.example.com$ABCD-1234-EFGH")
        XCTAssertEqual(payload.type, .esim)
        XCTAssertEqual(payload.content, .esim(ESIMProfile(address: "smdp.example.com", activationCode: "ABCD-1234-EFGH")))
        XCTAssertEqual(payload.fields, [
            QRField(label: .address, value: .mono("smdp.example.com")),
            QRField(label: .activationCode, value: .secret("ABCD-1234-EFGH"))
        ])
        XCTAssertEqual(payload.instruction, .installESIM)
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.mobilePlan]))
        XCTAssertEqual(payload.actions, [.copy])
        XCTAssertTrue(payload.containsSecret)
        XCTAssertEqual(payload.redactedRaw, "LPA:1$smdp.example.com$…")
        XCTAssertEqual(QRClassifier.classify("LPA:1$smdp.example.com$ABCD-1234-EFGH$1.2.3$1").redactedRaw, "LPA:1$smdp.example.com$…")

        // A past scan: the address is still there, the code is not.
        let stored = QRClassifier.classify(payload.redactedRaw)
        XCTAssertEqual(stored.content, .esim(ESIMProfile(address: "smdp.example.com", activationCode: "")))
        XCTAssertEqual(stored.fields, [QRField(label: .address, value: .mono("smdp.example.com"))])
    }

    func testDeviceSetupCodes() {
        let samples: [(String, String, String)] = [
            ("MT:Y.K9042C00KA0648G00", "Matter", "MT:…"),
            ("X-HM://0023ISYWYABCD", "HomeKit", "X-HM://…"),
            ("DPP:C:81/1;M:aa:bb:cc:dd:ee:ff;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgAC;;", "Wi-Fi Easy Connect", "DPP:…")
        ]
        for (text, kind, redacted) in samples {
            let payload = QRClassifier.classify(text)
            XCTAssertEqual(payload.type, .device, text)
            XCTAssertEqual(payload.content, .device(kind: kind), text)
            XCTAssertEqual(payload.fields, [QRField(label: .type, value: .text(kind))], text)
            XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.deviceSetupCode]), text)
            XCTAssertEqual(payload.actions, [], text)
            XCTAssertEqual(payload.redactedRaw, redacted, text)
            XCTAssertEqual(QRClassifier.classify(redacted).content, .device(kind: kind), text)
        }
    }

    func testHealthCertificates() {
        let certificate = "HC1:6BF+70790T9WJWG.FKY*4GO0.O1CV2 O5 N2FBBRW1*70HS8WY04AC*WIFN0AHCD8KD97TK0F90KECTHGWJC0FDC:5AIA%G7X+AQB9746HS80:54IBQF60R6$A80X6S1BTYACG6M+9XG8KIAWNA91AY%67092L4WJCT3EHS8XJC$+DXJCCWENF6OF63W5NW6WF6%JC QE/IAYJC5LEW34U3ET7DXC9 QE-ED8%E.JCBECB1A-:8$96646AL60A60S6Q$D.UDRYA 96NF6L/5QW6307KQEPD09WEQDD+Q6TW6FA7C466KCN9E%961A6DL6FA7D46JPCT3E5JDLA7$Q6E464W5TG6..DX%DZJC6/DTZ9 QE5$CB$DA/D JC1/D3Z8WED1ECW.CCWE.Y92OAGY8MY9L+9MPCG/D5 C5IA5N9$PC5$CUZCY$5Y$527B+A4KZNQG5TKOWWD9FL%I8U$F7O2IBM85CWOC%LEZU4R/BXHDAHN 11$CA5MRI:AONFN7091K9FKIGIY%VWSSSU9%01FO2*FTPQ3C3F"
        let payload = QRClassifier.classify(certificate)
        XCTAssertEqual(payload.type, .healthcert)
        XCTAssertEqual(payload.fields, [])
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.healthCertificate]))
        XCTAssertEqual(payload.actions, [])
        XCTAssertTrue(payload.containsSecret)
        XCTAssertEqual(payload.redactedRaw, "HC1:…")
        XCTAssertEqual(payload.summary, "")

        let smart = QRClassifier.classify("shc:/5676290952432060346029243740446031222959532654603460292540772804336028")
        XCTAssertEqual(smart.type, .healthcert)
        XCTAssertEqual(smart.redactedRaw, "shc:/…")
        XCTAssertEqual(QRClassifier.classify(smart.redactedRaw).type, .healthcert)
    }

    func testUnsafeLinks() {
        let script = QRClassifier.classify("javascript:alert(1)")
        XCTAssertEqual(script.type, .unsafe)
        XCTAssertEqual(script.content, .unsafe(scheme: "javascript"))
        XCTAssertEqual(script.fields, [
            QRField(label: .scheme, value: .mono("javascript")),
            QRField(label: .content, value: .mono("javascript:alert(1)"))
        ])
        XCTAssertEqual(script.notice, QRNotice(level: .danger, messages: [.unsafeLink]))
        XCTAssertEqual(script.actions, [.copy])

        let intent = QRClassifier.classify("intent://scan/#Intent;scheme=zxing;end")
        XCTAssertEqual(intent.type, .unsafe)
        XCTAssertEqual(intent.content, .unsafe(scheme: "intent"))
        XCTAssertEqual(intent.actions, [.copy])

        for scheme in QRClassifier.unsafeSchemes {
            XCTAssertEqual(QRClassifier.classify(scheme.uppercased() + ":x").content, .unsafe(scheme: scheme), scheme)
        }
        XCTAssertEqual(QRClassifier.classify("datax:1").type, .applink)
    }

    /// Only an ordinary link may go to the preview server.
    func testOnlyLinksHaveAHost() {
        let notForTheServer = [
            "https://discord.com/ra/AbCdEf123456", "https://s.team/q/1/1234567890",
            "https://login.weixin.qq.com/l/abc", "https://wa.me/3212345678", "https://api.whatsapp.com/send?phone=32",
            "https://t.me/some_shop", "https://telegram.me/x", "https://m.me/x", "https://signal.me/#p/+32",
            "https://payconiq.com/t/1/x"
        ]
        for text in notForTheServer {
            let payload = QRClassifier.classify(text)
            XCTAssertNil(payload.host, text)
            if case .url = payload.content {
                XCTFail("must not be a link for the server: \(text)")
            }
        }
    }

    func testSMSShortCode() {
        let payload = QRClassifier.classify("smsto:3333:WIN")
        XCTAssertEqual(payload.type, .sms)
        guard case .sms(let message) = payload.content else {
            return XCTFail("expected sms")
        }
        XCTAssertEqual(message.number, "3333")
        XCTAssertEqual(message.message, "WIN")
        XCTAssertTrue(message.isShortCode)
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.shortCode]))
    }

    func testGeo() {
        let payload = QRClassifier.classify("geo:50.85,4.35?q=Brussels")
        XCTAssertEqual(payload.type, .geo)
        XCTAssertEqual(payload.content, .geo(GeoLocation(latitude: "50.85", longitude: "4.35", label: "Brussels")))
    }

    func testOTPNeverExposesSecret() {
        let secret = "JBSWY3DPEHPK3PXP"
        let payload = QRClassifier.classify("otpauth://totp/Acme:joe?secret=\(secret)&issuer=Acme")
        XCTAssertEqual(payload.type, .otp)
        XCTAssertEqual(payload.content, .otp(OTPAuth(issuer: "Acme", account: "joe", type: "TOTP")))
        XCTAssertEqual(payload.notice, QRNotice(level: .danger, messages: [.signInSecret]))
        XCTAssertTrue(payload.containsSecret)

        for field in payload.fields {
            XCTAssertFalse(String(describing: field.value).contains(secret))
        }
        XCTAssertFalse(payload.redactedRaw.contains(secret))
        XCTAssertFalse(payload.summary.contains(secret))
        XCTAssertEqual(payload.redactedRaw, "otpauth://totp/Acme:joe?issuer=Acme")
    }

    func testOTPCopyNeverContainsSecret() {
        let secret = "JBSWY3DPEHPK3PXP"
        let payload = QRClassifier.classify("otpauth://totp/Acme:joe?secret=\(secret)&issuer=Acme")
        XCTAssertEqual(payload.actions, [.copy])
        XCTAssertEqual(payload.copyText, "Acme\njoe")
        XCTAssertFalse(payload.copyText.contains(secret))
        XCTAssertFalse(payload.copyText.lowercased().contains("secret"))

        // Secret hidden in an unusual place: still only issuer and account.
        let odd = QRClassifier.classify("otpauth://totp/joe?SECRET=\(secret)&digits=6")
        XCTAssertEqual(odd.copyText, "joe")
        XCTAssertFalse(odd.copyText.contains(secret))

        // Everything else copies the scanned text.
        XCTAssertEqual(QRClassifier.classify("hello world").copyText, "hello world")
    }

    func testAppLink() {
        let payload = QRClassifier.classify("spotify:track:123")
        XCTAssertEqual(payload.type, .applink)
        XCTAssertEqual(payload.content, .applink(scheme: "spotify"))
        XCTAssertEqual(payload.notice, QRNotice(level: .caution, messages: [.opensOtherApp]))
    }

    func testPlainText() {
        let payload = QRClassifier.classify("hello world")
        XCTAssertEqual(payload.type, .text)
        XCTAssertEqual(payload.notice, QRNotice(level: .neutral, messages: [.readOnDevice]))
        XCTAssertEqual(payload.actions, [.copy])
    }

    func testBrokenEMVFallsBackToText() {
        XCTAssertEqual(QRClassifier.classify("000201 not tlv").type, .text)
    }

    // MARK: - Additional cases

    func testSurroundingWhitespaceIsTrimmed() {
        let payload = QRClassifier.classify("  \n https://example.com/a \n")
        XCTAssertEqual(payload.type, .url)
        XCTAssertEqual(payload.raw, "https://example.com/a")
    }

    func testPrefixesAreCaseInsensitive() {
        XCTAssertEqual(QRClassifier.classify("wifi:T:WPA;S:x;P:y;;").type, .wifi)
        XCTAssertEqual(QRClassifier.classify("TEL:123").type, .phone)
        XCTAssertEqual(QRClassifier.classify("Bitcoin:abc").type, .crypto)
        XCTAssertEqual(QRClassifier.classify("OTPAUTH://totp/x?secret=A").type, .otp)
        XCTAssertEqual(QRClassifier.classify("mecard:N:A;;").type, .contact)
    }

    func testLinkIsKeptAsWritten() {
        let samples = [
            "https://example.com/a",
            "HTTP://EXAMPLE.COM",
            "https://pay.example.com/p/AbC-123?amount=12.50&ref=%2B%2B%2B090%2F9337%2B%2B%2B#frag",
            "https://user@example.com:8443/path/../x?a=1&a=2&b"
        ]
        for text in samples {
            guard case .url(let url) = QRClassifier.classify(text).content else {
                XCTFail("expected a link: \(text)")
                continue
            }
            XCTAssertEqual(url.absoluteString, text)
        }
    }

    func testAppSchemePayloadsAreKeptAsWritten() {
        let samples = [
            "upi://pay?pa=shop@bank&pn=Corner%20Shop&am=120.50&cu=INR",
            "bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01",
            "spotify:track:123",
            "tel:+3212345678",
            "BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00\n\n\nGift"
        ]
        for text in samples {
            XCTAssertEqual(QRClassifier.classify(text).raw, text)
        }
    }

    func testLinkWithoutHostIsNotAnAppLink() {
        XCTAssertEqual(QRClassifier.classify("http:foo").type, .text)
        XCTAssertEqual(QRClassifier.classify("https://").type, .text)
    }

    func testURLWithSpaceIsStillALink() {
        let payload = QRClassifier.classify("https://example.com/a b")
        XCTAssertEqual(payload.type, .url)
        XCTAssertEqual(payload.host, "example.com")
    }

    func testEPCWithCRLF() {
        let payload = QRClassifier.classify("BCD\r\n001\r\n1\r\nSCT\r\nGKCCBEBB\r\nRode Kruis\r\nBE72 0000 0000 1616\r\nEUR12.34\r\n\r\n+++090/9337/55493+++")
        guard case .epc(let payment) = payload.content else {
            return XCTFail("expected epc")
        }
        XCTAssertEqual(payment.iban, "BE72000000001616")
        XCTAssertTrue(payment.isIBANValid)
        XCTAssertEqual(payment.amount, "12.34")
        XCTAssertEqual(payment.reference, "+++090/9337/55493+++")
        XCTAssertEqual(payment.message, "")
    }

    func testIBANCheck() {
        XCTAssertTrue(IBAN.isValid("GB82 WEST 1234 5698 7654 32"))
        XCTAssertTrue(IBAN.isValid("de89370400440532013000"))
        XCTAssertFalse(IBAN.isValid("GB82 WEST 1234 5698 7654 33"))
        XCTAssertFalse(IBAN.isValid(""))
        XCTAssertFalse(IBAN.isValid("BE72"))
        XCTAssertFalse(IBAN.isValid("BE72-0000-0000-1616"))
        XCTAssertEqual(IBAN.grouped("DE89370400440532013000"), "DE89 3704 0044 0532 0130 00")
    }

    func testEMVUnknownCurrencyShowsNumber() {
        // 00 02 "01", 53 03 "999", 59 01 "A"
        let payload = QRClassifier.classify("00020153039995901A")
        guard case .emv(let payment) = payload.content else {
            return XCTFail("expected emv")
        }
        XCTAssertEqual(payment.currency, "999")
        XCTAssertEqual(payment.merchant, "A")
    }

    func testEMVTruncatedFallsBackToText() {
        XCTAssertEqual(QRClassifier.classify("0002015905AB").type, .text)
    }

    func testCryptoValueParameterAndOtherNetworks() {
        guard case .crypto(let eth) = QRClassifier.classify("ethereum:0xAbC?value=1.5").content else {
            return XCTFail("expected crypto")
        }
        XCTAssertEqual(eth.network, "Ethereum")
        XCTAssertEqual(eth.address, "0xAbC")
        XCTAssertEqual(eth.amount, "1.5")
        XCTAssertEqual(QRClassifier.classify("litecoin:abc").type, .crypto)
        XCTAssertEqual(QRClassifier.classify("bitcoincash:abc").type, .crypto)
        XCTAssertEqual(QRClassifier.classify("lightning:lnbc1").type, .crypto)
    }

    func testWiFiRedactionDropsPassword() {
        let payload = QRClassifier.classify("WIFI:T:WPA;S:Cafe\\;Bar;P:p\\:ss;H:true;;")
        XCTAssertTrue(payload.containsSecret)
        XCTAssertEqual(payload.redactedRaw, "WIFI:T:WPA;S:Cafe\\;Bar;H:true;;")
        XCTAssertFalse(payload.redactedRaw.contains("p\\:ss"))

        // The redacted form still classifies as the same network.
        let again = QRClassifier.classify(payload.redactedRaw)
        guard case .wifi(let network) = again.content else {
            return XCTFail("expected wifi")
        }
        XCTAssertEqual(network.ssid, "Cafe;Bar")
        XCTAssertEqual(network.password, "")
        XCTAssertEqual(network.hidden, true)
        XCTAssertFalse(again.containsSecret)
    }

    func testWiFiWithoutSecurityIsOpen() {
        let payload = QRClassifier.classify("WIFI:S:Guest;;")
        XCTAssertEqual(payload.notice.messages, [.openNetwork])
        XCTAssertEqual(payload.fields, [
            QRField(label: .network, value: .text("Guest")),
            QRField(label: .security, value: QRFieldValue.none)
        ])
    }

    func testVCard() {
        let text = """
        BEGIN:VCARD
        VERSION:3.0
        N:Doe;Jane;;Dr.;
        FN:Dr. Jane Doe
        ORG:Example Corp;Research
        TEL;TYPE=CELL:+32 470 12 34 56
        item1.EMAIL;TYPE=INTERNET:jane@example.com
        ADR;TYPE=WORK:;;Main Street 1;Brussels;;1000;Belgium
        URL:https://example.com/jane
        END:VCARD
        """
        let payload = QRClassifier.classify(text)
        XCTAssertEqual(payload.type, .contact)
        guard case .contact(let card) = payload.content else {
            return XCTFail("expected contact")
        }
        XCTAssertEqual(card.name, "Dr. Jane Doe")
        XCTAssertEqual(card.organisation, "Example Corp, Research")
        XCTAssertEqual(card.phones, ["+32 470 12 34 56"])
        XCTAssertEqual(card.emails, ["jane@example.com"])
        XCTAssertEqual(card.address, "Main Street 1, Brussels, 1000, Belgium")
        XCTAssertEqual(card.url, "https://example.com/jane")
        XCTAssertEqual(payload.actions, [.addToContacts, .copyAll])

        // The contact handed to the system's new-contact screen.
        let contact = ContactDraft.contact(for: payload)
        XCTAssertEqual(contact.givenName, "Jane")
        XCTAssertEqual(contact.familyName, "Doe")
        XCTAssertEqual(contact.phoneNumbers.map { $0.value.stringValue }, ["+32 470 12 34 56"])
        XCTAssertEqual(contact.emailAddresses.map { $0.value as String }, ["jane@example.com"])
    }

    func testContactDraftFromMECARD() {
        let payload = QRClassifier.classify("MECARD:N:Doe,John;TEL:+3212345678;EMAIL:john@example.com;ORG:Example;ADR:Main Street 1,Brussels;URL:https://example.com;;")
        let contact = ContactDraft.contact(for: payload)
        XCTAssertEqual(contact.givenName, "John")
        XCTAssertEqual(contact.familyName, "Doe")
        XCTAssertEqual(contact.organizationName, "Example")
        XCTAssertEqual(contact.phoneNumbers.map { $0.value.stringValue }, ["+3212345678"])
        XCTAssertEqual(contact.emailAddresses.map { $0.value as String }, ["john@example.com"])
        XCTAssertEqual(contact.postalAddresses.map { $0.value.street }, ["Main Street 1, Brussels"])
        XCTAssertEqual(contact.urlAddresses.map { $0.value as String }, ["https://example.com"])
    }

    func testEventDates() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var local = Calendar(identifier: .gregorian)
        local.timeZone = TimeZone.current

        let zulu = QRClassifier.parseEventDate("20261203T120000Z")
        XCTAssertEqual(zulu, EventDate(date: utc.date(from: DateComponents(year: 2026, month: 12, day: 3, hour: 12))!, isAllDay: false))
        XCTAssertEqual(QRClassifier.parseEventDate("20261203T1200Z"), zulu)

        // Without Z: local time.
        let localNoon = local.date(from: DateComponents(year: 2026, month: 12, day: 3, hour: 12, minute: 30))!
        XCTAssertEqual(QRClassifier.parseEventDate("20261203T123000"), EventDate(date: localNoon, isAllDay: false))
        XCTAssertEqual(QRClassifier.parseEventDate("20261203T1230"), EventDate(date: localNoon, isAllDay: false))

        // Without a time: all day.
        let day = local.date(from: DateComponents(year: 2026, month: 12, day: 3))!
        XCTAssertEqual(QRClassifier.parseEventDate("20261203"), EventDate(date: day, isAllDay: true))

        for bad in ["", "2026", "2026-12-03", "20261303", "20260230", "20261203T", "20261203T12", "20261203T2560", "20261203 1200", "20261203T120000ZZ", "tomorrow"] {
            XCTAssertNil(QRClassifier.parseEventDate(bad), bad)
        }
    }

    func testEventSchedule() {
        func schedule(_ lines: String) -> (start: Date, end: Date, isAllDay: Bool)? {
            guard case .event(let event) = QRClassifier.classify("BEGIN:VEVENT\n" + lines + "\nEND:VEVENT").content else { return nil }
            return event.schedule
        }
        // No end: one hour.
        let open = schedule("DTSTART:20261203T120000Z")
        XCTAssertEqual(open?.end.timeIntervalSince(open?.start ?? Date()), 3600)

        // All day; DTEND is the day after the last day.
        let oneDay = schedule("DTSTART;VALUE=DATE:20261203\nDTEND;VALUE=DATE:20261204")
        XCTAssertEqual(oneDay?.isAllDay, true)
        XCTAssertEqual(oneDay?.end, oneDay?.start)
        let threeDays = schedule("DTSTART:20261203\nDTEND:20261206")
        XCTAssertEqual(threeDays?.end, QRClassifier.parseEventDate("20261205")?.date)
        XCTAssertEqual(schedule("DTSTART:20261203")?.isAllDay, true)

        // A start that does not parse: no schedule, so no "Add to calendar".
        XCTAssertNil(schedule("DTSTART:next week"))
        XCTAssertEqual(QRClassifier.classify("BEGIN:VEVENT\nDTSTART:next week\nEND:VEVENT").actions, [.copyAll])
    }

    func testVCardFallsBackToStructuredName() {
        guard case .contact(let card) = QRClassifier.classify("BEGIN:VCARD\nN:Doe;John\nEND:VCARD").content else {
            return XCTFail("expected contact")
        }
        XCTAssertEqual(card.name, "John Doe")
    }

    func testEvent() {
        let text = "BEGIN:VCALENDAR\nBEGIN:VTIMEZONE\nDTSTART:19700101T000000\nEND:VTIMEZONE\nBEGIN:VEVENT\nSUMMARY:Team lunch\nDTSTART;TZID=Europe/Brussels:20261111T123000\nDTEND:20261111T133000Z\nLOCATION:Canteen\\, floor 2\nDESCRIPTION:Bring\n  your badge\nEND:VEVENT\nEND:VCALENDAR"
        let payload = QRClassifier.classify(text)
        XCTAssertEqual(payload.type, .event)
        guard case .event(let event) = payload.content else {
            return XCTFail("expected event")
        }
        XCTAssertEqual(event.title, "Team lunch")
        XCTAssertEqual(event.start, "2026-11-11 12:30")
        XCTAssertEqual(event.end, "2026-11-11 13:30 UTC")
        XCTAssertEqual(event.location, "Canteen, floor 2")
        XCTAssertEqual(event.details, "Bring your badge")
        XCTAssertEqual(QRClassifier.classify("BEGIN:VEVENT\nSUMMARY:X\nDTSTART:20260101\nEND:VEVENT").type, .event)
    }

    func testMailtoAndMATMSG() {
        XCTAssertEqual(
            QRClassifier.classify("mailto:a@b.c?subject=Hi%20there&body=Text").content,
            .email(EmailMessage(to: "a@b.c", subject: "Hi there", body: "Text"))
        )
        XCTAssertEqual(
            QRClassifier.classify("MATMSG:TO:a@b.c;SUB:Hi;BODY:Text;;").content,
            .email(EmailMessage(to: "a@b.c", subject: "Hi", body: "Text"))
        )
    }

    func testSMSVariants() {
        XCTAssertEqual(
            QRClassifier.classify("sms:+3212345678?body=Hello%20you").content,
            .sms(SMSMessage(number: "+3212345678", message: "Hello you"))
        )
        let plain = QRClassifier.classify("sms:+3212345678")
        XCTAssertEqual(plain.content, .sms(SMSMessage(number: "+3212345678", message: "")))
        XCTAssertEqual(plain.notice.level, .neutral)
        XCTAssertFalse(SMSMessage(number: "12", message: "").isShortCode)
        XCTAssertFalse(SMSMessage(number: "1234567", message: "").isShortCode)
        XCTAssertTrue(SMSMessage(number: "123456", message: "").isShortCode)
    }

    func testOTPIssuerFromLabel() {
        let payload = QRClassifier.classify("otpauth://hotp/Example%20Co:alice@example.com?secret=ABC&counter=1")
        XCTAssertEqual(payload.content, .otp(OTPAuth(issuer: "Example Co", account: "alice@example.com", type: "HOTP")))
        XCTAssertEqual(payload.redactedRaw, "otpauth://hotp/Example%20Co:alice@example.com?counter=1")
    }

    func testAppLinkSchemeRules() {
        XCTAssertEqual(QRClassifier.appLinkScheme("Spotify:track:1"), "spotify")
        XCTAssertEqual(QRClassifier.appLinkScheme("a-b.c+d:x"), "a-b.c+d")
        XCTAssertNil(QRClassifier.appLinkScheme("a:x"))
        XCTAssertNil(QRClassifier.appLinkScheme("1abc:x"))
        XCTAssertNil(QRClassifier.appLinkScheme("hello world: x"))
        XCTAssertNil(QRClassifier.appLinkScheme("no colon"))
        XCTAssertNil(QRClassifier.appLinkScheme(String(repeating: "a", count: 33) + ":x"))
        XCTAssertNil(QRClassifier.appLinkScheme("https://example.com"))
    }

    func testTextFieldsAndEmptyInput() {
        let payload = QRClassifier.classify("hello world")
        XCTAssertEqual(payload.fields, [QRField(label: .content, value: .text("hello world"))])
        let empty = QRClassifier.classify("   ")
        XCTAssertEqual(empty.type, .text)
        XCTAssertEqual(empty.fields, [])
    }
}
