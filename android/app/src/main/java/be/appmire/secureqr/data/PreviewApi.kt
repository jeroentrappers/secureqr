package be.appmire.secureqr.data

import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.buffer
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okio.BufferedSource
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume

sealed interface PreviewOutcome {
    data class Success(val response: PreviewResponse) : PreviewOutcome

    /** The server answered with an error. [message] is its user-facing text, when it sent one. */
    data class ApiError(val code: String, val message: String?) : PreviewOutcome

    /** The server could not be reached at all. */
    data object Offline : PreviewOutcome
}

/** [apiKey] is sent with the preview requests only; empty means no key (a local server asks for none). */
class PreviewApi(
    baseUrl: String,
    private val apiKey: String = "",
    private val client: OkHttpClient = defaultClient(),
) {
    private val baseUrl = baseUrl.trimEnd('/')

    /** Resolves a server-relative path such as `screenshotUrl` against the base URL. */
    fun absoluteUrl(path: String): String = when {
        path.startsWith("http://", true) || path.startsWith("https://", true) -> path
        path.startsWith("/") -> baseUrl + path
        else -> "$baseUrl/$path"
    }

    /** The plain check: one answer when everything is done. */
    suspend fun preview(url: String): PreviewOutcome =
        post("/v1/preview", "application/json", url, PreviewOutcome.Offline) { parse(it.code, it.body.string()) }

    /**
     * The same check, reported step by step. The flow ends with [PreviewEvent.Finished].
     * A server without the stream endpoint is asked through [preview] instead.
     */
    fun previewEvents(url: String): Flow<PreviewEvent> = channelFlow {
        val streamed = post<PreviewOutcome?>("/v1/preview/stream", "application/x-ndjson", url, PreviewOutcome.Offline) { response ->
            readStream(response.code, response.body.source()) { trySend(it) }
        }
        val outcome = streamed ?: run {
            send(PreviewEvent.StepsUnavailable)
            preview(url)
        }
        send(PreviewEvent.Finished(outcome))
    }.buffer(Channel.UNLIMITED)

    /** [read] runs on an OkHttp thread while the body is still arriving; [offline] stands in for any I/O failure. */
    private suspend fun <T> post(
        path: String,
        accept: String,
        url: String,
        offline: T,
        read: (Response) -> T,
    ): T {
        val body = ApiJson.encodeToString(PreviewRequest.serializer(), PreviewRequest(url))
            .toRequestBody(JSON_MEDIA_TYPE)
        val request = try {
            Request.Builder().url(baseUrl + path).post(body).header("Accept", accept)
                .apply { if (apiKey.isNotEmpty()) header(API_KEY_HEADER, apiKey) }
                .build()
        } catch (e: IllegalArgumentException) {
            return offline
        }

        return suspendCancellableCoroutine { continuation ->
            val call = client.newCall(request)
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    if (continuation.isActive) continuation.resume(offline)
                }

                override fun onResponse(call: Call, response: Response) {
                    val outcome = try {
                        response.use(read)
                    } catch (e: IOException) {
                        offline
                    }
                    if (continuation.isActive) continuation.resume(outcome)
                }
            })
        }
    }

    companion object {
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
        private const val TIMEOUT_SECONDS = 45L
        internal const val API_KEY_HEADER = "X-SecureQR-Key"

        /** The server no longer accepts this build's app key; only an app update helps. */
        const val CODE_UNAUTHORIZED = "unauthorized"

        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .callTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .writeTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .build()

        /** Turns an HTTP status and body into an outcome. Kept free of I/O so it can be unit-tested. */
        internal fun parse(status: Int, body: String): PreviewOutcome {
            if (status in 200..299) {
                return try {
                    PreviewOutcome.Success(ApiJson.decodeFromString(PreviewResponse.serializer(), body))
                } catch (e: Exception) {
                    PreviewOutcome.ApiError("internal", null)
                }
            }
            val error = try {
                ApiJson.decodeFromString(ErrorEnvelope.serializer(), body).error
            } catch (e: Exception) {
                null
            }
            return PreviewOutcome.ApiError(
                code = error?.code?.takeIf { it.isNotBlank() } ?: fallbackCode(status),
                message = error?.message?.takeIf { it.isNotBlank() },
            )
        }

        /**
         * Reads a stream response line by line as it arrives, handing steps and hops to
         * [onEvent]. Returns how the check ended, or null when the server does not have
         * the stream endpoint. A stream that stops before its last line counts as offline.
         */
        @Throws(IOException::class)
        internal fun readStream(status: Int, source: BufferedSource, onEvent: (PreviewEvent) -> Unit): PreviewOutcome? {
            if (status == 404) return null
            if (status !in 200..299) return parse(status, source.readUtf8())
            while (true) {
                val line = source.readUtf8Line() ?: return PreviewOutcome.Offline
                when (val event = parseStreamLine(line)) {
                    null -> Unit
                    is PreviewEvent.Finished -> return event.outcome
                    else -> onEvent(event)
                }
            }
        }

        /** One line of the stream. Null for anything this version does not know or cannot read. */
        internal fun parseStreamLine(line: String): PreviewEvent? {
            if (line.isBlank()) return null
            val parsed = try {
                ApiJson.decodeFromString(StreamLine.serializer(), line)
            } catch (e: Exception) {
                return null
            }
            return when (parsed.type) {
                "step" -> when {
                    parsed.id.isBlank() -> null
                    parsed.state == "active" -> PreviewEvent.Step(parsed.id, done = false, parsed.label)
                    parsed.state == "done" -> PreviewEvent.Step(parsed.id, done = true, parsed.label)
                    else -> null
                }
                "hop" -> parsed.hop?.host?.takeIf { it.isNotBlank() }?.let(PreviewEvent::HopReached)
                "result" -> parsed.result?.let { PreviewEvent.Finished(PreviewOutcome.Success(it)) }
                "error" -> PreviewEvent.Finished(
                    PreviewOutcome.ApiError(
                        code = parsed.error?.code?.takeIf { it.isNotBlank() } ?: fallbackCode(parsed.status ?: 500),
                        message = parsed.error?.message?.takeIf { it.isNotBlank() },
                    ),
                )
                else -> null
            }
        }

        private fun fallbackCode(status: Int): String = when (status) {
            400 -> "invalid_url"
            401 -> CODE_UNAUTHORIZED
            422 -> "unreachable"
            429 -> "rate_limited"
            504 -> "timeout"
            else -> "internal"
        }
    }
}
