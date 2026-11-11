package be.appmire.secureqr.qr

/** Payload types, in classification order (first match wins). */
enum class QrType(val id: String) {
    PAYLINK("paylink"),
    URL("url"),
    EPC("epc"),
    EMV("emv"),
    UPI("upi"),
    CRYPTO("crypto"),
    WIFI("wifi"),
    CONTACT("contact"),
    EVENT("event"),
    EMAIL("email"),
    PHONE("phone"),
    SMS("sms"),
    GEO("geo"),
    OTP("otp"),
    APPLINK("applink"),
    TEXT("text");

    companion object {
        fun fromId(id: String?): QrType? = entries.firstOrNull { it.id == id }
    }
}

enum class NoticeLevel { NEUTRAL, CAUTION, DANGER }

/** Notices shown on a typed card. The display copy lives in the UI layer. */
enum class Notice(val level: NoticeLevel) {
    INVALID_IBAN(NoticeLevel.DANGER),
    OTP_SECRET(NoticeLevel.DANGER),
    PAYMENT(NoticeLevel.CAUTION),
    PAYLINK(NoticeLevel.CAUTION),
    CRYPTO_IRREVERSIBLE(NoticeLevel.CAUTION),
    WIFI_OPEN(NoticeLevel.CAUTION),
    SMS_SHORT_CODE(NoticeLevel.CAUTION),
    APP_LINK(NoticeLevel.CAUTION),
    LOCAL_ONLY(NoticeLevel.NEUTRAL),

    /** What to do with a bank transfer code. Shown first and prominently. */
    EPC_INSTRUCTION(NoticeLevel.NEUTRAL),
}

enum class FieldLabel {
    BENEFICIARY, IBAN, BIC, AMOUNT, REFERENCE, MESSAGE,
    MERCHANT, CITY, COUNTRY, CURRENCY,
    PAYEE_NAME, PAYEE_ADDRESS, NOTE,
    NETWORK, ADDRESS, LABEL,
    SECURITY, PASSWORD, HIDDEN,
    NAME, PHONE, EMAIL, ORGANISATION, URL,
    TITLE, START, END, LOCATION, DESCRIPTION,
    TO, SUBJECT, BODY,
    NUMBER,
    LATITUDE, LONGITUDE,
    ISSUER, ACCOUNT, TYPE,
    SCHEME, TEXT,
    PROVIDER,
}

enum class FieldStyle {
    PLAIN,

    /** Identifier-like value, rendered in monospace. */
    MONO,

    /** Masked by default, with a reveal toggle. */
    SECRET,
}

/**
 * One label/value row.
 *
 * [value] is what is displayed, [copyValue] what goes on the clipboard (for
 * example an IBAN is displayed grouped in fours but copied without spaces).
 * Two values are symbolic and translated by the UI: an empty [FieldLabel.SECURITY]
 * means "no security", and [FieldLabel.HIDDEN] is only present when true.
 */
data class QrField(
    val label: FieldLabel,
    val value: String,
    val style: FieldStyle = FieldStyle.PLAIN,
    val copyValue: String = value,
)

enum class QrAction {
    OPEN_IN_APP,

    /** Payment-app links: open the scanned link unchanged so the installed app claims it. */
    OPEN_IN_PAYMENT_APP,
    COPY,
    COPY_ALL,
    COPY_IBAN,
    COPY_ADDRESS,
    COPY_PASSWORD,
}

data class QrContent(
    val type: QrType,
    /** The scanned text, trimmed. */
    val raw: String,
    val fields: List<QrField> = emptyList(),
    val notices: List<Notice> = emptyList(),
    val actions: List<QrAction> = emptyList(),
) {
    fun field(label: FieldLabel): String? = fields.firstOrNull { it.label == label }?.value

    fun fields(label: FieldLabel): List<String> = fields.filter { it.label == label }.map { it.value }

    /** One line that identifies this content in a list: who or what it is about, else its first line. */
    val summary: String
        get() {
            val labels = when (type) {
                QrType.PAYLINK -> listOf(FieldLabel.PROVIDER)
                QrType.EPC -> listOf(FieldLabel.BENEFICIARY, FieldLabel.IBAN)
                QrType.EMV -> listOf(FieldLabel.MERCHANT)
                QrType.UPI -> listOf(FieldLabel.PAYEE_NAME, FieldLabel.PAYEE_ADDRESS)
                QrType.CRYPTO -> listOf(FieldLabel.ADDRESS)
                QrType.WIFI -> listOf(FieldLabel.NETWORK)
                QrType.CONTACT -> listOf(FieldLabel.NAME, FieldLabel.PHONE, FieldLabel.EMAIL)
                QrType.EVENT -> listOf(FieldLabel.TITLE)
                QrType.EMAIL -> listOf(FieldLabel.TO)
                QrType.PHONE, QrType.SMS -> listOf(FieldLabel.NUMBER)
                QrType.OTP -> listOf(FieldLabel.ISSUER, FieldLabel.ACCOUNT)
                else -> emptyList()
            }
            return labels.firstNotNullOfOrNull { field(it) }
                ?: raw.lineSequence().firstOrNull { it.isNotBlank() }?.trim().orEmpty()
        }

    /**
     * What the plain "Copy" action puts on the clipboard: the scanned text,
     * except for a sign-in secret, where only issuer and account are copied
     * and the secret never leaves the card.
     */
    val copyText: String
        get() {
            if (type != QrType.OTP) return raw
            val issuer = field(FieldLabel.ISSUER)
            val account = field(FieldLabel.ACCOUNT)
            return when {
                issuer != null && account != null -> "$issuer ($account)"
                else -> issuer ?: account ?: Redaction.redact(this)
            }
        }

    /** The most severe notice level on this card. */
    val level: NoticeLevel
        get() = notices.maxOfOrNull { it.level } ?: NoticeLevel.NEUTRAL
}
