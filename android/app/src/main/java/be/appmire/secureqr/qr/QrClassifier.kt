package be.appmire.secureqr.qr

/**
 * Classifies scanned QR text and parses it into a typed card.
 * Plain Kotlin: no platform dependencies, so it runs in JVM unit tests.
 */
object QrClassifier {

    private val CRYPTO_NETWORKS = linkedMapOf(
        "bitcoin:" to "Bitcoin",
        "ethereum:" to "Ethereum",
        "litecoin:" to "Litecoin",
        "bitcoincash:" to "Bitcoin Cash",
        "lightning:" to "Lightning",
    )

    private val APP_LINK = Regex("^[a-z][a-z0-9+.-]{1,31}:", RegexOption.IGNORE_CASE)
    private val LINE_BREAK = Regex("\r\n|\n|\r")

    fun classify(scanned: String): QrContent {
        val text = scanned.trim()

        fun has(prefix: String) = text.startsWith(prefix, ignoreCase = true)
        fun after(prefix: String) = text.substring(prefix.length)

        // Sign-in codes and chat links, as web links or in the service's own scheme. Never sent to the server.
        SpecialCodes.login(text)?.let { return it }
        SpecialCodes.chat(text)?.let { return it }

        if (has("http:") || has("https:")) {
            // Payment-app links come before ordinary links: they are never sent to the server.
            PaymentHosts.providerFor(text)?.let { return paylink(text, it) }
            return QrContent(QrType.URL, text)
        }

        val lines = text.split(LINE_BREAK)
        if (lines.size >= 4 && lines[0].trim().equals("BCD", true) && lines[3].trim().equals("SCT", true)) {
            return epc(text, lines)
        }
        if (lines.size >= 4 && lines[0].trim().equals("SPC", true)) return SpecialCodes.swissQr(text, lines)
        if (has("SPD*")) return SpecialCodes.spd(text)
        if (text.startsWith("000201")) {
            // A payload that looks like EMV but does not consume cleanly is plain text.
            return emv(text) ?: text(text)
        }
        if (has("upi://pay")) return upi(text)
        for ((prefix, network) in CRYPTO_NETWORKS) {
            if (has(prefix)) return crypto(text, after(prefix), network)
        }
        if (has("WIFI:")) return wifi(text, after("WIFI:"))
        if (has("BEGIN:VCARD")) return vcard(text)
        if (has("MECARD:")) return mecard(text, after("MECARD:"))
        if (has("BEGIN:VEVENT") || has("BEGIN:VCALENDAR")) return event(text)
        if (has("mailto:")) return mailto(text, after("mailto:"))
        if (has("MATMSG:")) return matmsg(text, after("MATMSG:"))
        if (has("tel:")) return phone(text, after("tel:"))
        if (has("smsto:")) return sms(text, after("smsto:"))
        if (has("sms:")) return sms(text, after("sms:"))
        if (has("geo:")) return geo(text, after("geo:"))
        if (has("otpauth://")) return otp(text, after("otpauth://"))
        if (has("otpauth-migration://")) return SpecialCodes.otpExport(text)
        if (has("LPA:")) return SpecialCodes.esim(text)
        SpecialCodes.device(text)?.let { return it }
        SpecialCodes.healthCert(text)?.let { return it }
        SpecialCodes.unsafe(text)?.let { return it }
        APP_LINK.find(text)?.let { match ->
            return QrContent(
                type = QrType.APPLINK,
                raw = text,
                fields = fieldsOf(
                    field(FieldLabel.SCHEME, match.value.dropLast(1).lowercase(), FieldStyle.MONO),
                    field(FieldLabel.TEXT, text, FieldStyle.MONO),
                ),
                notices = listOf(Notice.APP_LINK),
                actions = listOf(QrAction.OPEN_IN_APP, QrAction.COPY),
            )
        }
        return text(text)
    }

    // ---- helpers -----------------------------------------------------------

    private fun field(label: FieldLabel, value: String?, style: FieldStyle = FieldStyle.PLAIN): QrField? {
        val v = value?.trim().orEmpty()
        return if (v.isEmpty()) null else QrField(label, v, style)
    }

    private fun fieldsOf(vararg fields: QrField?): List<QrField> = fields.filterNotNull()

    private val LOCAL = listOf(Notice.LOCAL_ONLY)

    private fun text(text: String) = QrContent(
        type = QrType.TEXT,
        raw = text,
        fields = fieldsOf(field(FieldLabel.TEXT, text)),
        notices = LOCAL,
        actions = listOf(QrAction.COPY),
    )

    // ---- payments ----------------------------------------------------------

