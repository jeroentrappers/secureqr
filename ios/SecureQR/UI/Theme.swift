import CoreText
import SwiftUI
import UIKit

/// Brand colours from design/brand.md (direction B, "Clear").
struct Palette {
    let bg: UIColor
    let surface: UIColor
    let line: UIColor
    let ink: UIColor
    let muted: UIColor
    let accent: UIColor
    let onAccent: UIColor
    let ok: UIColor
    let warn: UIColor
    let danger: UIColor

    static let light = Palette(
        bg: UIColor(hex: 0xF5F7FB),
        surface: UIColor(hex: 0xFFFFFF),
        line: UIColor(hex: 0xE1E6F0),
        ink: UIColor(hex: 0x111933),
        muted: UIColor(hex: 0x5F6B85),
        accent: UIColor(hex: 0x3B5BFF),
        onAccent: UIColor(hex: 0xFFFFFF),
        ok: UIColor(hex: 0x0E9F6E),
        warn: UIColor(hex: 0xC77700),
        danger: UIColor(hex: 0xD92D3A)
    )

    static let dark = Palette(
        bg: UIColor(hex: 0x0E1324),
        surface: UIColor(hex: 0x171D33),
        line: UIColor(hex: 0x29314D),
        ink: UIColor(hex: 0xEEF1FA),
        muted: UIColor(hex: 0x9AA5C0),
        accent: UIColor(hex: 0x6B84FF),
        onAccent: UIColor(hex: 0x0B1020),
        ok: UIColor(hex: 0x34C38F),
        warn: UIColor(hex: 0xF0A93B),
        danger: UIColor(hex: 0xF2616B)
    )
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Colour tokens that follow the system light/dark setting, plus metrics.
enum Theme {
    private static func dynamic(_ keyPath: KeyPath<Palette, UIColor>) -> Color {
        return Color(uiColor: UIColor { traits in
            let palette = traits.userInterfaceStyle == .dark ? Palette.dark : Palette.light
            return palette[keyPath: keyPath]
        })
    }

    static let bg = dynamic(\.bg)
    static let surface = dynamic(\.surface)
    static let line = dynamic(\.line)
    static let ink = dynamic(\.ink)
    static let muted = dynamic(\.muted)
    static let accent = dynamic(\.accent)
    static let onAccent = dynamic(\.onAccent)
    static let ok = dynamic(\.ok)
    static let warn = dynamic(\.warn)
    static let danger = dynamic(\.danger)

    /// The logo keeps its blue in both appearances.
    static let brandBlue = Color(uiColor: Palette.light.accent)

    /// The scanner is always dark, whatever the system setting.
    enum Scanner {
        static let accent = Color(uiColor: Palette.dark.accent)
        static let onAccent = Color(uiColor: Palette.dark.onAccent)
        static let background = Color(uiColor: Palette.dark.bg)
        static let text = Color.white
        static let secondaryText = Color.white.opacity(0.75)
        static let control = Color.white.opacity(0.14)
        static let pill = Color.black.opacity(0.6)
    }

    static let radius: CGFloat = 22
    static let screenPadding: CGFloat = 16
    static let cardPadding: CGFloat = 14
    static let gap: CGFloat = 12

    static func color(for level: VerdictLevel) -> Color {
        switch level {
        case .ok: return ok
        case .caution: return warn
        case .danger: return danger
        }
    }

    static func color(for level: QRNoticeLevel) -> Color {
        switch level {
        case .neutral: return muted
        case .caution: return warn
        case .danger: return danger
        }
    }
}

/// Nunito Sans for the interface, system monospace for identifiers.
enum AppFont {
    static let family = "Nunito Sans"

    /// PostScript name of one face of the bundled variable font, or nil when
    /// the font did not register; the system rounded font is used then.
    private static let baseFontName: String? = UIFont.fontNames(forFamilyName: family).first

    static var isBundledFontAvailable: Bool {
        return baseFontName != nil
    }

    /// The font's weight axis, 'wght' as a four-character code.
    private static let weightAxis = 0x77676874

    /// Position on the weight axis (the font covers 200 to 1000).
    static func axisValue(for weight: Font.Weight) -> CGFloat {
        switch weight {
        case .ultraLight, .thin: return 200
        case .light: return 300
        case .regular: return 400
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 700
        case .heavy: return 800
        case .black: return 900
        default: return 400
        }
    }

    /// Name suffix of the font's named instance for a weight.
    private static func instanceSuffix(for weight: Font.Weight) -> String {
        if weight == .regular { return "_Regular" }
        if weight == .medium { return "_Medium" }
        if weight == .semibold { return "_SemiBold" }
        if weight == .bold { return "_Bold" }
        if weight == .heavy { return "_ExtraBold" }
        if weight == .black { return "_Black" }
        if weight == .light { return "_Light" }
        return "_Regular"
    }

    /// The bundled font at an exact weight. `Font.weight(_:)` does not move a
    /// variable font's weight axis reliably, so the font's named instance for
    /// that weight is used, with the axis set explicitly as a fallback.
    static func uiFont(_ size: CGFloat, _ weight: Font.Weight, textStyle: UIFont.TextStyle) -> UIFont? {
        guard let baseName = baseFontName else { return nil }
        let metrics = UIFontMetrics(forTextStyle: textStyle)

        let suffix = instanceSuffix(for: weight)
        if let name = instanceNames.first(where: { $0.hasSuffix(suffix) }),
           let font = UIFont(name: name, size: size) {
            return metrics.scaledFont(for: font)
        }

        guard let base = UIFont(name: baseName, size: size) else { return nil }
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [weightAxis: axisValue(for: weight)]
        ])
        return metrics.scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }

    private static let instanceNames: [String] = UIFont.fontNames(forFamilyName: family)

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        if let font = uiFont(size, weight, textStyle: uiTextStyle(style)) {
            return Font(font as CTFont)
        }
        return Font.system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .monospaced)
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}
