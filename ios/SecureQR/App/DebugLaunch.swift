#if DEBUG
import CoreText
import SwiftUI
import UIKit

/// Launch arguments for development builds only (see README). The simulator
/// has no camera, so these stand in for a scan. Not compiled into Release.
///
///   -scanPayload <text>   behave as if <text> had just been scanned
///                         (write \n for a line break)
///   -showScreen history   open the history screen
///   -showScreen fonts     show the interface font at each weight
///   -showDetails YES      on the decision screen, open the route and scroll
///                         to the bottom (read in DecideView)
///   -apiBaseURL <url>     use another preview server (read in AppConfig)
enum DebugLaunch {
    private static var applied = false

    static func apply(to model: AppModel) {
        guard !applied else { return }
        applied = true

        let defaults = UserDefaults.standard
        if let payload = defaults.string(forKey: "scanPayload"), !payload.isEmpty {
            model.handleScan(payload.replacingOccurrences(of: "\\n", with: "\n"))
        } else if defaults.string(forKey: "showScreen") == "history" {
            model.showHistory()
        } else if defaults.string(forKey: "showScreen") == "fonts" {
            model.path.append(.debugFonts)
        }
    }
}

/// The interface font at the four weights the design uses.
struct DebugFontsScreen: View {
    private let samples: [(String, Font.Weight)] = [
        ("400 regular", .regular), ("600 semibold", .semibold),
        ("700 bold", .bold), ("800 heavy", .heavy)
    ]

    private static var report: String {
        var lines = UIFont.fontNames(forFamilyName: AppFont.family)
        for sample in [Font.Weight.regular, .semibold, .bold, .heavy] {
            if let font = AppFont.uiFont(22, sample, textStyle: .body) {
                let variation = CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber] ?? [:]
                lines.append(String(describing: AppFont.axisValue(for: sample)) + " " + font.fontName + " " + variation.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " "))
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(samples, id: \.0) { sample in
                    VStack(alignment: .leading, spacing: 2) {
                        CardLabel(text: sample.0)
                        Text(verbatim: "See where it goes before you go")
                            .font(AppFont.ui(22, sample.1))
                            .foregroundColor(Theme.ink)
                    }
                }
                CardLabel(text: AppFont.isBundledFontAvailable ? "Nunito Sans" : "system font (fallback)")
                Text(verbatim: DebugFontsScreen.report)
                    .font(AppFont.mono(10))
                    .foregroundColor(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.screenPadding)
        }
        .brandedScreen()
    }
}
#endif
