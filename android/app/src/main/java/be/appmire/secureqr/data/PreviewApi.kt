package be.appmire.secureqr.data

import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
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

class PreviewApi(
    baseUrl: String,
    private val client: OkHttpClient = defaultClient(),
) {
    private val baseUrl = baseUrl.trimEnd('/')

    /** Resolves a server-relative path such as `screenshotUrl` against the base URL. */
    fun absoluteUrl(path: String): String = when {
        path.startsWith("http://", true) || path.startsWith("https://", true) -> path
        path.startsWith("/") -> baseUrl + path
        else -> "$baseUrl/$path"
    }

    suspend fun preview(url: String): PreviewOutcome {
        val body = ApiJson.encodeToString(PreviewRequest.serializer(), PreviewRequest(url))
            .toRequestBody(JSON_MEDIA_TYPE)
        val request = try {
            Request.Builder().url("$baseUrl/v1/preview").post(body).header("Accept", "application/json").build()
        } catch (e: IllegalArgumentException) {
            return PreviewOutcome.Offline
        }

        return suspendCancellableCoroutine { continuation ->
            val call = client.newCall(request)
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    if (continuation.isActive) continuation.resume(PreviewOutcome.Offline)
                }

                override fun onResponse(call: Call, response: Response) {
                    val outcome = try {
                        response.use { parse(it.code, it.body.string()) }
                    } catch (e: IOException) {
                        PreviewOutcome.Offline
                    }
                    if (continuation.isActive) continuation.resume(outcome)
                }
            })
        }
    }

    companion object {
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
        private const val TIMEOUT_SECONDS = 45L

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

        private fun fallbackCode(status: Int): String = when (status) {
            400 -> "invalid_url"
            422 -> "unreachable"
            429 -> "rate_limited"
            504 -> "timeout"
            else -> "internal"
        }
    }
}
