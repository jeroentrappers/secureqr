import Foundation

/// Talks to the preview API (docs/api.md).
struct PreviewClient {
    static let timeout: TimeInterval = 45
    static let apiKeyHeader = "X-SecureQR-Key"

    let baseURL: URL
    let session: URLSession
    /// Sent with both preview requests when not empty. Never log it.
    private let apiKey: String

    /// `protocolClasses` lets tests answer the requests themselves.
    init(
        baseURL: URL = AppConfig.apiBaseURL,
        apiKey: String = AppConfig.apiKey,
        protocolClasses: [AnyClass]? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = PreviewClient.timeout
        configuration.timeoutIntervalForResource = PreviewClient.timeout
        configuration.waitsForConnectivity = false
        if let protocolClasses = protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        self.session = URLSession(configuration: configuration)
    }

    private struct PreviewRequest: Encodable {
        let url: String
    }

    private func request(path: String, url: String, accept: String, timeout: TimeInterval) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        // The server words its warnings and steps in the language the app is shown in.
        request.setValue(Bundle.main.preferredLocalizations.first ?? "en", forHTTPHeaderField: "Accept-Language")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: PreviewClient.apiKeyHeader)
        }
        do {
            request.httpBody = try JSONEncoder().encode(PreviewRequest(url: url))
        } catch {
            throw PreviewFailure.unexpected
        }
        return request
    }

    /// Asks the server to follow `url` and answers once, at the end.
    /// Throws a `PreviewFailure`.
    func preview(url: String, timeout: TimeInterval = PreviewClient.timeout) async throws -> PreviewResult {
        let request = try self.request(path: "v1/preview", url: url, accept: "application/json", timeout: timeout)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PreviewClient.failure(for: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PreviewFailure.unexpected
        }
        return try PreviewDecoding.decode(status: http.statusCode, data: data)
    }

    /// Asks the server to follow `url` and reports each check as it happens.
    /// The last event is `.result`; otherwise the stream throws a
    /// `PreviewFailure`. Dropping the stream cancels the request.
    func previewEvents(url: String) -> AsyncThrowingStream<PreviewEvent, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await streamedPreview(url: url) { continuation.yield($0) }
                    continuation.yield(.result(result))
                    continuation.finish()
                } catch let failure as PreviewFailure {
                    continuation.finish(throwing: failure)
                } catch {
                    continuation.finish(throwing: PreviewClient.failure(for: error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func streamedPreview(url: String, report: (PreviewEvent) -> Void) async throws -> PreviewResult {
        // One budget for the whole check, whichever endpoint answers.
        let deadline = Date().addingTimeInterval(PreviewClient.timeout)
        let request = try self.request(
            path: "v1/preview/stream", url: url, accept: "application/x-ndjson", timeout: PreviewClient.timeout
        )

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw PreviewClient.failure(for: error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw PreviewFailure.unexpected
        }

        if http.statusCode == 404 {
            // A server from before the step-by-step endpoint. Only a 404
            // means that: every other error (401 included) is final.
            bytes.task.cancel()
            report(.withoutSteps)
            return try await preview(url: url, timeout: max(deadline.timeIntervalSinceNow, 1))
        }

        do {
            guard (200...299).contains(http.statusCode) else {
                // An ordinary error response: {"error":{"code":…,"message":…}}.
                var data = Data()
                for try await byte in bytes {
                    data.append(byte)
                    if data.count >= PreviewClient.maxErrorBodySize { break }
                }
                return try PreviewDecoding.decode(status: http.statusCode, data: data)
            }

            for try await line in bytes.lines {
                switch PreviewStreamLine.parse(line) {
                case .event(.result(let result)):
                    return result
                case .event(let event):
                    report(event)
                case .failure(let failure):
                    throw failure
                case nil:
                    continue
                }
            }
        } catch let failure as PreviewFailure {
            throw failure
        } catch {
            throw PreviewClient.failure(for: error)
        }
        try Task.checkCancellation()
        // The connection ended without a result or an error line.
        throw PreviewFailure.offline
    }

    private static let maxErrorBodySize = 64 * 1024

    /// Absolute URL of a result's screenshot, if it has one.
    func screenshotURL(for result: PreviewResult) -> URL? {
        guard let path = result.screenshotUrl else { return nil }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    static func failure(for error: Error) -> PreviewFailure {
        if error is CancellationError {
            return .cancelled
        }
        guard let urlError = error as? URLError else {
            return .unexpected
        }
        switch urlError.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
             .secureConnectionFailed:
            return .offline
        default:
            return .unexpected
        }
    }
}
