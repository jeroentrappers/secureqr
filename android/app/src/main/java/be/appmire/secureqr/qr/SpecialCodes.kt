package be.appmire.secureqr.qr

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Codes that need a warning or a card of their own rather than the generic
 * link or app-link treatment: sign-in codes of chat and game services, chat
 * links, links that must not be opened, eSIM plans, smart-home setup codes,
 * health certificates, authenticator exports and two more bank-transfer
 * formats. See docs/qr-types.md. Plain Kotlin, no platform dependencies.
 */
internal object SpecialCodes {

    private fun field(label: FieldLabel, value: String?, style: FieldStyle = FieldStyle.PLAIN): QrField? {
        val v = value?.trim().orEmpty()
        return if (v.isEmpty()) null else QrField(label, v, style)
    }

    private fun String.has(prefix: String) = startsWith(prefix, ignoreCase = true)

    private fun hostMatches(host: String, domain: String) = host == domain || host.endsWith(".$domain")

    /** Host, path and query of an http(s) link; null for anything else. */
    private class Web(val host: String, val path: String, val query: UriParts)

    private val WEB = Regex("^https?://(?:[^/?#@]*@)?([^/?#:]*)(?::\\d*)?([^?#]*)(\\?[^#]*)?", RegexOption.IGNORE_CASE)

    private fun web(text: String): Web? {
        val m = WEB.find(text) ?: return null
        val host = m.groupValues[1].lowercase().trimEnd('.')
        if (host.isEmpty()) return null
        return Web(host, m.groupValues[2], splitUri(m.groupValues[3], plusAsSpace = true))
    }

    // ---- sign-in codes of other services -----------------------------------

    private class LoginHost(val domain: String, val path: String, val service: String)

    private val LOGIN_HOSTS = listOf(
        LoginHost("discord.com", "/ra/", "Discord"),
        LoginHost("discordapp.com", "/ra/", "Discord"),
        LoginHost("s.team", "/q/", "Steam"),
        LoginHost("login.weixin.qq.com", "/l/", "WeChat"),
    )
    private val LOGIN_SCHEMES = listOf(
        "tg://login" to "Telegram",
        "sgnl://linkdevice" to "Signal",
        "tsdevice:" to "Signal",
    )
    private val WHATSAPP_LOGIN = Regex("^[12]@[A-Za-z0-9+/=_-]{16,}(,[A-Za-z0-9+/=_-]{16,}){2,}$")

    /** What is kept of a WhatsApp sign-in code; it still classifies as one. */
    private const val WHATSAPP_REDACTED = "2@…"

    private fun loginHost(text: String): LoginHost? {
        val web = web(text) ?: return null
        return LOGIN_HOSTS.firstOrNull { hostMatches(web.host, it.domain) && web.path.has(it.path) }
    }

    fun login(text: String): QrContent? {
        val service = loginHost(text)?.service
            ?: LOGIN_SCHEMES.firstOrNull { text.has(it.first) }?.second
            ?: "WhatsApp".takeIf { text == WHATSAPP_REDACTED || WHATSAPP_LOGIN.matches(text) }
            ?: return null
        return QrContent(
            type = QrType.LOGIN,
            raw = text,
            fields = listOfNotNull(field(FieldLabel.SERVICE, service)),
            notices = listOf(Notice.LOGIN_CODE),
            // Never opened, never copied: the code is a live session.
            actions = emptyList(),
        )
    }

    // ---- chat links --------------------------------------------------------

    private fun number(value: String?): String? {
        val digits = value.orEmpty().filter { it in '0'..'9' }
        return if (digits.isEmpty()) null else "+$digits"
    }

    private fun telegramHandle(segment: String?): String? = when {
        segment.isNullOrEmpty() -> null
        segment.startsWith("+") || segment.equals("joinchat", true) -> INVITE
        else -> "@" + segment.removePrefix("@")
    }

    /** Symbolic handle for a group invite; the UI supplies the wording. */
    const val INVITE = "invite"

