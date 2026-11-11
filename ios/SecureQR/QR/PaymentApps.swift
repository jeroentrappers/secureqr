import Foundation

/// Web links that belong to a payment app. They are never sent to the
/// server; the original link is handed to the system so that the installed
/// app takes it over. This table is the one place to add providers.
enum PaymentApps {
    static let providers: [(host: String, name: String)] = [
        ("payconiq.com", "Bancontact (Payconiq)")
    ]

    /// The provider for a host: the listed host itself or any subdomain of
    /// it, case-insensitive. `payconiq.com.evil.example` does not match.
    static func provider(forHost host: String) -> String? {
        var name = host.lowercased()
        while name.hasSuffix(".") {
            name.removeLast()
        }
        for provider in providers {
            if name == provider.host || name.hasSuffix("." + provider.host) {
                return provider.name
            }
        }
        return nil
    }

    /// Euro cents as written in a link (`1250`) to `12.50 EUR`; empty when
    /// the value is not a plain number.
    static func euros(fromCents text: String) -> String {
        let digits = QRText.trimmed(text)
        guard !digits.isEmpty, digits.count <= 12, digits.allSatisfy({ QRText.isASCIIDigit($0) }),
              let cents = Int(digits) else {
            return ""
        }
        let fraction = cents % 100
        return String(cents / 100) + "." + (fraction < 10 ? "0" : "") + String(fraction) + " EUR"
    }
}
