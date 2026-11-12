package be.appmire.secureqr.qr

/**
 * Removes secrets from a payload before it is stored or shown as raw text:
 * the `secret` of an `otpauth://` URI, the password of a Wi-Fi code, and
 * nearly all of a sign-in code, authenticator export, eSIM plan, smart-home
 * setup code or health certificate.
 */
object Redaction {

    fun hasSecret(content: QrContent): Boolean = redact(content) != content.raw

    fun redact(content: QrContent): String = when (content.type) {
        QrType.OTP -> redactOtp(content.raw)
        QrType.WIFI -> redactWifi(content.raw)
        else -> SpecialCodes.redact(content.type, content.raw)
    }

    private fun redactOtp(raw: String): String {
        val q = raw.indexOf('?')
        if (q < 0) return raw
        val kept = raw.substring(q + 1).split('&').filterNot {
            percentDecode(it.substringBefore('=')).trim().equals("secret", ignoreCase = true)
        }
        return raw.substring(0, q) + if (kept.isEmpty()) "" else "?" + kept.joinToString("&")
    }

    private fun redactWifi(raw: String): String {
        val prefix = raw.substring(0, "WIFI:".length)
        val kept = splitUnescaped(raw.substring(prefix.length), ';').filterNot {
            it.substringBefore(':').trim().equals("P", ignoreCase = true) && ':' in it
        }
        return prefix + kept.joinToString(";")
    }
}
