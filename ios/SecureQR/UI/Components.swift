import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Logo

/// The check mark in the middle of the logo, on a 64 x 64 grid.
struct LogoCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 64
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            return CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        path.move(to: point(24.5, 32.5))
        path.addLine(to: point(30, 38))
        path.addLine(to: point(40, 27))
        return path
    }
}

/// Rounded blue square, white QR finder ring, white check (design/logo/mark.svg).
struct LogoMark: View {
    var size: CGFloat = 26

    var body: some View {
        let scale = size / 64
        ZStack {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .fill(Theme.brandBlue)
                .frame(width: 56 * scale, height: 56 * scale)
            RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
                .stroke(Color.white, lineWidth: 5 * scale)
                .frame(width: 34 * scale, height: 34 * scale)
            LogoCheckShape()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Mark plus wordmark: "Secure" in ink, "QR" in accent.
struct BrandBar: View {
    var ink: Color = Theme.ink
    var accent: Color = Theme.accent
    var markSize: CGFloat = 26
    var fontSize: CGFloat = 19

    var body: some View {
        HStack(spacing: 8) {
            LogoMark(size: markSize)
            (Text(verbatim: "Secure").foregroundColor(ink) + Text(verbatim: "QR").foregroundColor(accent))
                .font(AppFont.ui(fontSize, .heavy, relativeTo: .headline))
                .tracking(-0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "SecureQR"))
    }
}

// MARK: - Cards

/// Small uppercase monospace label used at the top of cards and rows.
struct CardLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.mono(11, .semibold))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundColor(Theme.muted)
    }
}

struct Card<Content: View>: View {
    var label: String?
    let content: Content

    init(label: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                CardLabel(text: label)
            }
            content
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }
}

/// A link or other identifier, in monospace, wrapping anywhere.
struct MonoText: View {
    let text: String
    var size: CGFloat = 15
    var weight: Font.Weight = .regular

    var body: some View {
        Text(text)
            .font(AppFont.mono(size, weight))
            .foregroundColor(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Banner

/// Verdict / notice banner: tint at 15 % over the surface, 1 px tinted border.
struct Banner: View {
    let tint: Color
    let symbolName: String
    var title: String?
    var lines: [String] = []

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 26)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let title = title {
                    Text(title)
                        .font(AppFont.ui(17, .bold, relativeTo: .headline))
                        .foregroundColor(Theme.ink)
                }
                ForEach(Array(lines.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(AppFont.ui(14.5, title == nil && item.offset == 0 ? .semibold : .regular, relativeTo: .subheadline))
                        .foregroundColor(Theme.ink.opacity(title == nil && item.offset == 0 ? 1 : 0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Theme.surface
                tint.opacity(0.15)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(tint, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chips

struct Chip: View {
    let text: String
    /// Nil for the neutral style.
    var tint: Color?

    var body: some View {
        Text(text)
            .font(AppFont.mono(11, .semibold))
            .foregroundColor(tint ?? Theme.muted)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule().fill((tint ?? Color.clear).opacity(tint == nil ? 0 : 0.12))
            )
            .overlay(
                Capsule().stroke(tint ?? Theme.line, lineWidth: 1)
            )
    }
}

/// Lays chips out left to right and wraps to the next line when needed.
struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? CGFloat.greatestFiniteMagnitude
        return arrange(subviews: subviews, width: width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let result = arrange(subviews: subviews, width: bounds.width)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: ProposedViewSize.unspecified
            )
        }
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return (CGSize(width: usedWidth, height: y + rowHeight), origins)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(17, .bold, relativeTo: .headline))
            .foregroundColor(Theme.onAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var foreground: Color = Theme.muted

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(17, .bold, relativeTo: .headline))
            .foregroundColor(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Screen chrome

/// Background, inline navigation bar and wordmark shared by every screen
/// except the scanner.
struct BrandedScreen: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandBar()
                }
            }
    }
}

extension View {
    func brandedScreen() -> some View {
        return modifier(BrandedScreen())
    }
}

/// Bottom button area that stays above the home indicator.
struct BottomBar<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

// MARK: - Clipboard and haptics

enum Clipboard {
    /// Sensitive text stays on this device and leaves the clipboard after two minutes.
    static func copy(_ text: String, sensitive: Bool = false) {
        if sensitive {
            UIPasteboard.general.setItems(
                [[UTType.utf8PlainText.identifier: text]],
                options: [
                    .localOnly: true,
                    .expirationDate: Date().addingTimeInterval(120)
                ]
            )
        } else {
            UIPasteboard.general.string = text
        }
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
