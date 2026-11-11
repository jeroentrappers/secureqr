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
    @State private var progress = PreviewProgress()
    /// True when the server cannot report steps (an older server).
    @State private var withoutSteps = false

    var body: some View {
        Group {
            switch phase {
            case .checking:
                CheckingView(url: url, progress: progress, withoutSteps: withoutSteps)
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
        progress = PreviewProgress()
        withoutSteps = false
        do {
            // Leaving the screen cancels this task, which ends the stream
            // and with it the request.
            for try await event in model.client.previewEvents(url: url.absoluteString) {
                if Task.isCancelled { return }
                switch event {
                case .step, .hop:
                    withAnimation(.easeOut(duration: 0.25)) {
                        progress.apply(event)
                    }
                case .withoutSteps:
                    withoutSteps = true
                case .result(let result):
                    finish(with: result)
                    return
                }
            }
            if Task.isCancelled { return }
            fail(with: .offline)
        } catch let failure as PreviewFailure {
            if failure == .cancelled || Task.isCancelled { return }
            fail(with: failure)
        } catch {
            if Task.isCancelled { return }
            fail(with: .unexpected)
        }
    }

    private func finish(with result: PreviewResult) {
        if let historyID = historyID {
            model.history.setVerdict(result.verdict.level, for: historyID)
        }
        phase = .result(result)
        if result.verdict.level == .danger {
            Haptics.warning()
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
    var progress = PreviewProgress()
    /// Show the plain "busy" state: the server does not report steps.
    var withoutSteps = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.gap) {
                Card(label: L("checking.says")) {
                    MonoText(text: url.absoluteString)
                }
                Card(label: L("checking.following")) {
                    if withoutSteps {
                        CheckingBusyRow(url: url)
                    } else {
                        CheckingSteps(progress: progress)
                    }
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
    }
}

/// The checks the server reports, one row each, in order of arrival.
private struct CheckingSteps: View {
    let progress: PreviewProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if progress.isEmpty {
                CheckingStepRow(
                    step: PreviewStep(id: "contacting", state: .active, label: L("checking.contacting")),
                    hosts: []
                )
            } else {
                ForEach(progress.steps) { step in
                    CheckingStepRow(
                        step: step,
                        hosts: step.id == PreviewProgress.redirectsStepID ? progress.hosts : []
                    )
                    .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

private struct CheckingStepRow: View {
    let step: PreviewStep
    /// Sites passed through so far; only under the redirects step.
    let hosts: [String]

    private static let iconSize: CGFloat = 20

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                if step.state == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.ok)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.accent)
                        .transition(.opacity)
                }
            }
            .frame(width: CheckingStepRow.iconSize, height: CheckingStepRow.iconSize)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.label)
                    .font(AppFont.ui(15, step.state == .done ? .regular : .semibold, relativeTo: .subheadline))
                    .foregroundColor(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: CheckingStepRow.iconSize, alignment: .center)
                ForEach(Array(hosts.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(AppFont.mono(12))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(L(step.state == .done ? "checking.step.done" : "checking.step.active"))
    }
}

/// Shown when the server answers only once, at the end.
private struct CheckingBusyRow: View {
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
        .task {
            // Cosmetic: this server answers once, at the end.
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
