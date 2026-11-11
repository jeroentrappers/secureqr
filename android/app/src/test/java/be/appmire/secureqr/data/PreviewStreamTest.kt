package be.appmire.secureqr.data

import be.appmire.secureqr.PreviewUiState
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PreviewStreamTest {

    private val result = """{"type":"result","result":{"id":"1","requestedUrl":"https://qr-go.example/x7Pq",""" +
        """"finalHost":"parcel-track.example","verdict":{"level":"caution"}}}"""

    private val documented = """
        {"type":"step","id":"blocklists","state":"active","label":"Checking threat blocklists"}
        {"type":"step","id":"address","state":"active","label":"Looking up the address"}
        {"type":"step","id":"address","state":"done","label":"Address found"}
        {"type":"step","id":"redirects","state":"active","label":"Following the link"}
        {"type":"hop","hop":{"url":"https://qr-go.example/x7Pq","host":"qr-go.example","status":null,"kind":"start"}}
        {"type":"hop","hop":{"url":"https://parcel-track.example/pay","host":"parcel-track.example","status":null,"kind":"http"}}
        {"type":"step","id":"page","state":"active","label":"Loading the page"}
        {"type":"step","id":"redirects","state":"done","label":"1 redirect"}
        {"type":"step","id":"page","state":"done","label":"Page loaded"}
        {"type":"step","id":"blocklists","state":"done","label":"Not on 4 blocklists"}
    """.trimIndent() + "\n" + result + "\n"

    private fun read(status: Int, body: String): Pair<List<PreviewEvent>, PreviewOutcome?> {
        val events = ArrayList<PreviewEvent>()
        val outcome = PreviewApi.readStream(status, Buffer().writeUtf8(body)) { events += it }
        return events to outcome
    }

    /** A client that answers from [answers] (path to status and body) without touching the network. */
    private fun api(
        answers: Map<String, Pair<Int, String>>,
        requested: MutableList<String> = ArrayList(),
        apiKey: String = "",
        sentKeys: MutableList<String?> = ArrayList(),
    ): PreviewApi {
        val interceptor = Interceptor { chain ->
            val path = chain.request().url.encodedPath
            requested += path
            sentKeys += chain.request().header("X-SecureQR-Key")
            val (status, body) = answers.getValue(path)
            Response.Builder()
                .request(chain.request())
                .protocol(Protocol.HTTP_1_1)
                .code(status)
                .message("")
                .body(body.toResponseBody("application/json".toMediaType()))
                .build()
        }
        return PreviewApi("https://api.example", apiKey, OkHttpClient.Builder().addInterceptor(interceptor).build())
    }

    @Test
    fun `reads the documented stream`() {
        val (events, outcome) = read(200, documented)
        assertEquals(10, events.size)
        assertEquals(PreviewEvent.Step("blocklists", done = false, "Checking threat blocklists"), events[0])
        assertEquals(PreviewEvent.Step("address", done = true, "Address found"), events[2])
        assertEquals(PreviewEvent.HopReached("qr-go.example"), events[4])
        assertEquals(PreviewEvent.HopReached("parcel-track.example"), events[5])
        assertEquals("parcel-track.example", (outcome as PreviewOutcome.Success).response.finalHost)
        assertEquals(VerdictLevel.CAUTION, outcome.response.verdict.verdictLevel)
    }

    @Test
    fun `steps keep the order of first arrival and are updated in place`() {
        val progress = read(200, documented).first.fold(CheckProgress(), CheckProgress::reduce)
        assertEquals(
            listOf(
                CheckStep("blocklists", done = true, "Not on 4 blocklists"),
                CheckStep("address", done = true, "Address found"),
                CheckStep("redirects", done = true, "1 redirect"),
                CheckStep("page", done = true, "Page loaded"),
            ),
            progress.steps,
        )
        assertEquals(listOf("qr-go.example", "parcel-track.example"), progress.hopHosts)
        assertTrue(progress.stepsAvailable)
    }

    @Test
    fun `a host equal to the previous one is listed once`() {
        val progress = listOf("a.example", "a.example", "b.example", "a.example")
            .fold(CheckProgress()) { p, host -> p.reduce(PreviewEvent.HopReached(host)) }
        assertEquals(listOf("a.example", "b.example", "a.example"), progress.hopHosts)
    }

    @Test
    fun `a reused answer is a single result line`() {
        val (events, outcome) = read(200, """{"type":"result","result":{"cached":true,"verdict":{"level":"ok"}}}""")
        assertTrue(events.isEmpty())
        assertEquals(true, (outcome as PreviewOutcome.Success).response.cached)
    }

    @Test
    fun `an error line ends the stream with the server's wording`() {
        val (events, outcome) = read(
            200,
            """
            {"type":"step","id":"address","state":"active","label":"Looking up the address"}
            {"type":"error","status":422,"error":{"code":"unreachable","message":"The site did not respond"}}
            """.trimIndent(),
        )
        assertEquals(1, events.size)
        assertEquals(PreviewOutcome.ApiError("unreachable", "The site did not respond"), outcome)
        assertEquals(
            PreviewEvent.Finished(PreviewOutcome.ApiError("timeout", null)),
            PreviewApi.parseStreamLine("""{"type":"error","status":504}"""),
        )
    }

    @Test
    fun `unknown types, states, fields and unreadable lines are ignored`() {
        val (events, outcome) = read(
            200,
            """
            {"type":"heartbeat","n":1}
            {"type":"step","id":"address","state":"skipped","label":"Skipped"}
            {"type":"step","id":"certificate","state":"active","label":"Checking the certificate","weight":3}
            {"type":"hop","hop":{"host":"a.example","country":"BE"},"extra":[1,2]}
            {"type":"hop"}

            not json
            $result
            """.trimIndent(),
        )
        assertEquals(
            listOf(
                PreviewEvent.Step("certificate", done = false, "Checking the certificate"),
                PreviewEvent.HopReached("a.example"),
            ),
            events,
        )
        assertTrue(outcome is PreviewOutcome.Success)
    }

    @Test
    fun `a stream that ends without a result is a network failure`() {
        val truncated = documented.substringBefore("""{"type":"result"""")
        assertEquals(PreviewOutcome.Offline, read(200, truncated).second)
        assertEquals(PreviewOutcome.Offline, read(200, "").second)
        // Cut off in the middle of the last line.
        assertEquals(PreviewOutcome.Offline, read(200, documented.dropLast(20)).second)
    }

    @Test
    fun `error responses keep the plain error handling`() {
        assertEquals(
            PreviewOutcome.ApiError("invalid_url", "Not a valid link"),
            read(400, """{"error":{"code":"invalid_url","message":"Not a valid link"}}""").second,
        )
        assertEquals(PreviewOutcome.ApiError("rate_limited", null), read(429, "<html>Too many</html>").second)
        assertNull(read(404, """{"error":{"code":"not_found","message":"Not found"}}""").second)
    }

    @Test
    fun `the flow reports steps and ends with the result`() = runBlocking {
        val events = api(mapOf("/v1/preview/stream" to (200 to documented))).previewEvents("https://qr-go.example/x7Pq").toList()
        assertEquals(11, events.size)
        assertEquals(PreviewEvent.Step("blocklists", done = false, "Checking threat blocklists"), events.first())
        assertTrue((events.last() as PreviewEvent.Finished).outcome is PreviewOutcome.Success)
    }

    @Test
    fun `a server without the stream endpoint is asked the plain way`() = runBlocking {
        val requested = ArrayList<String>()
        val events = api(
            mapOf(
                "/v1/preview/stream" to (404 to "Not found"),
                "/v1/preview" to (200 to """{"finalHost":"a.example","verdict":{"level":"ok"}}"""),
            ),
            requested,
        ).previewEvents("https://a.example/").toList()
        assertEquals(listOf("/v1/preview/stream", "/v1/preview"), requested)
        assertEquals(PreviewEvent.StepsUnavailable, events[0])
        assertEquals("a.example", ((events[1] as PreviewEvent.Finished).outcome as PreviewOutcome.Success).response.finalHost)
        assertEquals(2, events.size)
        assertEquals(false, events.fold(CheckProgress(), CheckProgress::reduce).stepsAvailable)
    }

    @Test
    fun `a truncated stream ends the flow as offline`() = runBlocking {
        val body = """{"type":"step","id":"address","state":"active","label":"Looking up the address"}""" + "\n"
        val events = api(mapOf("/v1/preview/stream" to (200 to body))).previewEvents("https://a.example/").toList()
        assertEquals(PreviewEvent.Finished(PreviewOutcome.Offline), events.last())
        assertEquals(2, events.size)
    }

    private val unauthorized = """{"error":{"code":"unauthorized",""" +
        """"message":"This copy of the app can no longer use the service. Update SecureQR and try again."}}"""

    @Test
    fun `the app key is sent on the stream and on the plain check`() = runBlocking {
        val requested = ArrayList<String>()
        val sentKeys = ArrayList<String?>()
        val api = api(
            mapOf(
                "/v1/preview/stream" to (404 to "Not found"),
                "/v1/preview" to (200 to """{"finalHost":"a.example","verdict":{"level":"ok"}}"""),
            ),
            requested,
            apiKey = "test-key",
            sentKeys = sentKeys,
        )
        api.previewEvents("https://a.example/").toList()
        assertEquals(listOf("/v1/preview/stream", "/v1/preview"), requested)
        assertEquals(listOf<String?>("test-key", "test-key"), sentKeys)
    }

    @Test
    fun `without an app key no key header is sent`() = runBlocking {
        val sentKeys = ArrayList<String?>()
        val api = api(
            mapOf(
                "/v1/preview/stream" to (404 to "Not found"),
                "/v1/preview" to (200 to """{"finalHost":"a.example","verdict":{"level":"ok"}}"""),
            ),
            sentKeys = sentKeys,
        )
        api.previewEvents("https://a.example/").toList()
        assertEquals(listOf<String?>(null, null), sentKeys)
    }

    @Test
    fun `a refused app key ends the check without asking the plain way`() = runBlocking {
        val requested = ArrayList<String>()
        val events = api(mapOf("/v1/preview/stream" to (401 to unauthorized)), requested, apiKey = "old-key")
            .previewEvents("https://a.example/").toList()
        assertEquals(listOf("/v1/preview/stream"), requested)
        assertEquals(
            listOf<PreviewEvent>(
                PreviewEvent.Finished(
                    PreviewOutcome.ApiError(
                        "unauthorized",
                        "This copy of the app can no longer use the service. Update SecureQR and try again.",
                    ),
                ),
            ),
            events,
        )
    }

    @Test
    fun `a refused app key is read from the status when the body says nothing`() {
        assertEquals(PreviewOutcome.ApiError("unauthorized", null), read(401, "").second)
        assertEquals(PreviewOutcome.ApiError("unauthorized", null), PreviewApi.parse(401, "<html>No</html>"))
    }

    @Test
    fun `a refused app key asks for an update and offers no retry`() {
        val outcome = PreviewApi.parse(401, unauthorized) as PreviewOutcome.ApiError
        val failed = PreviewUiState.Failed(outcome.code, outcome.message, offline = false)
        assertTrue(failed.updateNeeded)
        assertFalse(failed.retryable)
        assertEquals("This copy of the app can no longer use the service. Update SecureQR and try again.", failed.message)

        val other = PreviewUiState.Failed("timeout", null, offline = false)
        assertFalse(other.updateNeeded)
        assertTrue(other.retryable)
        assertFalse(PreviewUiState.Failed(null, null, offline = true).updateNeeded)
    }
}
