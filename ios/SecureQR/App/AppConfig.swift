import Foundation

enum AppConfig {
    static let productionBaseURL = URL(string: "https://qr.appmire.be")!

    /// Base URL of the preview API, from the `APIBaseURL` Info.plist key
    /// (build setting `API_BASE_URL`).
    static var apiBaseURL: URL {
        #if DEBUG
        // -apiBaseURL <url>: point a development build at another server.
        if let text = UserDefaults.standard.string(forKey: "apiBaseURL"),
           let url = URL(string: text), url.scheme != nil, url.host != nil {
            return url
        }
        #endif
        if let text = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
                return url
            }
        }
        return productionBaseURL
    }
}
