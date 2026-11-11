package be.appmire.secureqr.data

import be.appmire.secureqr.qr.NoticeLevel
import be.appmire.secureqr.qr.QrContent
import be.appmire.secureqr.qr.QrType
import be.appmire.secureqr.qr.Redaction
import be.appmire.secureqr.qr.hostOf
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * One past scan. [payload] never contains an OTP secret or a Wi-Fi password:
 * those are stripped before storing and [redacted] is set.
 */
@Serializable
data class HistoryEntry(
    val id: String,
    val payload: String,
    val type: String,
    val host: String? = null,
    /**
     * `ok`, `caution`, `danger` (verdict or notice level), `neutral`,
     * `failed` for a link whose check did not succeed, or null while a link
     * is still being checked.
     */
    val level: String? = null,
    val timestamp: Long,
    val redacted: Boolean = false,
) {
    companion object {
        const val LEVEL_NEUTRAL = "neutral"
        const val LEVEL_FAILED = "failed"

        fun from(content: QrContent, now: Long): HistoryEntry {
            val payload = Redaction.redact(content)
            val isUrl = content.type == QrType.URL
            return HistoryEntry(
                id = UUID.randomUUID().toString(),
                payload = payload,
                type = content.type.id,
                host = if (isUrl) hostOf(content.raw) else null,
                level = if (isUrl) null else when (content.level) {
                    NoticeLevel.DANGER -> VerdictLevel.DANGER.id
                    NoticeLevel.CAUTION -> VerdictLevel.CAUTION.id
                    NoticeLevel.NEUTRAL -> LEVEL_NEUTRAL
                },
                timestamp = now,
                redacted = payload != content.raw,
            )
        }
    }
}

/** The list operations behind the history, newest first. Pure, so they can be unit-tested. */
object HistoryLog {
    const val MAX_ENTRIES = 500

    /** Every scan gets its own entry, also a repeat of the same code. */
    fun add(current: List<HistoryEntry>, entry: HistoryEntry): List<HistoryEntry> =
        (listOf(entry) + current).take(MAX_ENTRIES)

    /** Records the outcome of a (re-)check and moves the entry to the top. */
    fun setLevel(current: List<HistoryEntry>, id: String, level: String, now: Long): List<HistoryEntry> =
        current.map { if (it.id == id) it.copy(level = level, timestamp = now) else it }
            .sortedByDescending { it.timestamp }

    fun delete(current: List<HistoryEntry>, id: String): List<HistoryEntry> = current.filterNot { it.id == id }
}
