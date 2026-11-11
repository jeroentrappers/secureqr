import Foundation

/// Talks to the preview API (docs/api.md).
struct PreviewClient {
    static let timeout: TimeInterval = 45

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = PreviewClient.timeout
        configuration.timeoutIntervalForResource = PreviewClient.timeout
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    private struct PreviewRequest: Encodable {
        let url: String
    }

    /// Asks the server to follow `url`. Throws a `PreviewFailure`.
    func preview(url: String) async throws -> PreviewResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/preview"))
        request.httpMethod = "POST"
        request.timeoutInterval = PreviewClient.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try JSONEncoder().encode(PreviewRequest(url: url))
        } catch {
            throw PreviewFailure.unexpected
        }

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
