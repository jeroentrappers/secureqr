package be.appmire.secureqr.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PreviewApiTest {

    private val sample = """
        {
          "id": "b3f1c2e4a9d04c6f",
          "requestedUrl": "https://qr-go.example/x7Pq",
          "finalUrl": "https://pay-fee.parcel-track.example/pay?id=1",
          "finalHost": "pay-fee.parcel-track.example",
          "finalDomain": "parcel-track.example",
          "title": "Your parcel is on hold",
          "https": true,
          "hops": [
            { "url": "https://qr-go.example/x7Pq", "host": "qr-go.example", "status": 301, "kind": "start" },
            { "url": "https://trk.mailing.example/c/9", "host": "trk.mailing.example", "status": 302, "kind": "http" },
            { "url": "https://pay-fee.parcel-track.example/pay?id=1", "host": "pay-fee.parcel-track.example", "status": 200, "kind": "http" }
          ],
          "screenshotUrl": "/v1/screenshots/b3f1c2e4a9d04c6f.jpg",
          "reputation": { "checked": ["Quad9", "Cloudflare"], "flaggedBy": [], "flaggedHost": null },
          "verdict": {
            "level": "caution",
            "reasons": [
              { "code": "domain_changed", "message": "Ends at a different site than it starts" },
              { "code": "asks_for_payment", "message": "The page asks for card details" }
            ]
          },
          "durationMs": 4210
        }
    """.trimIndent()

    private fun success(body: String): PreviewResponse {
        val outcome = PreviewApi.parse(200, body)
        assertTrue("expected success but was $outcome", outcome is PreviewOutcome.Success)
        return (outcome as PreviewOutcome.Success).response
    }

    @Test
    fun `decodes the documented response`() {
        val r = success(sample)
        assertEquals("https://qr-go.example/x7Pq", r.requestedUrl)
        assertEquals("pay-fee.parcel-track.example", r.finalHost)
        assertEquals("parcel-track.example", r.finalDomain)
        assertTrue(r.https)
        assertEquals(3, r.hops.size)
        assertEquals(2, r.redirectCount)
        assertEquals("start", r.hops[0].kind)
        assertEquals(301, r.hops[0].status)
        assertEquals("/v1/screenshots/b3f1c2e4a9d04c6f.jpg", r.screenshotUrl)
        assertEquals(VerdictLevel.CAUTION, r.verdict.verdictLevel)
        assertEquals("Ends at a different site than it starts", r.verdict.reasons.first().message)
        assertEquals(listOf("Quad9", "Cloudflare"), r.reputation?.checked)
        assertEquals(ReputationStatus.CLEAR, r.reputation?.status)
    }

    @Test
    fun `reputation is optional and drives the blocklist chip`() {
        assertNull(success("""{"verdict":{"level":"ok"}}""").reputation)
        assertNull(success("""{"reputation":null,"verdict":{"level":"ok"}}""").reputation)
        assertEquals(
            ReputationStatus.UNKNOWN,
            success("""{"reputation":{"checked":[],"flaggedBy":[]},"verdict":{"level":"ok"}}""").reputation?.status,
        )
        assertEquals(ReputationStatus.UNKNOWN, success("""{"reputation":{},"verdict":{"level":"ok"}}""").reputation?.status)
        val flagged = success(
            """{"reputation":{"checked":["Quad9"],"flaggedBy":["Quad9"],"flaggedHost":"bad.example"},
               "verdict":{"level":"danger","reasons":[{"code":"known_malicious","message":"Listed as malicious"}]}}""",
        )
        assertEquals(ReputationStatus.FLAGGED, flagged.reputation?.status)
        assertEquals("bad.example", flagged.reputation?.flaggedHost)
        assertEquals("Listed as malicious", flagged.verdict.reasons.first().message)
        assertEquals(VerdictLevel.DANGER, flagged.verdict.verdictLevel)
    }

    @Test
    fun `cached answers report their age`() {
        val fresh = success(sample)
        assertEquals(false, fresh.cached)
        assertNull(fresh.checkedAt)
        assertNull(fresh.cachedMinutesAgo(0))

        val checked = java.time.Instant.parse("2026-11-11T10:00:00Z").toEpochMilli()
        val cached = success("""{"cached":true,"checkedAt":"2026-11-11T10:00:00.000Z","verdict":{"level":"ok"}}""")
        assertEquals(true, cached.cached)
        assertEquals(0L, cached.cachedMinutesAgo(checked + 59_000))
        assertEquals(1L, cached.cachedMinutesAgo(checked + 60_000))
        assertEquals(7L, cached.cachedMinutesAgo(checked + 7 * 60_000 + 30_000))
        // A clock that is behind the server never yields a negative age.
        assertEquals(0L, cached.cachedMinutesAgo(checked - 120_000))

        val offset = success("""{"cached":true,"checkedAt":"2026-11-11T11:00:00+01:00","verdict":{"level":"ok"}}""")
        assertEquals(3L, offset.cachedMinutesAgo(checked + 3 * 60_000))

        // Not shown when the answer is fresh, or the time is missing or unreadable.
        assertNull(success("""{"cached":false,"checkedAt":"2026-11-11T10:00:00Z","verdict":{"level":"ok"}}""").cachedMinutesAgo(checked))
        assertNull(success("""{"cached":true,"verdict":{"level":"ok"}}""").cachedMinutesAgo(checked))
        assertNull(success("""{"cached":true,"checkedAt":"yesterday","verdict":{"level":"ok"}}""").cachedMinutesAgo(checked))
        assertNull(success("""{"cached":null,"checkedAt":null,"verdict":{"level":"ok"}}""").cachedMinutesAgo(checked))
    }

    @Test
    fun `four reputation sources decode`() {
        val r = success(
            """{"reputation":{"checked":["Quad9","Cloudflare","DNS4EU","Phishing.Database"],"flaggedBy":["DNS4EU","Phishing.Database"],
               "flaggedHost":"bad.example"},"verdict":{"level":"danger"}}""",
        )
        assertEquals(4, r.reputation?.checked?.size)
        assertEquals(ReputationStatus.FLAGGED, r.reputation?.status)
    }

    @Test
    fun `app link is optional`() {
        assertNull(success(sample).appLink)
        assertNull(success("""{"appLink":null,"verdict":{"level":"ok"}}""").appLink)
        val r = success(
            """{"appLink":{"scheme":"itsme","extra":true},"screenshotUrl":null,
               "verdict":{"level":"caution","reasons":[{"code":"opens_app","message":"This link opens another app"}]}}""",
        )
        assertEquals("itsme", r.appLink?.scheme)
        assertNull(r.screenshotUrl)
        assertEquals("This link opens another app", r.verdict.reasons.single().message)
    }

    @Test
    fun `tolerates nulls, unknown fields and unknown reason codes`() {
        val r = success(
            """
            {"id":"1","requestedUrl":"http://a.example","finalUrl":"http://a.example","finalHost":"a.example",
             "finalDomain":"a.example","title":null,"https":false,"somethingNew":{"x":[1,2]},
             "hops":[{"url":"http://a.example","host":"a.example","status":null,"kind":"start","extra":1}],
             "screenshotUrl":null,
             "verdict":{"level":"danger","reasons":[{"code":"brand_new_code","message":"Something new","weight":3}],"score":7},
             "durationMs":12}
            """.trimIndent(),
        )
        assertEquals("", r.title)
        assertNull(r.screenshotUrl)
        assertNull(r.hops[0].status)
        assertEquals(0, r.redirectCount)
        assertEquals("Something new", r.verdict.reasons.single().message)
    }

    @Test
    fun `an unknown verdict level is never treated as ok`() {
        assertEquals(VerdictLevel.CAUTION, VerdictLevel.fromApi("weird"))
        assertEquals(VerdictLevel.CAUTION, VerdictLevel.fromApi(null))
        assertEquals(VerdictLevel.OK, VerdictLevel.fromApi("ok"))
        assertEquals(VerdictLevel.CAUTION, success("""{"id":"1"}""").verdict.verdictLevel)
    }

    @Test
    fun `decodes every documented error`() {
        val cases = listOf(
            400 to "invalid_url", 401 to "unauthorized", 400 to "blocked_target", 422 to "unreachable",
            429 to "rate_limited", 504 to "timeout", 500 to "internal",
        )
        for ((status, code) in cases) {
            val outcome = PreviewApi.parse(status, """{ "error": { "code": "$code", "message": "Message for $code" } }""")
            assertEquals(PreviewOutcome.ApiError(code, "Message for $code"), outcome)
        }
    }

    @Test
    fun `error without a usable body falls back on the status`() {
        assertEquals(PreviewOutcome.ApiError("rate_limited", null), PreviewApi.parse(429, "<html>Too many</html>"))
        assertEquals(PreviewOutcome.ApiError("internal", null), PreviewApi.parse(502, ""))
        assertEquals(PreviewOutcome.ApiError("timeout", null), PreviewApi.parse(504, "{}"))
    }

    @Test
    fun `a success status with an unreadable body is an internal error`() {
        assertEquals(PreviewOutcome.ApiError("internal", null), PreviewApi.parse(200, "not json"))
    }

    @Test
    fun `screenshot urls resolve against the base url`() {
        val api = PreviewApi("http://10.0.2.2:8080/")
        assertEquals("http://10.0.2.2:8080/v1/screenshots/a.jpg", api.absoluteUrl("/v1/screenshots/a.jpg"))
        assertEquals("http://10.0.2.2:8080/v1/screenshots/a.jpg", api.absoluteUrl("v1/screenshots/a.jpg"))
        assertEquals("https://cdn.example/a.jpg", api.absoluteUrl("https://cdn.example/a.jpg"))
    }
}
