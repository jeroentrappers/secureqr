import XCTest
@testable import SecureQR

final class PreviewModelsTests: XCTestCase {

    private let documentedResponse = """
    {
      "id": "b3f1c2e4a9d04c6f",
      "requestedUrl": "https://qr-go.example/x7Pq",
      "finalUrl": "https://pay-fee.parcel-track.example/pay?id=1",
      "finalHost": "pay-fee.parcel-track.example",
      "finalDomain": "parcel-track.example",
      "title": "Your parcel is on hold",
      "https": true,
      "hops": [
        { "url": "https://qr-go.example/x7Pq", "host": "qr-go.example", "status": 301, "kind": "start" },
        { "url": "https://trk.mailing.example/c/9", "host": "trk.mailing.example", "status": 302, "kind": "http" },
        { "url": "https://pay-fee.parcel-track.example/pay?id=1", "host": "pay-fee.parcel-track.example", "status": 200, "kind": "http" }
      ],
      "screenshotUrl": "/v1/screenshots/b3f1c2e4a9d04c6f.jpg",
      "reputation": { "checked": ["Quad9", "Cloudflare"], "flaggedBy": [], "flaggedHost": null },
      "verdict": {
        "level": "caution",
        "reasons": [
          { "code": "domain_changed", "message": "Ends at a different site than it starts" },
          { "code": "asks_for_payment", "message": "The page asks for card details" }
        ]
      },
      "durationMs": 4210
    }
    """

    private func decode(_ json: String, status: Int = 200) throws -> PreviewResult {
        return try PreviewDecoding.decode(status: status, data: Data(json.utf8))
    }

    func testDocumentedResponse() throws {
        let result = try decode(documentedResponse)
        XCTAssertEqual(result.id, "b3f1c2e4a9d04c6f")
        XCTAssertEqual(result.requestedUrl, "https://qr-go.example/x7Pq")
        XCTAssertEqual(result.finalHost, "pay-fee.parcel-track.example")
        XCTAssertEqual(result.finalDomain, "parcel-track.example")
        XCTAssertEqual(result.title, "Your parcel is on hold")
        XCTAssertTrue(result.https)
        XCTAssertEqual(result.hops.count, 3)
        XCTAssertEqual(result.hops[0].kind, .start)
        XCTAssertEqual(result.hops[1].status, 302)
        XCTAssertEqual(result.redirectCount, 2)
        XCTAssertEqual(result.screenshotUrl, "/v1/screenshots/b3f1c2e4a9d04c6f.jpg")
        XCTAssertEqual(result.verdict.level, .caution)
        XCTAssertEqual(result.verdict.reasons.first?.message, "Ends at a different site than it starts")
        XCTAssertEqual(result.reputation?.checked, ["Quad9", "Cloudflare"])
        XCTAssertEqual(result.reputationStatus, .clean)
        XCTAssertEqual(result.durationMs, 4210)
    }

    func testReputationAbsentShowsNoChip() throws {
        let result = try decode("""
        {"finalUrl":"https://a.example/","finalHost":"a.example","verdict":{"level":"ok","reasons":[]}}
        """)
        XCTAssertNil(result.reputation)
        XCTAssertEqual(result.reputationStatus, .unknown)
        XCTAssertEqual(result.finalDomain, "a.example")
        XCTAssertTrue(result.https)
        XCTAssertEqual(result.hops, [])
        XCTAssertEqual(result.redirectCount, 0)
        XCTAssertNil(result.screenshotUrl)
    }

    func testReputationStates() throws {
        let flagged = try decode("""
        {"finalUrl":"http://a.example/","finalHost":"a.example",
         "reputation":{"checked":["Quad9"],"flaggedBy":["Quad9"],"flaggedHost":"a.example"},
         "verdict":{"level":"danger","reasons":[{"code":"known_malicious","message":"On a threat blocklist"}]}}
        """)
        XCTAssertEqual(flagged.reputationStatus, .flagged)
        XCTAssertEqual(flagged.reputation?.flaggedHost, "a.example")
        XCTAssertEqual(flagged.verdict.reasons.first?.code, "known_malicious")
        XCTAssertFalse(flagged.https)

        let unchecked = try decode("""
        {"finalUrl":"https://a.example/","finalHost":"a.example",
         "reputation":{"checked":[],"flaggedBy":[],"flaggedHost":null},
         "verdict":{"level":"ok","reasons":[]}}
        """)
        XCTAssertEqual(unchecked.reputationStatus, .unknown)

        let partial = try decode("""
        {"finalUrl":"https://a.example/","finalHost":"a.example",
         "reputation":{"checked":["Quad9"]},
         "verdict":{"level":"ok"}}
        """)
        XCTAssertEqual(partial.reputationStatus, .clean)
        XCTAssertEqual(partial.verdict.reasons, [])
    }

    func testUnknownFieldsAndValuesAreIgnored() throws {
        let result = try decode("""
        {"finalUrl":"https://a.example/","finalHost":"a.example","somethingNew":{"x":[1,2]},
         "screenshotUrl":null,
         "hops":[{"url":"https://a.example/","host":"a.example","status":null,"kind":"teleport","extra":1}],
         "reputation":{"checked":["Quad9"],"flaggedBy":[],"flaggedHost":null,"score":3},
         "verdict":{"level":"catastrophic","extra":true,
                    "reasons":[{"code":"brand_new_code","message":"Something new","weight":2}]}}
        """)
        XCTAssertEqual(result.hops.first?.kind, .unknown)
        XCTAssertNil(result.hops.first?.status)
        XCTAssertNil(result.screenshotUrl)
        // An unknown level must never read as "ok".
        XCTAssertEqual(result.verdict.level, .caution)
        XCTAssertEqual(result.verdict.reasons, [VerdictReason(code: "brand_new_code", message: "Something new")])
    }

