import XCTest
@testable import SecureQR

/// Answers the client's requests from a table keyed by URL path.
private final class StubProtocol: URLProtocol {
    struct Answer {
        var status = 200
        var contentType = "application/x-ndjson"
        /// Delivered one piece at a time.
        var chunks: [String] = []
        /// Ends the load with this error after the chunks instead of finishing.
        var failure: URLError.Code?
    }

    private static let lock = NSLock()
    private static var answers: [String: Answer] = [:]
    private static var requested: [String] = []
    private static var headers: [[String: String]] = []

    static func reset(_ answers: [String: Answer]) {
        lock.lock()
        self.answers = answers
        requested = []
        headers = []
        lock.unlock()
    }

    /// The header fields of each request, in the order of `requestedPaths`.
    static var requestedHeaders: [[String: String]] {
        lock.lock()
        defer { lock.unlock() }
        return headers
    }

    static var requestedPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        StubProtocol.lock.lock()
        StubProtocol.requested.append(path)
        StubProtocol.headers.append(request.allHTTPHeaderFields ?? [:])
        let answer = StubProtocol.answers[path]
        StubProtocol.lock.unlock()

        guard let answer = answer, let url = request.url,
              let response = HTTPURLResponse(
                url: url, statusCode: answer.status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": answer.contentType]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in answer.chunks {
            client?.urlProtocol(self, didLoad: Data(chunk.utf8))
        }
        if let failure = answer.failure {
            client?.urlProtocol(self, didFailWithError: URLError(failure))
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

final class PreviewStreamTests: XCTestCase {

    private let resultJSON = """
    {"id":"b3f1","requestedUrl":"https://qr-go.example/x7Pq","finalUrl":"https://parcel-track.example/pay",\
    "finalHost":"parcel-track.example","finalDomain":"parcel-track.example","title":"Parcel","https":true,\
    "hops":[{"url":"https://qr-go.example/x7Pq","host":"qr-go.example","status":301,"kind":"start"},\
    {"url":"https://parcel-track.example/pay","host":"parcel-track.example","status":200,"kind":"http"}],\
    "screenshotUrl":"/v1/screenshots/b3f1.jpg","verdict":{"level":"caution","reasons":\
    [{"code":"domain_changed","message":"Ends at a different site than it starts"}]},"durationMs":4210}
    """

    /// The example from docs/api.md, without its last line.
    private let documentedSteps = [
        #"{"type":"step","id":"blocklists","state":"active","label":"Checking threat blocklists"}"#,
        #"{"type":"step","id":"address","state":"active","label":"Looking up the address"}"#,
        #"{"type":"step","id":"address","state":"done","label":"Address found"}"#,
        #"{"type":"step","id":"redirects","state":"active","label":"Following the link"}"#,
        #"{"type":"hop","hop":{"url":"https://qr-go.example/x7Pq","host":"qr-go.example","status":null,"kind":"start"}}"#,
        #"{"type":"hop","hop":{"url":"https://parcel-track.example/pay","host":"parcel-track.example","status":null,"kind":"http"}}"#,
        #"{"type":"step","id":"page","state":"active","label":"Loading the page"}"#,
        #"{"type":"step","id":"redirects","state":"done","label":"1 redirect"}"#,
        #"{"type":"step","id":"page","state":"done","label":"Page loaded"}"#,
        #"{"type":"step","id":"forms","state":"active","label":"Looking for sign-in and payment forms"}"#,
        #"{"type":"step","id":"picture","state":"active","label":"Taking a picture of the page"}"#,
        #"{"type":"step","id":"blocklists","state":"done","label":"Not on 4 blocklists"}"#,
        #"{"type":"step","id":"forms","state":"done","label":"Asks for card details"}"#,
        #"{"type":"step","id":"picture","state":"done","label":"Picture taken"}"#
    ]

    private var resultLine: String {
        return #"{"type":"result","result":"# + resultJSON + "}"
    }

    private func progress(after lines: [String]) -> PreviewProgress {
        var progress = PreviewProgress()
        for line in lines {
            if case .event(let event)? = PreviewStreamLine.parse(line) {
                progress.apply(event)
            }
        }
        return progress
    }

    // MARK: - Lines

    func testStepLine() {
        XCTAssertEqual(
            PreviewStreamLine.parse(documentedSteps[0]),
            .event(.step(PreviewStep(id: "blocklists", state: .active, label: "Checking threat blocklists")))
        )
        XCTAssertEqual(
            PreviewStreamLine.parse(documentedSteps[2]),
            .event(.step(PreviewStep(id: "address", state: .done, label: "Address found")))
        )
    }

    func testHopLine() {
        XCTAssertEqual(PreviewStreamLine.parse(documentedSteps[4]), .event(.hop(host: "qr-go.example")))
        XCTAssertEqual(PreviewStreamLine.parse(#"{"type":"hop","hop":{"host":"a.example","new":1}}"#), .event(.hop(host: "a.example")))
        XCTAssertNil(PreviewStreamLine.parse(#"{"type":"hop","hop":{"url":"https://a.example/"}}"#))
        XCTAssertNil(PreviewStreamLine.parse(#"{"type":"hop"}"#))
    }

    func testResultLine() throws {
        guard case .event(.result(let result))? = PreviewStreamLine.parse(resultLine) else {
            return XCTFail("expected a result")
        }
        XCTAssertEqual(result.finalHost, "parcel-track.example")
        XCTAssertEqual(result.verdict.level, .caution)
        XCTAssertEqual(result.redirectCount, 1)
        XCTAssertEqual(result.screenshotUrl, "/v1/screenshots/b3f1.jpg")
    }

    func testUnreadableResultLineIsAFailure() {
        XCTAssertEqual(PreviewStreamLine.parse(#"{"type":"result","result":{"id":"x"}}"#), .failure(.unexpected))
        XCTAssertEqual(PreviewStreamLine.parse(#"{"type":"result"}"#), .failure(.unexpected))
    }

    func testErrorLine() {
        XCTAssertEqual(
            PreviewStreamLine.parse(#"{"type":"error","status":422,"error":{"code":"unreachable","message":"The site did not respond"}}"#),
            .failure(.server(code: "unreachable", message: "The site did not respond"))
        )
        // Without a readable error object the status decides.
        XCTAssertEqual(
            PreviewStreamLine.parse(#"{"type":"error","status":504}"#),
            .failure(.server(code: "timeout", message: ""))
        )
        XCTAssertEqual(
            PreviewStreamLine.parse(#"{"type":"error"}"#),
            .failure(.server(code: "internal", message: ""))
        )
    }

    func testUnknownTypesAndFieldsAreIgnored() {
        XCTAssertNil(PreviewStreamLine.parse(#"{"type":"heartbeat","at":12}"#))
        XCTAssertNil(PreviewStreamLine.parse(#"{"type":"step","id":"page","state":"skipped","label":"Skipped"}"#))
        XCTAssertNil(PreviewStreamLine.parse(#"{"type":"step","state":"active","label":"No id"}"#))
        XCTAssertNil(PreviewStreamLine.parse(#"{"id":"page","state":"active"}"#))
        XCTAssertNil(PreviewStreamLine.parse(""))
        XCTAssertNil(PreviewStreamLine.parse("   "))
        XCTAssertNil(PreviewStreamLine.parse(#"{"type":"step","id":"pa"#))
        XCTAssertNil(PreviewStreamLine.parse("[1,2]"))
        XCTAssertEqual(
            PreviewStreamLine.parse(#"{"type":"step","id":"page","state":"done","label":"Page loaded","ms":120,"extra":{"a":[1]}}"#),
            .event(.step(PreviewStep(id: "page", state: .done, label: "Page loaded")))
        )
    }

    // MARK: - Checklist

    func testStepsKeepTheOrderOfFirstArrivalAndUpdateInPlace() {
        let midway = progress(after: Array(documentedSteps.prefix(7)))
        XCTAssertEqual(midway.steps.map { $0.id }, ["blocklists", "address", "redirects", "page"])
        XCTAssertEqual(midway.steps.map { $0.state }, [.active, .done, .active, .active])
        XCTAssertEqual(midway.steps[1].label, "Address found")

        let end = progress(after: documentedSteps)
        XCTAssertEqual(end.steps.map { $0.id }, ["blocklists", "address", "redirects", "page", "forms", "picture"])
        XCTAssertTrue(end.steps.allSatisfy { $0.state == .done })
        XCTAssertEqual(end.steps.map { $0.label }, [
            "Not on 4 blocklists", "Address found", "1 redirect", "Page loaded", "Asks for card details", "Picture taken"
        ])
        XCTAssertEqual(end.hosts, ["qr-go.example", "parcel-track.example"])
    }

    func testProgressStartsEmpty() {
        XCTAssertTrue(PreviewProgress().isEmpty)
        XCTAssertFalse(progress(after: [documentedSteps[0]]).isEmpty)
    }

    func testRepeatedHostIsListedOnce() {
        var progress = PreviewProgress()
        for host in ["a.example", "a.example", "b.example", "b.example", "a.example", ""] {
            progress.apply(.hop(host: host))
        }
        XCTAssertEqual(progress.hosts, ["a.example", "b.example", "a.example"])
    }

    func testStepWithoutLabelKeepsTheEarlierLabel() {
        var progress = PreviewProgress()
        progress.apply(.step(PreviewStep(id: "new", state: .active, label: "")))
        XCTAssertTrue(progress.isEmpty)
        progress.apply(.step(PreviewStep(id: "page", state: .active, label: "Loading the page")))
        progress.apply(.step(PreviewStep(id: "page", state: .done, label: "")))
        XCTAssertEqual(progress.steps, [PreviewStep(id: "page", state: .done, label: "Loading the page")])
    }

    // MARK: - Client

    private func client(apiKey: String = "") -> PreviewClient {
        return PreviewClient(
            baseURL: URL(string: "https://stub.example")!, apiKey: apiKey, protocolClasses: [StubProtocol.self]
        )
    }

    /// The app key header of each request, nil where it was not sent.
    private var sentKeys: [String?] {
        return StubProtocol.requestedHeaders.map { fields in
            fields.first { $0.key.caseInsensitiveCompare("X-SecureQR-Key") == .orderedSame }?.value
        }
    }

    private func collect(_ client: PreviewClient) async -> (events: [PreviewEvent], failure: PreviewFailure?) {
        var events: [PreviewEvent] = []
        do {
            for try await event in client.previewEvents(url: "https://qr-go.example/x7Pq") {
                events.append(event)
            }
            return (events, nil)
        } catch let failure as PreviewFailure {
            return (events, failure)
        } catch {
            XCTFail("unexpected error type: \(error)")
            return (events, .unexpected)
        }
    }

    func testStreamReportsStepsThenTheResult() async {
        let lines = documentedSteps + [#"{"type":"later","x":1}"#, resultLine]
        // Split in the middle of lines: the client must reassemble them.
        let body = lines.joined(separator: "\n") + "\n"
        let cut = body.index(body.startIndex, offsetBy: 130)
        let cut2 = body.index(body.startIndex, offsetBy: 700)
        StubProtocol.reset(["/v1/preview/stream": .init(chunks: [
            String(body[..<cut]), String(body[cut..<cut2]), String(body[cut2...])
        ])])

        let (events, failure) = await collect(client())
        XCTAssertNil(failure)
        XCTAssertEqual(events.count, documentedSteps.count + 1)
        XCTAssertEqual(events.first, .step(PreviewStep(id: "blocklists", state: .active, label: "Checking threat blocklists")))
        XCTAssertEqual(events[4], .hop(host: "qr-go.example"))
        guard case .result(let result)? = events.last else {
            return XCTFail("the last event must be the result")
        }
        XCTAssertEqual(result.finalHost, "parcel-track.example")
        XCTAssertEqual(StubProtocol.requestedPaths, ["/v1/preview/stream"])
    }

    func testReusedAnswerIsASingleResult() async {
        StubProtocol.reset(["/v1/preview/stream": .init(chunks: [resultLine + "\n"])])
        let (events, failure) = await collect(client())
        XCTAssertNil(failure)
        XCTAssertEqual(events.count, 1)
        guard case .result? = events.first else {
            return XCTFail("expected only the result")
        }
    }

    func testResultWithoutTrailingNewline() async {
        StubProtocol.reset(["/v1/preview/stream": .init(chunks: [documentedSteps[0] + "\n", resultLine])])
        let (events, failure) = await collect(client())
        XCTAssertNil(failure)
        XCTAssertEqual(events.count, 2)
    }

    func testErrorLineEndsTheStreamWithTheServersError() async {
        let error = #"{"type":"error","status":422,"error":{"code":"unreachable","message":"The site did not respond"}}"#
        StubProtocol.reset(["/v1/preview/stream": .init(chunks: [
            documentedSteps[0] + "\n" + documentedSteps[1] + "\n", error + "\n"
        ])])
        let (events, failure) = await collect(client())
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(failure, .server(code: "unreachable", message: "The site did not respond"))
    }

    func testTruncatedStreamIsANetworkFailure() async {
        // Ends cleanly, but in the middle of a line and without a result.
        StubProtocol.reset(["/v1/preview/stream": .init(chunks: [
            documentedSteps[0] + "\n" + documentedSteps[1] + "\n" + #"{"type":"step","id":"addr"#
        ])])
        let (events, failure) = await collect(client())
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(failure, .offline)

        StubProtocol.reset(["/v1/preview/stream": .init(chunks: [])])
        let empty = await collect(client())
        XCTAssertTrue(empty.events.isEmpty)
        XCTAssertEqual(empty.failure, .offline)
    }

    func testConnectionLostMidStreamIsANetworkFailure() async {
        StubProtocol.reset(["/v1/preview/stream": .init(
            chunks: [documentedSteps[0] + "\n"], failure: .networkConnectionLost
        )])
        let (_, failure) = await collect(client())
        XCTAssertEqual(failure, .offline)
    }

    func testMissingStreamEndpointFallsBackToThePlainOne() async {
        StubProtocol.reset([
            "/v1/preview/stream": .init(status: 404, contentType: "text/html", chunks: ["<html>Not found</html>"]),
            "/v1/preview": .init(contentType: "application/json", chunks: [resultJSON])
        ])
        let (events, failure) = await collect(client())
        XCTAssertNil(failure)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.first, .withoutSteps)
        guard case .result(let result)? = events.last else {
            return XCTFail("expected the plain endpoint's result")
        }
        XCTAssertEqual(result.finalHost, "parcel-track.example")
        XCTAssertEqual(StubProtocol.requestedPaths, ["/v1/preview/stream", "/v1/preview"])
    }

    func testFallbackKeepsThePlainEndpointsErrors() async {
        StubProtocol.reset([
            "/v1/preview/stream": .init(status: 404, contentType: "application/json", chunks: [#"{"error":{"code":"not_found","message":"Not found"}}"#]),
            "/v1/preview": .init(status: 504, contentType: "application/json", chunks: [#"{"error":{"code":"timeout","message":"Too slow"}}"#])
        ])
        let (events, failure) = await collect(client())
        XCTAssertEqual(events, [.withoutSteps])
        XCTAssertEqual(failure, .server(code: "timeout", message: "Too slow"))
    }

    func testErrorResponseKeepsTheUsualHandling() async {
        StubProtocol.reset(["/v1/preview/stream": .init(
            status: 429, contentType: "application/json",
            chunks: [#"{"error":{"code":"rate_limited","message":"Too many requests"}}"#]
        )])
        let (events, failure) = await collect(client())
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(failure, .server(code: "rate_limited", message: "Too many requests"))
        XCTAssertEqual(StubProtocol.requestedPaths, ["/v1/preview/stream"])

        StubProtocol.reset(["/v1/preview/stream": .init(status: 400, contentType: "text/plain", chunks: ["nope"])])
        let unreadable = await collect(client())
        XCTAssertEqual(unreadable.failure, .server(code: "invalid_url", message: ""))
    }

    // MARK: - App key

    private let unauthorizedBody = #"{"error":{"code":"unauthorized","message":"This copy of the app can no longer use the service. Update SecureQR and try again."}}"#

    func testAppKeyIsSentToTheStreamEndpoint() async {
        StubProtocol.reset(["/v1/preview/stream": .init(chunks: [resultLine + "\n"])])
        let (_, failure) = await collect(client(apiKey: "test-key-1"))
        XCTAssertNil(failure)
        XCTAssertEqual(StubProtocol.requestedPaths, ["/v1/preview/stream"])
        XCTAssertEqual(sentKeys, ["test-key-1"])
    }

    func testAppKeyIsSentToBothEndpointsOnFallback() async {
        StubProtocol.reset([
            "/v1/preview/stream": .init(status: 404, contentType: "text/html", chunks: ["<html>Not found</html>"]),
            "/v1/preview": .init(contentType: "application/json", chunks: [resultJSON])
        ])
        let (_, failure) = await collect(client(apiKey: "test-key-1"))
        XCTAssertNil(failure)
        XCTAssertEqual(StubProtocol.requestedPaths, ["/v1/preview/stream", "/v1/preview"])
        XCTAssertEqual(sentKeys, ["test-key-1", "test-key-1"])
    }

    func testAppKeyIsSentToThePlainEndpoint() async throws {
        StubProtocol.reset(["/v1/preview": .init(contentType: "application/json", chunks: [resultJSON])])
        let result = try await client(apiKey: "test-key-1").preview(url: "https://qr-go.example/x7Pq")
        XCTAssertEqual(result.finalHost, "parcel-track.example")
        XCTAssertEqual(sentKeys, ["test-key-1"])
    }

    func testNoAppKeyHeaderWithoutAKey() async throws {
        StubProtocol.reset([
            "/v1/preview/stream": .init(status: 404, contentType: "text/html", chunks: ["<html>Not found</html>"]),
            "/v1/preview": .init(contentType: "application/json", chunks: [resultJSON])
        ])
        let (_, failure) = await collect(client(apiKey: ""))
        XCTAssertNil(failure)
        XCTAssertEqual(StubProtocol.requestedPaths, ["/v1/preview/stream", "/v1/preview"])
        XCTAssertEqual(sentKeys, [nil, nil])

        StubProtocol.reset(["/v1/preview": .init(contentType: "application/json", chunks: [resultJSON])])
        _ = try await client(apiKey: "").preview(url: "https://qr-go.example/x7Pq")
        XCTAssertEqual(sentKeys, [nil])
    }

    func testUnauthorizedOnTheStreamEndpointDoesNotFallBack() async {
        StubProtocol.reset([
            "/v1/preview/stream": .init(status: 401, contentType: "application/json", chunks: [unauthorizedBody]),
            "/v1/preview": .init(contentType: "application/json", chunks: [resultJSON])
        ])
        let (events, failure) = await collect(client(apiKey: "old-key"))
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(failure, .server(
            code: "unauthorized",
            message: "This copy of the app can no longer use the service. Update SecureQR and try again."
        ))
        XCTAssertEqual(failure?.isRetryable, false)
        XCTAssertEqual(failure?.title, "Update needed")
        XCTAssertEqual(StubProtocol.requestedPaths, ["/v1/preview/stream"])

        // Without a readable body the status alone decides.
        StubProtocol.reset([
            "/v1/preview/stream": .init(status: 401, contentType: "text/plain", chunks: ["no"]),
            "/v1/preview": .init(contentType: "application/json", chunks: [resultJSON])
        ])
        let bare = await collect(client(apiKey: "old-key"))
        XCTAssertEqual(bare.failure, .server(code: "unauthorized", message: ""))
        XCTAssertEqual(StubProtocol.requestedPaths, ["/v1/preview/stream"])
    }

    func testUnauthorizedOnThePlainEndpoint() async {
        StubProtocol.reset(["/v1/preview": .init(status: 401, contentType: "application/json", chunks: [unauthorizedBody])])
        do {
            _ = try await client().preview(url: "https://qr-go.example/x7Pq")
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? PreviewFailure, .server(
                code: "unauthorized",
                message: "This copy of the app can no longer use the service. Update SecureQR and try again."
            ))
        }
    }

    func testUnreachableServerIsOffline() async {
        StubProtocol.reset([:])
        let (events, failure) = await collect(client())
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(failure, .offline)
    }
}
