package be.appmire.secureqr.qr

/**
 * Web hosts that belong to a payment app. A link to one of these (or to a
 * subdomain) is never sent to the preview server, because visiting it could
 * touch a payment session; it gets a payment card instead and is opened
 * unchanged so the installed app can claim it.
 *
 * This is the only place to add a provider. Keep it short: only hosts with a
 * confirmed, published link format belong here.
 */
object PaymentHosts {
    private val PROVIDERS: Map<String, String> = mapOf(
        "payconiq.com" to "Bancontact (Payconiq)",
    )

    /** The provider name when [url] is an http(s) link on a payment-app host, else null. */
    fun providerFor(url: String): String? {
        val host = hostOf(url)?.trimEnd('.') ?: return null
        return PROVIDERS.entries.firstOrNull { (domain, _) ->
            // The host itself or a real subdomain; "payconiq.com.evil.example" matches neither.
            host == domain || host.endsWith(".$domain")
        }?.value
    }
}
