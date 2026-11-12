import SwiftUI

@main
struct SecureQRApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.history)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack(path: $model.path) {
            ScannerScreen()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        // The scanner is full-bleed camera; everything else shows the status bar.
        .statusBarHidden(model.isScannerFrontmost)
        .onAppear {
            #if DEBUG
            DebugLaunch.apply(to: model)
            #endif
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .preview(let url, let historyID):
            PreviewScreen(url: url, historyID: historyID)
        case .content(let raw, let type, let secretsRemoved):
            ContentScreen(payload: QRClassifier.classify(stored: raw, as: type), secretsRemoved: secretsRemoved)
        case .history:
            HistoryScreen()
        #if DEBUG
        case .debugFonts:
            DebugFontsScreen()
        #endif
        }
    }
}