    func testCachedAnswer() throws {
        let cached = try decode("""
        {"finalUrl":"https://a.example/","finalHost":"a.example","verdict":{"level":"ok"},
         "checkedAt":"2026-11-11T10:42:07.120Z","cached":true,
         "reputation":{"checked":["Quad9","Cloudflare","DNS4EU","Phishing.Database"],"flaggedBy":[]}}
        """)
        XCTAssertTrue(cached.cached)
        let checkedAt = try XCTUnwrap(cached.checkedAt)
        XCTAssertEqual(checkedAt.timeIntervalSince1970, 1_794_393_727.12, accuracy: 0.01)
        XCTAssertEqual(cached.minutesSinceChecked(now: checkedAt.addingTimeInterval(4 * 60 + 30)), 4)
        XCTAssertEqual(cached.minutesSinceChecked(now: checkedAt.addingTimeInterval(20)), 0)
        XCTAssertEqual(cached.minutesSinceChecked(now: checkedAt.addingTimeInterval(-5)), 0)
        XCTAssertEqual(cached.reputation?.checked.count, 4)
        XCTAssertEqual(cached.reputationStatus, .clean)

        let fresh = try decode("""
        {"finalUrl":"https://a.example/","finalHost":"a.example","verdict":{"level":"ok"},
         "checkedAt":"2026-11-11T10:42:07Z","cached":false}
        """)
        XCTAssertFalse(fresh.cached)
        XCTAssertNotNil(fresh.checkedAt)
        XCTAssertNil(fresh.minutesSinceChecked())

        let absent = try decode("""
        {"finalUrl":"https://a.example/","finalHost":"a.example","verdict":{"level":"ok"}}
        """)
        XCTAssertFalse(absent.cached)
        XCTAssertNil(absent.checkedAt)

        let odd = try decode("""
        {"finalUrl":"https://a.example/","finalHost":"a.example","verdict":{"level":"ok"},
         "checkedAt":"yesterday","cached":true}
        """)
        XCTAssertTrue(odd.cached)
        XCTAssertNil(odd.minutesSinceChecked())
    }

    func testErrorResponses() {
        let cases: [(Int, String)] = [
            (400, "invalid_url"), (400, "blocked_target"), (422, "unreachable"),
            (429, "rate_limited"), (504, "timeout"), (500, "internal")
        ]
        for (status, code) in cases {
            let body = "{\"error\":{\"code\":\"\(code)\",\"message\":\"Friendly \(code)\"}}"
            XCTAssertThrowsError(try decode(body, status: status)) { error in
                XCTAssertEqual(error as? PreviewFailure, .server(code: code, message: "Friendly \(code)"))
            }
            XCTAssertTrue(PreviewFailure.knownCodes.contains(code))
        }
    }

    func testErrorWithoutBodyFallsBackOnStatus() {
        XCTAssertThrowsError(try decode("<html>Bad gateway</html>", status: 504)) { error in
            XCTAssertEqual(error as? PreviewFailure, .server(code: "timeout", message: ""))
        }
        XCTAssertThrowsError(try decode("", status: 503)) { error in
            XCTAssertEqual(error as? PreviewFailure, .server(code: "internal", message: ""))
        }
    }

    func testMalformedSuccessIsUnexpected() {
        XCTAssertThrowsError(try decode("{\"ok\":true}")) { error in
            XCTAssertEqual(error as? PreviewFailure, .unexpected)
        }
    }

    func testRetryability() {
        XCTAssertFalse(PreviewFailure.server(code: "invalid_url", message: "").isRetryable)
        XCTAssertFalse(PreviewFailure.server(code: "blocked_target", message: "").isRetryable)
        XCTAssertTrue(PreviewFailure.server(code: "rate_limited", message: "").isRetryable)
        XCTAssertTrue(PreviewFailure.server(code: "unreachable", message: "").isRetryable)
        XCTAssertTrue(PreviewFailure.offline.isRetryable)
        XCTAssertTrue(PreviewFailure.timedOut.isRetryable)
    }
}

final class HistoryEntryTests: XCTestCase {

    func testSecretsNeverReachTheHistoryFile() throws {
        let otp = QRClassifier.classify("otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme")
        let wifi = QRClassifier.classify("WIFI:T:WPA;S:Home;P:hunter2secret;;")
        let entries = [HistoryEntry(payload: otp), HistoryEntry(payload: wifi)]

        let json = String(decoding: try HistoryFile.encode(entries), as: UTF8.self)
        XCTAssertFalse(json.contains("JBSWY3DPEHPK3PXP"))
        XCTAssertFalse(json.contains("hunter2secret"))
        XCTAssertTrue(entries[0].redacted)
        XCTAssertTrue(entries[1].redacted)
        XCTAssertEqual(entries[0].type, .otp)
        XCTAssertEqual(entries[1].payload, "WIFI:T:WPA;S:Home;;")
    }

    func testRoundTrip() throws {
        var entry = HistoryEntry(
            payload: QRClassifier.classify("https://example.com/a"),
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        entry.verdict = .danger
        XCTAssertEqual(entry.host, "example.com")
        XCTAssertFalse(entry.redacted)

        let decoded = try HistoryFile.decode(try HistoryFile.encode([entry]))
        XCTAssertEqual(decoded, [entry])
    }

    func testSaveAndLoad() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("secureqr-tests-\(UUID().uuidString)")
            .appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertEqual(HistoryFile.load(from: url), [])
        let entry = HistoryEntry(
            payload: QRClassifier.classify("tel:+3212345678"),
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try HistoryFile.save([entry], to: url)
        XCTAssertEqual(HistoryFile.load(from: url), [entry])

        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(HistoryFile.load(from: url), [])
    }
}
