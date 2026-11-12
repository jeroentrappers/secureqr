package be.appmire.secureqr.qr

/** How a scanned Wi-Fi network is secured, as far as the system's "add network" question can take it. */
enum class WifiKind { OPEN, WPA2, WPA3, UNSUPPORTED }

/**
 * Maps the `T:` value of a Wi-Fi code (as shown on the card: upper case, empty
 * for none) to a [WifiKind]. `WPA` covers WPA and WPA2, as the codes in the
 * wild use it for both. WEP and company sign-in (EAP) are not supported.
 */
fun wifiKind(security: String, password: String): WifiKind {
    val value = security.trim().uppercase()
    return when {
        value.isEmpty() || value == "NOPASS" -> if (password.isEmpty()) WifiKind.OPEN else WifiKind.WPA2
        password.isEmpty() -> WifiKind.UNSUPPORTED
        value == "SAE" || value == "WPA3" -> WifiKind.WPA3
        value == "WPA" || value == "WPA2" || value == "WPA/WPA2" || value == "WPA2/WPA3" -> WifiKind.WPA2
        else -> WifiKind.UNSUPPORTED
    }
}
