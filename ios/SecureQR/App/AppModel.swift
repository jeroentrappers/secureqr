import Foundation
import Combine

enum Route: Hashable {
    /// The server preview flow for a link.
    case preview(url: URL, historyID: UUID?)
    /// The typed card for anything that is not a link.
    case content(raw: String, secretsRemoved: Bool)
    case history
    #if DEBUG
    case debugFonts
    #endif
}

/// Navigation and the pieces every screen shares. Use from the main thread.
final class AppModel: ObservableObject {
    @Published var path: [Route] = []

    let history: HistoryStore
    let client: PreviewClient

    init(history: HistoryStore = HistoryStore(), client: PreviewClient = PreviewClient()) {
        self.history = history
        self.client = client
    }

    /// True while the scanner is the visible screen.
    var isScannerFrontmost: Bool {
        return path.isEmpty
    }

    /// Classifies freshly scanned text, records it and shows the right screen.
    /// Nothing is opened here. Returns false for empty text.
    @discardableResult
    func handleScan(_ text: String) -> Bool {
        let payload = QRClassifier.classify(text)
        guard !payload.raw.isEmpty else { return false }
        let id = history.record(payload)
        path.append(route(for: payload, historyID: id, secretsRemoved: false))
        return true
    }

    /// Shows a past scan again. Links are checked again.
    func reopen(_ entry: HistoryEntry) {
        let payload = QRClassifier.classify(entry.payload)
        path.append(route(for: payload, historyID: entry.id, secretsRemoved: entry.redacted))
    }

    func showHistory() {
        path.append(.history)
    }

    func returnToScanner() {
        path.removeAll()
    }

    private func route(for payload: ScannedPayload, historyID: UUID?, secretsRemoved: Bool) -> Route {
        if case .url(let url) = payload.content {
            return .preview(url: url, historyID: historyID)
        }
        return .content(raw: payload.raw, secretsRemoved: secretsRemoved)
    }
}