    fun chat(text: String): QrContent? {
        var service: String? = null
        var number: String? = null
        var handle: String? = null
        var message: String? = null

        val web = web(text)
        if (web != null) {
            val segment = percentDecode(web.path.trim('/').substringBefore('/'))
            when {
                hostMatches(web.host, "wa.me") -> {
                    service = "WhatsApp"
                    number = number(segment)
                }
                hostMatches(web.host, "api.whatsapp.com") && web.path.has("/send") -> {
                    service = "WhatsApp"
                    number = number(web.query["phone"])
                }
                hostMatches(web.host, "t.me") || hostMatches(web.host, "telegram.me") -> {
                    service = "Telegram"
                    handle = telegramHandle(segment)
                }
                hostMatches(web.host, "m.me") -> {
                    service = "Messenger"
                    handle = segment.takeIf { it.isNotEmpty() }
                }
                hostMatches(web.host, "signal.me") -> service = "Signal"
            }
            message = web.query["text"]
        } else {
            val scheme = listOf("whatsapp://send", "tg://resolve", "viber://chat", "viber://add").firstOrNull { text.has(it) }
            if (scheme != null) {
                val uri = splitUri(text.substring(scheme.length), plusAsSpace = true)
                when (scheme) {
                    "whatsapp://send" -> {
                        service = "WhatsApp"
                        number = number(uri["phone"])
                    }
                    "tg://resolve" -> {
                        service = "Telegram"
                        handle = telegramHandle(uri["domain"])
                    }
                    else -> {
                        service = "Viber"
                        number = number(uri["number"])
                    }
                }
                message = uri["text"]
            }
        }
        if (service == null) return null

        return QrContent(
            type = QrType.CHAT,
            raw = text,
            fields = listOfNotNull(
                field(FieldLabel.SERVICE, service),
                field(FieldLabel.NUMBER, number, FieldStyle.MONO),
                field(FieldLabel.HANDLE, handle, FieldStyle.MONO),
                field(FieldLabel.MESSAGE, message),
            ),
            notices = listOf(Notice.CHAT_LINK),
            actions = listOf(QrAction.OPEN_IN_APP, QrAction.COPY),
        )
    }

    // ---- links that must not be opened -------------------------------------

    private val UNSAFE_SCHEMES = setOf(
        "javascript", "data", "vbscript", "file", "blob", "content",
        "intent", "android-app", "chrome", "about", "view-source", "jar",
    )
    private val SCHEME = Regex("^([a-z][a-z0-9+.-]*):", RegexOption.IGNORE_CASE)

    fun unsafe(text: String): QrContent? {
        val scheme = SCHEME.find(text)?.groupValues?.get(1)?.lowercase() ?: return null
        if (scheme !in UNSAFE_SCHEMES) return null
        return QrContent(
            type = QrType.UNSAFE,
            raw = text,
            fields = listOfNotNull(
                field(FieldLabel.SCHEME, scheme, FieldStyle.MONO),
                field(FieldLabel.TEXT, text, FieldStyle.MONO),
            ),
            notices = listOf(Notice.UNSAFE_LINK),
            actions = listOf(QrAction.COPY),
        )
    }

    // ---- phone numbers -----------------------------------------------------

    private val PREMIUM = listOf(
        Regex("^(\\+|00)(32|31|49|43|41)90\\d"),
        Regex("^090\\d"),
        Regex("^(\\+|00)449\\d"),
        Regex("^09[018]\\d"),
        Regex("^(\\+?1)?900\\d{7}$"),
    )

    /** A code with `*` or `#` is handled by the phone itself (call forwarding, settings). */
    fun isServiceCode(number: String) = '*' in number || '#' in number

    fun isPremiumNumber(number: String): Boolean {
        val compact = number.filterNot { it in " -.()" }
        return PREMIUM.any { it.containsMatchIn(compact) }
    }

    // ---- bank transfers besides EPC ----------------------------------------

    private fun transfer(
        type: QrType,
        text: String,
        name: String?,
        iban: String,
        amount: String?,
        reference: String?,
        message: String?,
    ): QrContent {
        val compact = iban.filterNot { it.isWhitespace() }.uppercase()
        return QrContent(
            type = type,
            raw = text,
            fields = listOfNotNull(
                field(FieldLabel.BENEFICIARY, name),
                if (compact.isEmpty()) null else QrField(FieldLabel.IBAN, Iban.grouped(compact), FieldStyle.MONO, copyValue = compact),
                field(FieldLabel.AMOUNT, amount),
                field(FieldLabel.REFERENCE, reference, FieldStyle.MONO),
                field(FieldLabel.MESSAGE, message),
            ),
            notices = listOfNotNull(
                Notice.EPC_INSTRUCTION,
                if (Iban.isValid(compact)) null else Notice.INVALID_IBAN,
                Notice.PAYMENT,
            ),
            actions = listOf(QrAction.COPY_IBAN, QrAction.COPY_ALL),
        )
    }

    private fun amount(value: String?, currency: String?): String? {
        val v = value?.trim().orEmpty()
        if (v.isEmpty()) return null
        return listOf(v, currency?.trim()?.uppercase().orEmpty()).filter { it.isNotEmpty() }.joinToString(" ")
    }

    /** Swiss QR-bill: one value per line, positions fixed by the standard. */
    fun swissQr(text: String, lines: List<String>): QrContent {
        fun line(i: Int) = lines.getOrNull(i)?.trim().orEmpty()
        return transfer(
            QrType.SWISSQR, text,
            name = line(5),
            iban = line(3),
            amount = amount(line(18), line(19)),
            reference = line(28),
            message = line(29),
        )
    }

    /** Czech payment code: `SPD*1.0*KEY:value*KEY:value`. */
    fun spd(text: String): QrContent {
        val values = text.split('*').drop(1).mapNotNull { item ->
            val colon = item.indexOf(':')
            if (colon <= 0) null else item.substring(0, colon).trim().uppercase() to percentDecode(item.substring(colon + 1))
        }.toMap()
        return transfer(
            QrType.SPD, text,
            name = values["RN"],
            iban = values["ACC"].orEmpty().substringBefore('+'),
            amount = amount(values["AM"], values["CC"]),
            reference = values["X-VS"],
            message = values["MSG"],
        )
    }