    /**
     * Payconiq links: `/l/1/<profile>/<pos>` (sticker) or
     * `/t/1/<profile>?D=<description>&A=<euro cents>&R=<reference>` (invoice).
     * Everything is optional; the link itself is never rebuilt from these.
     */
    private fun paylink(text: String, provider: String): QrContent {
        val uri = splitUri(text, plusAsSpace = true)
        val amount = uri["a"]?.takeIf { cents -> cents.length <= 12 && cents.all { it in '0'..'9' } }?.toLong()
            ?.let { "%d.%02d EUR".format(it / 100, it % 100) }
        return QrContent(
            type = QrType.PAYLINK,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.PROVIDER, provider),
                field(FieldLabel.AMOUNT, amount),
                field(FieldLabel.DESCRIPTION, uri["d"]),
                field(FieldLabel.REFERENCE, uri["r"], FieldStyle.MONO),
            ),
            notices = listOf(Notice.PAYLINK),
            actions = listOf(QrAction.OPEN_IN_PAYMENT_APP, QrAction.COPY),
        )
    }

    private val EPC_AMOUNT = Regex("^([A-Za-z]{3})\\s*([0-9]+(?:[.,][0-9]+)?)$")

    private fun epc(text: String, lines: List<String>): QrContent {
        fun line(i: Int) = lines.getOrNull(i)?.trim().orEmpty()

        val iban = Iban.normalize(line(6))
        val valid = Iban.isValid(iban)
        val amount = line(7).let { raw ->
            EPC_AMOUNT.find(raw)?.let { "${it.groupValues[2]} ${it.groupValues[1].uppercase()}" } ?: raw
        }
        val ibanField = if (iban.isEmpty()) null else
            QrField(FieldLabel.IBAN, Iban.grouped(iban), FieldStyle.MONO, copyValue = iban)

        return QrContent(
            type = QrType.EPC,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.BENEFICIARY, line(5)),
                ibanField,
                field(FieldLabel.BIC, line(4), FieldStyle.MONO),
                field(FieldLabel.AMOUNT, amount),
                field(FieldLabel.REFERENCE, line(9), FieldStyle.MONO),
                field(FieldLabel.MESSAGE, line(10)),
            ),
            notices = listOfNotNull(
                Notice.EPC_INSTRUCTION,
                if (valid) null else Notice.INVALID_IBAN,
                Notice.PAYMENT,
            ),
            // Plain text, not a link: there is nothing to open or share.
            actions = listOf(QrAction.COPY_IBAN, QrAction.COPY_ALL),
        )
    }

    private val EMV_CURRENCIES = mapOf(
        "978" to "EUR", "840" to "USD", "826" to "GBP", "756" to "CHF",
        "356" to "INR", "702" to "SGD", "764" to "THB", "986" to "BRL",
    )

    /** Parses `TT LL value` items; null unless the whole string is consumed cleanly. */
    internal fun parseTlv(text: String): List<Pair<String, String>>? {
        val out = ArrayList<Pair<String, String>>()
        var i = 0
        while (i < text.length) {
            if (i + 4 > text.length) return null
            val tag = text.substring(i, i + 2)
            val len = text.substring(i + 2, i + 4)
            if (!tag.all { it in '0'..'9' } || !len.all { it in '0'..'9' }) return null
            val end = i + 4 + len.toInt()
            if (end > text.length) return null
            out += tag to text.substring(i + 4, end)
            i = end
        }
        return out.takeIf { it.isNotEmpty() }
    }

    private fun emv(text: String): QrContent? {
        val items = parseTlv(text) ?: return null
        fun tag(id: String) = items.firstOrNull { it.first == id }?.second

        // Pix (Brazil): a merchant account template (tags 26 to 51) that names the Pix scheme.
        val pix = items.asSequence()
            .filter { (it.first.toIntOrNull() ?: 0) in 26..51 }
            .mapNotNull { parseTlv(it.second) }
            .firstOrNull { sub -> sub.any { it.first == "00" && it.second.equals("br.gov.bcb.pix", ignoreCase = true) } }
        val pixKey = pix?.let { sub -> (sub.firstOrNull { it.first == "01" } ?: sub.firstOrNull { it.first == "25" })?.second }

        return QrContent(
            type = QrType.EMV,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.PROVIDER, if (pix != null) "Pix" else null),
                field(FieldLabel.MERCHANT, tag("59")),
                field(FieldLabel.CITY, tag("60")),
                field(FieldLabel.COUNTRY, tag("58")),
                field(FieldLabel.AMOUNT, tag("54")),
                field(FieldLabel.CURRENCY, tag("53")?.let { EMV_CURRENCIES[it] ?: it }),
                field(FieldLabel.PAYEE_ADDRESS, pixKey, FieldStyle.MONO),
            ),
            notices = listOf(Notice.PAYMENT),
            actions = listOf(QrAction.COPY_ALL),
        )
    }

    private fun upi(text: String): QrContent {
        val uri = splitUri(text, plusAsSpace = true)
        return QrContent(
            type = QrType.UPI,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.PAYEE_NAME, uri["pn"]),
                field(FieldLabel.PAYEE_ADDRESS, uri["pa"], FieldStyle.MONO),
                field(FieldLabel.AMOUNT, uri["am"]),
                field(FieldLabel.CURRENCY, uri["cu"]),
                field(FieldLabel.NOTE, uri["tn"]),
            ),
            notices = listOf(Notice.PAYMENT),
            actions = listOf(QrAction.OPEN_IN_APP, QrAction.COPY),
        )
    }

    private fun crypto(text: String, rest: String, network: String): QrContent {
        val uri = splitUri(rest)
        val address = percentDecode(uri.path.removePrefix("//"))
        return QrContent(
            type = QrType.CRYPTO,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.NETWORK, network),
                field(FieldLabel.ADDRESS, address, FieldStyle.MONO),
                field(FieldLabel.AMOUNT, uri["amount"] ?: uri["value"]),
                field(FieldLabel.LABEL, uri["label"]),
                field(FieldLabel.MESSAGE, uri["message"]),
            ),
            notices = listOf(Notice.PAYMENT, Notice.CRYPTO_IRREVERSIBLE),
            actions = listOf(QrAction.OPEN_IN_APP, QrAction.COPY_ADDRESS),
        )
    }

    // ---- Wi-Fi -------------------------------------------------------------

    private fun wifi(text: String, body: String): QrContent {
        val items = parseKeyValues(body)
        fun value(key: String) = items.firstOrNull { it.key == key }?.value

        val security = value("T")?.trim().orEmpty()
        val open = security.isEmpty() || security.equals("nopass", true)
        val password = value("P").orEmpty()
        val hidden = value("H")?.trim().equals("true", true)

        return QrContent(
            type = QrType.WIFI,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.NETWORK, value("S")),
                // Empty value = no security; the UI supplies the wording.
                QrField(FieldLabel.SECURITY, if (open) "" else security.uppercase()),
                if (password.isEmpty()) null else QrField(FieldLabel.PASSWORD, password, FieldStyle.SECRET),
                if (hidden) QrField(FieldLabel.HIDDEN, "true") else null,
            ),
            notices = if (open) listOf(Notice.WIFI_OPEN) else LOCAL,
            actions = listOfNotNull(
                // Without a name there is nothing to join.
                if (value("S").isNullOrEmpty()) null else QrAction.JOIN_WIFI,
                if (password.isEmpty()) QrAction.COPY else QrAction.COPY_PASSWORD,
            ),
        )
    }

    // ---- contact / event ---------------------------------------------------

    private fun mecard(text: String, body: String): QrContent {
        val items = parseKeyValues(body)
        fun all(key: String) = items.filter { it.key == key }.map { it.value }

        val name = items.firstOrNull { it.key == "N" }?.let { n ->
            // MECARD names are "Last,First".
            val parts = n.parts.filter { it.isNotEmpty() }
            if (parts.size >= 2) (parts.drop(1) + parts[0]).joinToString(" ") else parts.joinToString(" ")
        }
        return contact(
            text,
            name = name,
            phones = all("TEL"),
            emails = all("EMAIL"),
            organisation = all("ORG").firstOrNull(),
            address = all("ADR").firstOrNull(),
            url = all("URL").firstOrNull(),
        )
    }

    private class ContentLine(val name: String, val value: String)

    /** vCard / iCalendar content lines: unfolded, parameters and group prefixes dropped. */
    private fun contentLines(text: String): List<ContentLine> {
        val unfolded = ArrayList<String>()
        for (line in text.split(LINE_BREAK)) {
            if ((line.startsWith(" ") || line.startsWith("\t")) && unfolded.isNotEmpty()) {
                unfolded[unfolded.lastIndex] = unfolded.last() + line.substring(1)
            } else {
                unfolded += line
            }
        }
        return unfolded.mapNotNull { line ->
            val colon = line.indexOf(':')
            if (colon <= 0) return@mapNotNull null
            val name = line.substring(0, colon).substringBefore(';').substringAfterLast('.').trim().uppercase()
            ContentLine(name, line.substring(colon + 1).trim())
        }
    }

    private fun unescapeText(value: String): String {
        val out = StringBuilder(value.length)
        var i = 0
        while (i < value.length) {
            val c = value[i]
            if (c == '\\' && i + 1 < value.length) {
                when (val next = value[i + 1]) {
                    'n', 'N' -> out.append('\n')
                    else -> out.append(next)
                }
                i += 2
            } else {
                out.append(c)
                i++
            }
        }
        return out.toString()
    }

    /** Joins the non-empty `;`-separated components of a structured value. */
    private fun structured(value: String, separator: String): String =
        splitUnescaped(value, ';').map { unescapeText(it).trim() }.filter { it.isNotEmpty() }.joinToString(separator)

    private fun vcard(text: String): QrContent {
        val lines = contentLines(text)
        fun all(name: String) = lines.filter { it.name == name && it.value.isNotEmpty() }.map { it.value }

        val name = all("FN").firstOrNull()?.let(::unescapeText)
            ?: all("N").firstOrNull()?.let { n ->
                // N is Family;Given;Additional;Prefix;Suffix.
                val parts = splitUnescaped(n, ';').map { unescapeText(it).trim() }
                listOfNotNull(parts.getOrNull(3), parts.getOrNull(1), parts.getOrNull(2), parts.getOrNull(0), parts.getOrNull(4))
                    .filter { it.isNotEmpty() }
                    .joinToString(" ")
            }
        return contact(
            text,
            name = name,
            phones = all("TEL").map { it.removePrefix("tel:") },
            emails = all("EMAIL"),
            organisation = all("ORG").firstOrNull()?.let { structured(it, ", ") },
            address = all("ADR").firstOrNull()?.let { structured(it, ", ") },
            url = all("URL").firstOrNull(),
        )
    }

    private fun contact(
        text: String,
        name: String?,
        phones: List<String>,
        emails: List<String>,
        organisation: String?,
        address: String?,
        url: String?,
    ) = QrContent(
        type = QrType.CONTACT,
        raw = text,
        fields = listOfNotNull(field(FieldLabel.NAME, name)) +
            phones.mapNotNull { field(FieldLabel.PHONE, it, FieldStyle.MONO) } +
            emails.mapNotNull { field(FieldLabel.EMAIL, it, FieldStyle.MONO) } +
            fieldsOf(
                field(FieldLabel.ORGANISATION, organisation),
                field(FieldLabel.ADDRESS, address),
                field(FieldLabel.URL, url, FieldStyle.MONO),
            ),
        notices = LOCAL,
        actions = listOf(QrAction.ADD_CONTACT, QrAction.COPY_ALL),
    )

    private val ICAL_DATE = Regex("^(\\d{4})(\\d{2})(\\d{2})(?:T(\\d{2})(\\d{2})(?:\\d{2})?(Z)?)?$")

    /** `20260314T093000Z` becomes `2026-03-14 09:30 UTC`; anything else is shown as it is. */
    internal fun formatCalendarDate(value: String): String {
        val m = ICAL_DATE.find(value.trim()) ?: return value
        val (year, month, day, hour, minute, utc) = m.destructured
        val date = "$year-$month-$day"
        if (hour.isEmpty()) return date
        return "$date $hour:$minute" + if (utc.isNotEmpty()) " UTC" else ""
    }

    /** The properties of the first VEVENT, so a VTIMEZONE's DTSTART is not picked up. */
    private fun eventLines(text: String): List<ContentLine> {
        val lines = contentLines(text)
        val start = lines.indexOfFirst { it.name == "BEGIN" && it.value.equals("VEVENT", true) }
        return if (start < 0) emptyList() else lines.drop(start + 1)
            .takeWhile { !(it.name == "END" && it.value.equals("VEVENT", true)) }
    }

    /** Start and end of a scanned event for the system calendar; null when the start does not parse. */
    internal fun eventTimes(text: String): SpecialCodes.EventTimes? {
        val scoped = eventLines(text)
        fun value(name: String) = scoped.firstOrNull { it.name == name }?.value
        return SpecialCodes.eventTimes(value("DTSTART"), value("DTEND"))
    }

    private fun event(text: String): QrContent {
        val scoped = eventLines(text)
        fun value(name: String) = scoped.firstOrNull { it.name == name }?.value
        val times = SpecialCodes.eventTimes(value("DTSTART"), value("DTEND"))

        return QrContent(
            type = QrType.EVENT,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.TITLE, value("SUMMARY")?.let(::unescapeText)),
                field(FieldLabel.START, value("DTSTART")?.let(::formatCalendarDate)),
                field(FieldLabel.END, value("DTEND")?.let(::formatCalendarDate)),
                field(FieldLabel.LOCATION, value("LOCATION")?.let(::unescapeText)),
                field(FieldLabel.DESCRIPTION, value("DESCRIPTION")?.let(::unescapeText)),
            ),
            notices = LOCAL,
            actions = listOfNotNull(if (times != null) QrAction.ADD_EVENT else null, QrAction.COPY_ALL),
        )
    }

    // ---- messaging ---------------------------------------------------------

    private fun email(text: String, to: String?, subject: String?, body: String?) = QrContent(
        type = QrType.EMAIL,
        raw = text,
        fields = fieldsOf(
            field(FieldLabel.TO, to, FieldStyle.MONO),
            field(FieldLabel.SUBJECT, subject),
            field(FieldLabel.BODY, body),
        ),
        notices = LOCAL,
        actions = listOf(QrAction.OPEN_IN_APP, QrAction.COPY),
    )

    private fun mailto(text: String, rest: String): QrContent {
        val uri = splitUri(rest)
        val to = listOf(percentDecode(uri.path), uri["to"].orEmpty()).filter { it.isNotBlank() }.joinToString(", ")
        return email(text, to, uri["subject"], uri["body"])
    }

    private fun matmsg(text: String, body: String): QrContent {
        val items = parseKeyValues(body)
        fun value(key: String) = items.firstOrNull { it.key == key }?.value
        return email(text, value("TO"), value("SUB"), value("BODY"))
    }

    private fun phone(text: String, rest: String): QrContent {
        val number = percentDecode(rest.removePrefix("//")).trim()
        val serviceCode = SpecialCodes.isServiceCode(number)
        return QrContent(
            type = QrType.PHONE,
            raw = text,
            fields = fieldsOf(field(FieldLabel.NUMBER, number, FieldStyle.MONO)),
            notices = when {
                serviceCode -> listOf(Notice.DIALER_CODE)
                SpecialCodes.isPremiumNumber(number) -> listOf(Notice.PREMIUM_NUMBER)
                else -> LOCAL
            },
            // A service code is never handed to the dialler.
            actions = if (serviceCode) listOf(QrAction.COPY) else listOf(QrAction.OPEN_IN_APP, QrAction.COPY),
        )
    }

    private val SHORT_CODE = Regex("^\\d{3,6}$")

    private fun sms(text: String, rest: String): QrContent {
        // Both `sms:123?body=Hi` and `smsto:123:Hi` are in use.
        val uri = splitUri(rest.removePrefix("//"), plusAsSpace = true)
        val colon = uri.path.indexOf(':')
        val number = percentDecode(if (colon < 0) uri.path else uri.path.substring(0, colon)).trim()
        val message = uri["body"] ?: if (colon < 0) null else uri.path.substring(colon + 1)

        return QrContent(
            type = QrType.SMS,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.NUMBER, number, FieldStyle.MONO),
                field(FieldLabel.MESSAGE, message),
            ),
            notices = if (SHORT_CODE.matches(number)) listOf(Notice.SMS_SHORT_CODE) else LOCAL,
            actions = listOf(QrAction.OPEN_IN_APP, QrAction.COPY),
        )
    }

    private fun geo(text: String, rest: String): QrContent {
        val uri = splitUri(rest, plusAsSpace = true)
        val coordinates = uri.path.substringBefore(';').split(',')
        return QrContent(
            type = QrType.GEO,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.LATITUDE, coordinates.getOrNull(0), FieldStyle.MONO),
                field(FieldLabel.LONGITUDE, coordinates.getOrNull(1), FieldStyle.MONO),
                field(FieldLabel.LABEL, uri["q"]),
            ),
            notices = LOCAL,
            actions = listOf(QrAction.OPEN_IN_APP, QrAction.COPY),
        )
    }

    private fun otp(text: String, rest: String): QrContent {
        val uri = splitUri(rest, plusAsSpace = true)
        val type = uri.path.substringBefore('/')
        val label = percentDecode(uri.path.substringAfter('/', "")).trim('/')
        val labelIssuer = if (':' in label) label.substringBefore(':') else null
        val account = if (':' in label) label.substringAfter(':') else label

        // The secret is deliberately never turned into a field.
        return QrContent(
            type = QrType.OTP,
            raw = text,
            fields = fieldsOf(
                field(FieldLabel.ISSUER, uri["issuer"] ?: labelIssuer),
                field(FieldLabel.ACCOUNT, account),
                field(FieldLabel.TYPE, type.uppercase(), FieldStyle.MONO),
            ),
            notices = listOf(Notice.OTP_SECRET),
            actions = listOf(QrAction.COPY),
        )
    }
}
