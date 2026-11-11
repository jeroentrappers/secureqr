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
        XCTAssertEqual(payload.actions, [.copyPassword])
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
        XCTAssertEqual(payload.actions, [])
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
    }

    func testTel() {
        let payload = QRClassifier.classify("tel:+3212345678")
        XCTAssertEqual(payload.type, .phone)
        XCTAssertEqual(payload.content, .phone("+3212345678"))
        XCTAssertEqual(payload.actions, [.openInApp, .copy])
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
        XCTAssertEqual(payload.actions, [.copyAll])
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
