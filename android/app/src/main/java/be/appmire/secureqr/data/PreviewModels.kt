package be.appmire.secureqr.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.OffsetDateTime
import java.time.format.DateTimeParseException

/** Lenient on purpose: unknown fields and unknown reason codes must never break decoding. */
internal val ApiJson = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    isLenient = true
    explicitNulls = false
}

@Serializable
internal data class PreviewRequest(val url: String)

@Serializable
data class PreviewResponse(
    val id: String = "",
    val requestedUrl: String = "",
    val finalUrl: String = "",
    val finalHost: String = "",
    val finalDomain: String = "",
    val title: String = "",
    val https: Boolean = false,
    val hops: List<Hop> = emptyList(),
    val screenshotUrl: String? = null,
    val reputation: Reputation? = null,
    /** Set when the chain ends by handing over to an app scheme; the `opens_app` reason carries the wording. */
    val appLink: AppLink? = null,
    val verdict: Verdict = Verdict(),
    val durationMs: Long = 0,
    /** True when the server reused an answer from the last few minutes. */
    val cached: Boolean = false,
    /** ISO 8601 time of the check that produced this answer. */
    val checkedAt: String? = null,
) {
    /**
     * Whole minutes since [checkedAt], for a reused answer. Null when the
     * answer is fresh or the time is missing or unreadable.
     */
    fun cachedMinutesAgo(nowMillis: Long): Long? {
        if (!cached || checkedAt == null) return null
        val checked = try {
            OffsetDateTime.parse(checkedAt).toInstant().toEpochMilli()
        } catch (e: DateTimeParseException) {
            return null
        }
        return ((nowMillis - checked) / 60_000).coerceAtLeast(0)
    }

    /** Number of redirects: every hop after the scanned URL. */
    val redirectCount: Int get() = (hops.size - 1).coerceAtLeast(0)
}

@Serializable
data class Hop(
    val url: String = "",
    val host: String = "",
    val status: Int? = null,
    /** `start`, `http` or `client`; other values are shown as a plain redirect. */
    val kind: String = "http",
)

@Serializable
data class Reputation(
    val checked: List<String> = emptyList(),
    val flaggedBy: List<String> = emptyList(),
    val flaggedHost: String? = null,
) {
    val status: ReputationStatus
        get() = when {
            flaggedBy.isNotEmpty() -> ReputationStatus.FLAGGED
            checked.isNotEmpty() -> ReputationStatus.CLEAR
            else -> ReputationStatus.UNKNOWN
        }
}

@Serializable
data class AppLink(val scheme: String = "")

enum class ReputationStatus { FLAGGED, CLEAR, UNKNOWN }

@Serializable
data class Verdict(
    val level: String = "",
    val reasons: List<Reason> = emptyList(),
) {
    val verdictLevel: VerdictLevel get() = VerdictLevel.fromApi(level)
}

@Serializable
data class Reason(val code: String = "", val message: String = "")

enum class VerdictLevel(val id: String) {
    OK("ok"),
    CAUTION("caution"),
    DANGER("danger");

    companion object {
        /** An unrecognised level is never treated as "ok". */
        fun fromApi(value: String?): VerdictLevel = entries.firstOrNull { it.id == value } ?: CAUTION
    }
}

@Serializable
internal data class ErrorEnvelope(val error: ErrorBody? = null)

@Serializable
internal data class ErrorBody(val code: String = "", val message: String = "")
