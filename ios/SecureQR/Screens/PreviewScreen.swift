import SwiftUI
import UIKit

/// The server preview flow for one link: checking, then the decision
/// screen or a failure screen. Nothing is opened without a tap.
struct PreviewScreen: View {
    let url: URL
    let historyID: UUID?

    @EnvironmentObject private var model: AppModel

    private enum Phase {
        case checking
        case result(PreviewResult)
        case failed(PreviewFailure)
    }

    @State private var phase: Phase = .checking
    @State private var attempt = 0

    var body: some View {
        Group {
            switch phase {
            case .checking:
                CheckingView(url: url)
            case .result(let result):
                DecideView(
                    result: result,
                    screenshotURL: model.client.screenshotURL(for: result),
                    onOpen: openLink,
                    onDismiss: { model.returnToScanner() }
                )
            case .failed(let failure):
                PreviewFailureView(
                    url: url,
                    failure: failure,
                    onRetry: retry,
                    onOpenAnyway: openLink,
                    onDismiss: { model.returnToScanner() }
                )
            }
        }
        .brandedScreen()
        .task(id: attempt) {
            await load()
        }
    }

    private func load() async {
        // Coming back to a finished result must not check the link again.
        if case .result = phase { return }
        phase = .checking
        do {
            let result = try await model.client.preview(url: url.absoluteString)
            if Task.isCancelled { return }
            if let historyID = historyID {
                model.history.setVerdict(result.verdict.level, for: historyID)
            }
            phase = .result(result)
            if result.verdict.level == .danger {
                Haptics.warning()
            }
        } catch let failure as PreviewFailure {
            if failure == .cancelled || Task.isCancelled { return }
            fail(with: failure)
        } catch {
            if Task.isCancelled { return }
            fail(with: .unexpected)
        }
    }

    /// The scan stays in history, marked as "could not be checked".
    private func fail(with failure: PreviewFailure) {
        if let historyID = historyID {
            model.history.markCheckFailed(for: historyID)
        }
        phase = .failed(failure)
    }

    private func retry() {
        phase = .checking
        attempt += 1
    }

    /// Opens the link that was scanned (not the final URL) in the system browser.
    private func openLink() {
        UIApplication.shared.open(url)
        model.returnToScanner()
    }
}

// MARK: - Screen 2: checking

struct CheckingView: View {
    let url: URL

    @State private var step = 0

    private var statusText: String {
        switch step {
        case 0: return L("checking.step.opening")
        case 1: return L("checking.step.following")
        default: return L("checking.step.screenshot")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.gap) {
                Card(label: L("checking.says")) {
                    MonoText(text: url.absoluteString)
                }
                Card(label: L("checking.following")) {
                    HStack(alignment: .top, spacing: 10) {
                        ProgressView()
                            .tint(Theme.accent)
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            MonoText(text: url.host ?? url.absoluteString, size: 14)
                            Text(statusText)
                                .font(AppFont.ui(13.5, .regular, relativeTo: .footnote))
                                .foregroundColor(Theme.muted)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text(L("checking.note"))
                    .font(AppFont.ui(14, .regular, relativeTo: .footnote))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .padding(Theme.screenPadding)
        }
        .task {
            // Cosmetic: the server answers once, at the end.
            while !Task.isCancelled && step < 2 {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if Task.isCancelled { return }
                step += 1
            }
        }
    }
}

// MARK: - Failure

struct PreviewFailureView: View {
    let url: URL
    let failure: PreviewFailure
    let onRetry: () -> Void
    let onOpenAnyway: () -> Void
    let onDismiss: () -> Void

    @State private var confirmOpen = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.gap) {
                Banner(
                    tint: Theme.warn,
                    symbolName: failure.symbolName,
                    title: failure.title,
                    lines: [failure.message]
                )
                Card(label: L("checking.says")) {
                    MonoText(text: url.absoluteString)
                }
                Text(L("failure.unchecked.note"))
                    .font(AppFont.ui(14, .regular, relativeTo: .footnote))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(Theme.screenPadding)
        }
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                if failure.isRetryable {
                    Button(L("failure.retry"), action: onRetry)
                        .buttonStyle(PrimaryButtonStyle())
                }
                HStack(spacing: 8) {
                    Button(L("decide.openAnyway")) { confirmOpen = true }
                        .buttonStyle(GhostButtonStyle())
                    if failure.isRetryable {
                        Button(L("decide.dontOpen"), action: onDismiss)
                            .buttonStyle(GhostButtonStyle(foreground: Theme.ink))
                    } else {
                        Button(L("decide.dontOpen"), action: onDismiss)
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
        .alert(L("failure.confirm.title"), isPresented: $confirmOpen) {
            Button(L("decide.openAnyway"), role: .destructive, action: onOpenAnyway)
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("failure.confirm.message"))
        }
    }
}
