import NetworkExtension
import SwiftUI
import UIKit

/// Screen 5: the typed card for anything that is not a link. Everything
/// here was read on the phone; nothing is opened without a tap.
struct ContentScreen: View {
    let payload: ScannedPayload
    /// True when this is a past scan whose password or secret was not kept.
    let secretsRemoved: Bool

    @EnvironmentObject private var model: AppModel

    @State private var revealSecrets = false
    @State private var showRaw = false
    @State private var copiedAction: QRAction?
    @State private var showNoAppAlert = false
    @State private var showWiFiFailedAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.gap) {
                header
                if let instruction = payload.instruction {
                    instructionBanner(instruction)
                }
                if !payload.fields.isEmpty {
                    fieldsCard
                }
                noticeBanner
                actionButtons
                rawCard
            }
            .padding(Theme.screenPadding)
        }
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                Button(L("content.done")) { model.returnToScanner() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .brandedScreen()
        .alert(L("content.noApp.title"), isPresented: $showNoAppAlert) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(L("content.noApp.message"))
        }
        .alert(L("content.wifi.failed.title"), isPresented: $showWiFiFailedAlert) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(L("content.wifi.failed.message"))
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: payload.type.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(width: 30)
                .accessibilityHidden(true)
            Text(payload.providerTitle ?? payload.type.title)
                .font(AppFont.ui(24, .heavy, relativeTo: .title2))
                .foregroundColor(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.horizontal, 2)
    }

    /// What to do with this code: first on the card, and prominent.
    private func instructionBanner(_ message: QRNoticeMessage) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(Theme.accent)
                .accessibilityHidden(true)
            Text(message.text)
                .font(AppFont.ui(17, .bold, relativeTo: .headline))
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Theme.surface
                Theme.accent.opacity(0.10)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.accent, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var fieldsCard: some View {
        let fields = payload.fields
        return Card {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.offset) { item in
                    if item.offset > 0 {
                        Rectangle().fill(Theme.line).frame(height: 1)
                    }
                    FieldRow(field: item.element, revealSecrets: $revealSecrets)
                }
            }
        }
    }

    private var noticeBanner: some View {
        let notice = payload.notice
        var lines = notice.messages.map { $0.text }
        if secretsRemoved {
            lines.append(L("content.history.redacted"))
        }
        return Banner(
            tint: Theme.color(for: notice.level),
            symbolName: notice.level.symbolName,
            title: nil,
            lines: lines
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        let actions = payload.actions
        if !actions.isEmpty {
            VStack(spacing: 8) {
                ForEach(actions, id: \.rawValue) { action in
                    let label = HStack(spacing: 8) {
                        Image(systemName: copiedAction == action ? "checkmark" : action.symbolName)
                            .font(.system(size: 15, weight: .semibold))
                        Text(copiedAction == action ? L("content.copied") : action.title)
                    }
                    if action == .openInPaymentApp || (action == .joinWiFi && payload.notice.level == .neutral) {
                        Button { perform(action) } label: { label }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button { perform(action) } label: { label }
                            .buttonStyle(GhostButtonStyle(foreground: Theme.ink))
                    }
                }
            }
        }
    }

    private var rawCard: some View {
        Card {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRaw.toggle()
                }
            } label: {
                HStack {
                    CardLabel(text: L(showRaw ? "content.raw.hide" : "content.raw.show"))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .rotationEffect(.degrees(showRaw ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showRaw {
                Text(payload.redactedRaw)
                    .font(AppFont.mono(13))
                    .foregroundColor(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                if payload.containsSecret {
                    Text(L("content.raw.secretHidden"))
                        .font(AppFont.ui(13, .regular, relativeTo: .footnote))
                        .foregroundColor(Theme.muted)
                }
            }
        }
    }

    // MARK: - Actions

    private func perform(_ action: QRAction) {
        switch action {
        case .openInApp, .openInPaymentApp:
            openInApp()
        case .joinWiFi:
            if case .wifi(let network) = payload.content {
                joinWiFi(network)
            }
        case .copy:
            // Never the secret: see `ScannedPayload.copyText`.
            copy(payload.copyText, sensitive: false, action: action)
        case .copyAll:
            copy(allFieldsText(), sensitive: false, action: action)
        case .copyIBAN:
            if case .epc(let payment) = payload.content {
                copy(payment.iban, sensitive: false, action: action)
            }
        case .copyAddress:
            if case .crypto(let payment) = payload.content {
                copy(payment.address, sensitive: false, action: action)
            }
        case .copyPassword:
            if case .wifi(let network) = payload.content {
                copy(network.password, sensitive: true, action: action)
            }
        }
    }

    private func copy(_ text: String, sensitive: Bool, action: QRAction) {
        Clipboard.copy(text, sensitive: sensitive)
        Haptics.success()
        copiedAction = action
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if copiedAction == action {
                copiedAction = nil
            }
        }
    }

    private func allFieldsText() -> String {
        var lines: [String] = []
        for field in payload.fields {
            if let value = field.value.plainText(includingSecrets: false) {
                lines.append(field.label.title + ": " + value)
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Asks the system to join the scanned network. iOS shows its own
    /// "Wants to Join Wi-Fi Network" question first; saying no there is not
    /// an error.
    private func joinWiFi(_ network: WiFiNetwork) {
        let configuration: NEHotspotConfiguration
        if network.password.isEmpty {
            configuration = NEHotspotConfiguration(ssid: network.ssid)
        } else {
            let isWEP = network.security.trimmingCharacters(in: .whitespaces).uppercased() == "WEP"
            configuration = NEHotspotConfiguration(ssid: network.ssid, passphrase: network.password, isWEP: isWEP)
        }
        configuration.hidden = network.hidden ?? false
        NEHotspotConfigurationManager.shared.apply(configuration) { error in
            DispatchQueue.main.async {
                guard let error = error as NSError? else {
                    Haptics.success()
                    return
                }
                let quiet: [NEHotspotConfigurationError] = [.userDenied, .alreadyAssociated]
                if error.domain == NEHotspotConfigurationErrorDomain,
                   let code = NEHotspotConfigurationError(rawValue: error.code), quiet.contains(code) {
                    return
                }
                showWiFiFailedAlert = true
            }
        }
    }

    /// Hands the original scanned text, unchanged, to the system. If nothing
    /// handles it, say so.
    private func openInApp() {
        guard let url = URL(string: payload.raw) else {
            showNoAppAlert = true
            return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                showNoAppAlert = true
            }
        }
    }
}

private struct FieldRow: View {
    let field: QRField
    @Binding var revealSecrets: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CardLabel(text: field.label.title)
            valueView
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var valueView: some View {
        switch field.value {
        case .text(let value):
            Text(value)
                .font(AppFont.ui(17, .semibold, relativeTo: .body))
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .mono(let value):
            Text(value)
                .font(AppFont.mono(15, .medium))
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .secret(let value):
            HStack(alignment: .center, spacing: 8) {
                Text(revealSecrets ? value : String(repeating: "•", count: 10))
                    .font(AppFont.mono(15, .medium))
                    .foregroundColor(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    revealSecrets.toggle()
                } label: {
                    Image(systemName: revealSecrets ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L(revealSecrets ? "content.secret.hide" : "content.secret.show")))
            }
        case .yes:
            plain(L("common.yes"))
        case .no:
            plain(L("common.no"))
        case .none:
            plain(L("common.none"))
        }
    }

    private func plain(_ text: String) -> some View {
        Text(text)
            .font(AppFont.ui(17, .semibold, relativeTo: .body))
            .foregroundColor(Theme.ink)
    }
}
