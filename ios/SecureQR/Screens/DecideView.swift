import SwiftUI

/// Screen 3: verdict, screenshot, where the link ends, the hops, and the
/// two buttons.
struct DecideView: View {
    let result: PreviewResult
    let screenshotURL: URL?
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @State private var showHops = false
    @State private var showWholePage = false

    private static let bottomID = "decide.bottom"

    private var level: VerdictLevel {
        return result.verdict.level
    }

    private var tint: Color {
        return Theme.color(for: level)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.gap) {
                    Banner(
                        tint: tint,
                        symbolName: level.symbolName,
                        title: level.headline,
                        lines: result.verdict.reasons.map { $0.message }
                    )
                    if let minutes = result.minutesSinceChecked() {
                        Text(DecideView.checkedText(minutes: minutes))
                            .font(AppFont.ui(13.5, .regular, relativeTo: .footnote))
                            .foregroundColor(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.cardPadding)
                            .padding(.top, -4)
                    }
                    ScreenshotCard(result: result, screenshotURL: screenshotURL, showWholePage: $showWholePage)
                    landingCard
                    if !result.hops.isEmpty {
                        hopsCard
                    }
                    Color.clear.frame(height: 1).id(DecideView.bottomID)
                }
                .padding(Theme.screenPadding)
            }
            .onAppear {
                #if DEBUG
                // -showDetails YES: open the route and scroll down (screenshots).
                if UserDefaults.standard.bool(forKey: "showDetails") {
                    showHops = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        proxy.scrollTo(DecideView.bottomID, anchor: .bottom)
                    }
                }
                #endif
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                HStack(spacing: 8) {
                    if level == .ok {
                        Button(L("common.cancel"), action: onDismiss)
                            .buttonStyle(GhostButtonStyle())
                        Button(L("decide.open"), action: onOpen)
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button(L("decide.openAnyway"), action: onOpen)
                            .buttonStyle(GhostButtonStyle())
                        Button(L("decide.dontOpen"), action: onDismiss)
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - "You would land on"

    private var landingCard: some View {
        Card(label: L("decide.landOn")) {
            Text(DecideView.highlightedHost(result.finalHost, domain: result.finalDomain, tint: tint))
                .font(AppFont.mono(17, .semibold))
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if !result.title.isEmpty {
                Text(result.title)
                    .font(AppFont.ui(14.5, .regular, relativeTo: .subheadline))
                    .foregroundColor(Theme.muted)
                    .lineLimit(2)
            }
            ChipFlow(spacing: 6) {
                if result.https {
                    Chip(text: L("decide.chip.https"))
                } else {
                    Chip(text: L("decide.chip.notEncrypted"), tint: Theme.danger)
                }
                Chip(text: DecideView.redirectsText(result.redirectCount))
                switch result.reputationStatus {
                case .flagged:
                    Chip(text: L("decide.chip.blocklisted"), tint: Theme.danger)
                case .clean:
                    Chip(text: L("decide.chip.notBlocklisted"))
                case .unknown:
                    EmptyView()
                }
            }
            .padding(.top, 2)
        }
    }

    /// "Checked N min ago", for an answer the server reused.
    static func checkedText(minutes: Int) -> String {
        switch minutes {
        case 0: return L("decide.checked.now")
        case 1: return L("decide.checked.one")
        default: return LF("decide.checked.many", minutes)
        }
    }

    static func redirectsText(_ count: Int) -> String {
        switch count {
        case 0: return L("decide.chip.redirects.none")
        case 1: return L("decide.chip.redirects.one")
        default: return LF("decide.chip.redirects.many", count)
        }
    }

    /// The host with its registrable domain highlighted.
    static func highlightedHost(_ host: String, domain: String, tint: Color) -> AttributedString {
        var text = AttributedString(host)
        if !domain.isEmpty, let range = text.range(of: domain, options: .backwards) {
            text[range].backgroundColor = tint.opacity(0.3)
        }
        return text
    }

    // MARK: - Hops

    private var hopsCard: some View {
        Card {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHops.toggle()
                }
            } label: {
                HStack {
                    CardLabel(text: L(showHops ? "decide.hops.hide" : "decide.hops.show"))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .rotationEffect(.degrees(showHops ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showHops {
                VStack(spacing: 0) {
                    ForEach(Array(result.hops.enumerated()), id: \.offset) { item in
                        if item.offset > 0 {
                            Rectangle().fill(Theme.line).frame(height: 1)
                        }
                        HopRow(number: item.offset + 1, hop: item.element)
                    }
                }
            }
        }
    }
}

private struct HopRow: View {
    let number: Int
    let hop: Hop

    private var detail: String {
        if let status = hop.status {
            return hop.kind.title + " · " + String(status)
        }
        return hop.kind.title
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(number))
                .font(AppFont.mono(11, .bold))
                .foregroundColor(Theme.surface)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.ok))
            VStack(alignment: .leading, spacing: 2) {
                MonoText(text: hop.host.isEmpty ? hop.url : hop.host, size: 14)
                Text(detail)
                    .font(AppFont.ui(13, .regular, relativeTo: .footnote))
                    .foregroundColor(Theme.muted)
                Text(hop.url)
                    .font(AppFont.mono(11))
                    .foregroundColor(Theme.muted)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

/// The server's screenshot of the final page under a small browser strip.
private struct ScreenshotCard: View {
    let result: PreviewResult
    let screenshotURL: URL?
    @Binding var showWholePage: Bool

    /// Height of the collapsed screenshot: the top of the page.
    private let collapsedHeight: CGFloat = 300

    // The strip imitates a light browser bar in both appearances.
    private let chromeBackground = Color(red: 0.925, green: 0.933, blue: 0.949)
    private let chromeText = Color(red: 0.33, green: 0.33, blue: 0.33)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: result.https ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(result.finalHost)
                    .font(AppFont.mono(12))
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer(minLength: 0)
            }
            .foregroundColor(chromeText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(chromeBackground)

            if let screenshotURL = screenshotURL {
                AsyncImage(url: screenshotURL) { phase in
                    switch phase {
                    case .success(let image):
                        // 780 x 1688 px, scaled to the card's width. Collapsed,
                        // only the top of the page shows.
                        if showWholePage {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .pinchZoom()
                                .accessibilityLabel(Text(L("decide.screenshot.label")))
                        } else {
                            Color.clear
                                .frame(height: collapsedHeight)
                                .overlay(alignment: .top) {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                }
                                .clipped()
                                .pinchZoom()
                                .accessibilityLabel(Text(L("decide.screenshot.label")))
                        }
                        pageToggle
                    case .failure:
                        placeholder(text: L("decide.screenshot.failed"))
                    case .empty:
                        ZStack {
                            Theme.surface
                            ProgressView().tint(Theme.accent)
                        }
                        .frame(height: 220)
                    @unknown default:
                        placeholder(text: L("decide.screenshot.failed"))
                    }
                }
            } else {
                placeholder(text: L("decide.screenshot.none"))
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var pageToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showWholePage.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(L(showWholePage ? "decide.screenshot.less" : "decide.screenshot.more"))
                    .font(AppFont.ui(14.5, .semibold, relativeTo: .subheadline))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(showWholePage ? 180 : 0))
            }
            .foregroundColor(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    private func placeholder(text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 22))
                .foregroundColor(Theme.muted)
                .accessibilityHidden(true)
            Text(text)
                .font(AppFont.ui(14, .regular, relativeTo: .footnote))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}