    // ---- codes that are only explained -------------------------------------

    fun otpExport(text: String) = QrContent(
        type = QrType.OTP_EXPORT,
        raw = text,
        notices = listOf(Notice.OTP_EXPORT),
    )

    /** `LPA:1$<address>$<activation code>[$…]`. */
    fun esim(text: String): QrContent {
        val parts = text.substring("LPA:".length).split('$')
        return QrContent(
            type = QrType.ESIM,
            raw = text,
            fields = listOfNotNull(
                field(FieldLabel.ADDRESS, parts.getOrNull(1), FieldStyle.MONO),
                field(FieldLabel.ACTIVATION_CODE, parts.getOrNull(2), FieldStyle.SECRET),
            ),
            notices = listOf(Notice.ESIM_INSTRUCTION, Notice.ESIM),
            actions = listOf(QrAction.COPY),
        )
    }

    private val DEVICE_PREFIXES = listOf("MT:" to "Matter", "X-HM://" to "HomeKit", "DPP:" to "Wi-Fi Easy Connect")
    private val HEALTH_PREFIXES = listOf("HC1:", "shc:/")

    fun device(text: String): QrContent? {
        val standard = DEVICE_PREFIXES.firstOrNull { text.has(it.first) }?.second ?: return null
        return QrContent(
            type = QrType.DEVICE,
            raw = text,
            fields = listOfNotNull(field(FieldLabel.TYPE, standard)),
            notices = listOf(Notice.DEVICE_SETUP),
        )
    }

    fun healthCert(text: String): QrContent? {
        if (HEALTH_PREFIXES.none { text.has(it) }) return null
        return QrContent(type = QrType.HEALTHCERT, raw = text, notices = listOf(Notice.HEALTH_CERT))
    }

    // ---- what is kept in history and shown as raw text ---------------------

    /**
     * The part of [raw] that holds no secret, ending in `…`. What is kept
     * still classifies as the same type, so a history entry reopens as the
     * same card.
     */
    fun redact(type: QrType, raw: String): String {
        fun keep(length: Int) = raw.substring(0, length.coerceAtMost(raw.length)) + "…"
        return when (type) {
            QrType.LOGIN -> {
                val host = loginHost(raw)
                val scheme = LOGIN_SCHEMES.firstOrNull { raw.has(it.first) }?.first
                when {
                    host != null -> keep(raw.indexOf(host.path, ignoreCase = true) + host.path.length)
                    scheme != null -> keep(scheme.length)
                    else -> WHATSAPP_REDACTED
                }
            }
            QrType.OTP_EXPORT -> keep("otpauth-migration://".length)
            QrType.ESIM -> {
                val parts = raw.split('$')
                if (parts.size < 3) raw else parts.take(2).joinToString("$") + "$…"
            }
            QrType.DEVICE -> keep(DEVICE_PREFIXES.first { raw.has(it.first) }.first.length)
            QrType.HEALTHCERT -> keep(HEALTH_PREFIXES.first { raw.has(it) }.length)
            else -> raw
        }
    }

    // ---- calendar dates ----------------------------------------------------

    /** Start and end of an event in epoch milliseconds, as the system calendar wants them. */
    class EventTimes(val start: Long, val end: Long, val allDay: Boolean)

    private val ICAL_DATE = Regex("^(\\d{4})(\\d{2})(\\d{2})(?:T(\\d{2})(\\d{2})(\\d{2})?(Z)?)?$")

    private fun instant(value: String?, zone: ZoneId): Pair<Long, Boolean>? {
        val m = ICAL_DATE.find(value?.trim().orEmpty()) ?: return null
        val (year, month, day, hour, minute, second, utc) = m.destructured
        return try {
            val date = LocalDate.of(year.toInt(), month.toInt(), day.toInt())
            if (hour.isEmpty()) {
                // All-day events are stored at midnight UTC.
                date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() to true
            } else {
                val time = LocalDateTime.of(date.year, date.month, date.dayOfMonth, hour.toInt(), minute.toInt(), second.ifEmpty { "0" }.toInt())
                time.atZone(if (utc.isNotEmpty()) ZoneOffset.UTC else zone).toInstant().toEpochMilli() to false
            }
        } catch (e: RuntimeException) {
            // 20261340 and the like.
            null
        }
    }

    /** Null when the start does not parse. Without a usable end: one hour, or one day for an all-day event. */
    fun eventTimes(start: String?, end: String?, zone: ZoneId = ZoneId.systemDefault()): EventTimes? {
        val (startMillis, allDay) = instant(start, zone) ?: return null
        val fallback = startMillis + if (allDay) 24 * 3_600_000L else 3_600_000L
        val endMillis = instant(end, zone)?.first?.takeIf { it > startMillis } ?: fallback
        return EventTimes(startMillis, endMillis, allDay)
    }
}
