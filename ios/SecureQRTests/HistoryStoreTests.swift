import XCTest
@testable import SecureQR

final class HistoryStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("secureqr-store-\(UUID().uuidString)")
            .appendingPathComponent("history.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    private func scan(_ text: String, into store: HistoryStore) -> UUID {
        return store.record(QRClassifier.classify(text))
    }

    func testLinkStartsUncheckedThenGetsVerdict() {
        let store = HistoryStore(fileURL: fileURL)
        let id = scan("https://example.com/a", into: store)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].type, .url)
        XCTAssertEqual(store.entries[0].host, "example.com")
        XCTAssertNil(store.entries[0].verdict)
        XCTAssertFalse(store.entries[0].checkFailed)

        store.setVerdict(.caution, for: id)
        XCTAssertEqual(store.entries[0].verdict, .caution)
        XCTAssertFalse(store.entries[0].checkFailed)
    }

    func testFailedCheckIsKept() {
        let store = HistoryStore(fileURL: fileURL)
        let id = scan("http://192.168.1.1/", into: store)
        store.markCheckFailed(for: id)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertTrue(store.entries[0].checkFailed)
        XCTAssertNil(store.entries[0].verdict)
        XCTAssertEqual(store.entries[0].payload, "http://192.168.1.1/")

        // It survives a restart, still marked.
        let reloaded = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.entries, store.entries)
        XCTAssertTrue(reloaded.entries[0].checkFailed)

        // A later successful check replaces the failed state, and the reverse.
        reloaded.setVerdict(.ok, for: id)
        XCTAssertFalse(reloaded.entries[0].checkFailed)
        XCTAssertEqual(reloaded.entries[0].verdict, .ok)
        reloaded.markCheckFailed(for: id)
        XCTAssertTrue(reloaded.entries[0].checkFailed)
        XCTAssertNil(reloaded.entries[0].verdict)
    }

    func testEveryContentTypeIsStored() {
        let samples: [(String, QRType)] = [
            ("https://discord.com/ra/AbCdEf123456", .login),
            ("https://wa.me/3212345678?text=Hi%20there", .chat),
            ("SPC\n0200\n1\nCH4431999123000889012\nS\nRobert Schneider AG", .swissqr),
            ("SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK", .spd),
            ("otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU", .otpexport),
            ("LPA:1$smdp.example.com$ABCD-1234-EFGH", .esim),
            ("MT:Y.K9042C00KA0648G00", .device),
            ("HC1:6BF+70790T9WJWG.FKY*4GO0.O1CV2 O5 N2FBBRW1*70HS8WY04AC*WIFN0AHCD8KD97TK0F90KEC", .healthcert),
            ("javascript:alert(1)", .unsafe),
            ("https://payconiq.com/t/1/5f2a9c0e1b?D=Invoice%2042&A=1250&R=INV42", .paylink),
            ("https://example.com/a", .url),
            ("BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00", .epc),
            ("00020101021129370016A000000677010111011300660000000005802TH530376454031005913Test Merchant6007Bangkok6304ABCD", .emv),
            ("upi://pay?pa=shop@bank&pn=Corner%20Shop&am=120.50&cu=INR", .upi),
            ("bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01", .crypto),
            ("WIFI:T:WPA;S:Home;P:hunter2secret;;", .wifi),
            ("MECARD:N:Doe,John;TEL:+3212345678;;", .contact),
            ("BEGIN:VEVENT\nSUMMARY:X\nDTSTART:20260101\nEND:VEVENT", .event),
            ("mailto:a@b.c?subject=Hi", .email),
            ("tel:+3212345678", .phone),
            ("smsto:3333:WIN", .sms),
            ("geo:50.85,4.35?q=Brussels", .geo),
            ("otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme", .otp),
            ("spotify:track:123", .applink),
            ("hello world", .text)
        ]
        XCTAssertEqual(Set(samples.map { $0.1 }), Set(QRType.allCases))

        let store = HistoryStore(fileURL: fileURL)
        for sample in samples {
            _ = scan(sample.0, into: store)
        }
        XCTAssertEqual(store.entries.count, samples.count)
        // Newest first.
        XCTAssertEqual(store.entries.map { $0.type }, samples.map { $0.1 }.reversed())

        let reloaded = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.entries, store.entries)
        // Each stored payload still classifies as the same type.
        for entry in reloaded.entries {
            XCTAssertEqual(QRClassifier.classify(stored: entry.payload, as: entry.type).type, entry.type)
        }
    }

    func testCodesAreRedactedOnDisk() throws {
        let samples: [(text: String, secret: String, stored: String)] = [
            ("https://discord.com/ra/AbCdEf123456", "AbCdEf123456", "https://discord.com/…"),
            ("https://s.team/q/1/1234567890", "1234567890", "https://s.team/…"),
            ("tg://login?token=abc", "token", "tg://…"),
            ("tsdevice:/?uuid=abcdef&pub_key=xyz", "abcdef", "tsdevice:…"),
            ("2@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl,MnOpQrStUvWxYzAb,CdEfGhIjKlMnOpQr", "AbCdEfGhIjKl", "…"),
            ("otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU", "CjEKCkhlbGxv", "otpauth-migration://…"),
            ("LPA:1$smdp.example.com$ABCD-1234-EFGH", "ABCD-1234-EFGH", "LPA:1$smdp.example.com$…"),
            ("MT:Y.K9042C00KA0648G00", "K9042C00KA", "MT:…"),
            ("X-HM://0023ISYWYABCD", "0023ISYWY", "X-HM://…"),
            ("DPP:C:81/1;M:aa:bb:cc:dd:ee:ff;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgAC;;", "MDkwEwYH", "DPP:…"),
            ("HC1:6BF+70790T9WJWG.FKY*4GO0.O1CV2 O5 N2FBBRW1*70HS8WY04AC*WIFN0AHCD8KD97TK0F90KEC", "6BF+70790T9WJWG", "HC1:…"),
            ("shc:/5676290952432060346029243740446031222959532654603460292540772804336028", "567629095243", "shc:/…")
        ]
        let store = HistoryStore(fileURL: fileURL)
        for sample in samples {
            _ = scan(sample.text, into: store)
        }
        XCTAssertEqual(store.entries.map { $0.payload }, samples.map { $0.stored }.reversed())
        XCTAssertTrue(store.entries.allSatisfy { $0.redacted })

        let onDisk = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)
        for sample in samples {
            XCTAssertFalse(onDisk.contains(sample.secret), sample.text)
        }
    }

    func testStoredSignInCodeIsNeverALink() {
        let texts: [(String, String)] = [
            ("https://discord.com/ra/AbCdEf123456", "Discord"),
            ("https://s.team/q/1/1234567890", "Steam"),
            ("https://login.weixin.qq.com/l/abcdef", "WeChat"),
            ("tg://login?token=abc", "Telegram"),
            ("sgnl://linkdevice?uuid=abc&pub_key=def", "Signal"),
            ("2@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl,MnOpQrStUvWxYzAb,CdEfGhIjKlMnOpQr", "WhatsApp")
        ]
        let store = HistoryStore(fileURL: fileURL)
        for text in texts {
            _ = scan(text.0, into: store)
        }
        let reloaded = HistoryStore(fileURL: fileURL)
        for (entry, text) in zip(reloaded.entries, texts.reversed()) {
            XCTAssertEqual(entry.type, .login)
            XCTAssertNil(entry.host)
            let payload = QRClassifier.classify(stored: entry.payload, as: entry.type)
            XCTAssertEqual(payload.content, .login(service: text.1), text.0)
            XCTAssertEqual(payload.summary, text.1)
            XCTAssertEqual(payload.actions, [])
            XCTAssertNil(payload.host)
        }
        // Any other stored type is classified from its text as before.
        XCTAssertEqual(QRClassifier.classify(stored: "https://example.com/a", as: .url).type, .url)
        XCTAssertEqual(QRClassifier.classify(stored: "tel:1", as: .phone).type, .phone)
    }

    func testSecretsAreRedactedOnDisk() throws {
        let store = HistoryStore(fileURL: fileURL)
        _ = scan("otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme", into: store)
        _ = scan("WIFI:T:WPA;S:Home;P:hunter2secret;;", into: store)

        let onDisk = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)
        XCTAssertFalse(onDisk.contains("JBSWY3DPEHPK3PXP"))
        XCTAssertFalse(onDisk.contains("hunter2secret"))
        XCTAssertTrue(store.entries.allSatisfy { $0.redacted })
    }

    func testRemoveAndClear() {
        let store = HistoryStore(fileURL: fileURL)
        let first = scan("tel:1", into: store)
        let second = scan("tel:2", into: store)
        let third = scan("tel:3", into: store)

        store.remove(second)
        XCTAssertEqual(store.entries.map { $0.id }, [third, first])
        store.remove(second)
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(HistoryStore(fileURL: fileURL).entries.map { $0.id }, [third, first])

        store.clear()
        XCTAssertEqual(store.entries, [])
        XCTAssertEqual(HistoryStore(fileURL: fileURL).entries, [])
    }

    func testCapAtFiveHundred() {
        XCTAssertEqual(HistoryFile.maximumEntries, 500)
        let store = HistoryStore(fileURL: fileURL)
        for index in 0..<505 {
            _ = scan("tel:\(index)", into: store)
        }
        XCTAssertEqual(store.entries.count, 500)
        XCTAssertEqual(store.entries.first?.payload, "tel:504")
        XCTAssertEqual(store.entries.last?.payload, "tel:5")
    }

    func testOlderFileWithoutNewFieldsStillLoads() throws {
        let old = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","payload":"https://example.com/a","type":"url",
          "host":"example.com","verdict":"ok","date":"2026-11-11T10:00:00Z","redacted":false}]
        """
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(old.utf8).write(to: fileURL)

        let store = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].verdict, .ok)
        XCTAssertFalse(store.entries[0].checkFailed)
    }
}
