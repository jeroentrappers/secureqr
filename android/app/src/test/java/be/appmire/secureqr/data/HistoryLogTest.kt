package be.appmire.secureqr.data

import be.appmire.secureqr.qr.QrClassifier
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryLogTest {

    private fun entry(payload: String, now: Long = 1_000) = HistoryEntry.from(QrClassifier.classify(payload), now)

    @Test
    fun `every kind of scan gets an entry`() {
        val payloads = listOf(
            "https://payconiq.com/t/1/5f2a9c0e1b?D=Invoice%2042&A=1250&R=INV42",
            "https://example.com/a",
            "BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00\n\n\nGift\n",
            "00020101021129370016A000000677010111011300660000000005802TH530376454031005913Test Merchant6007Bangkok6304ABCD",
            "upi://pay?pa=shop@bank&pn=Corner%20Shop&am=120.50&cu=INR",
            "bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01",
            "WIFI:T:WPA;S:Cafe\\;Bar;P:p\\:ss;;",
            "MECARD:N:Doe,John;TEL:+3212345678;;",
            "BEGIN:VEVENT\nSUMMARY:Lunch\nEND:VEVENT",
            "mailto:a@b.c",
            "tel:+3212345678",
            "smsto:3333:WIN",
            "geo:50.85,4.35?q=Brussels",
            "otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme",
            "spotify:track:123",
            "hello world",
        )
        var log = emptyList<HistoryEntry>()
        payloads.forEachIndexed { i, payload -> log = HistoryLog.add(log, entry(payload, now = i.toLong())) }

        assertEquals(payloads.size, log.size)
        assertEquals(
            listOf("paylink", "url", "epc", "emv", "upi", "crypto", "wifi", "contact", "event", "email", "phone", "sms", "geo", "otp", "applink", "text"),
            log.reversed().map { it.type },
        )
        // Newest first.
        assertEquals("text", log.first().type)
    }

    @Test
    fun `secrets are redacted before storing`() {
        val otp = entry("otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme")
        assertFalse("JBSWY3DPEHPK3PXP" in otp.payload)
        assertTrue(otp.redacted)
        assertEquals("danger", otp.level)

        val wifi = entry("WIFI:T:WPA;S:Cafe\\;Bar;P:p\\:ss;;")
        assertFalse("p\\:ss" in wifi.payload)
        assertTrue(wifi.redacted)
        assertEquals(HistoryEntry.LEVEL_NEUTRAL, wifi.level)

        assertFalse(entry("hello world").redacted)

        // A payment-app link is stored like any other typed entry: no host, its notice level, the link as scanned.
        val paylink = entry("https://payconiq.com/t/1/5f2a9c0e1b?D=Invoice%2042&A=1250&R=INV42")
        assertEquals("paylink", paylink.type)
        assertNull(paylink.host)
        assertEquals("caution", paylink.level)
        assertEquals("https://payconiq.com/t/1/5f2a9c0e1b?D=Invoice%2042&A=1250&R=INV42", paylink.payload)
    }

    @Test
    fun `a link starts unchecked and keeps its entry when the check fails`() {
        val link = entry("https://example.com/a")
        assertEquals("example.com", link.host)
        assertNull(link.level)

        var log = HistoryLog.add(listOf(entry("hello world", now = 500)), link)
        log = HistoryLog.setLevel(log, link.id, HistoryEntry.LEVEL_FAILED, now = 2_000)
        assertEquals(2, log.size)
        assertEquals(HistoryEntry.LEVEL_FAILED, log.first().level)
        assertEquals(2_000, log.first().timestamp)

        // Re-checking later updates the same entry instead of adding one.
        log = HistoryLog.setLevel(log, link.id, "ok", now = 3_000)
        assertEquals(2, log.size)
        assertEquals("ok", log.first { it.id == link.id }.level)
    }

    @Test
    fun `a re-checked entry moves to the top`() {
        val old = entry("https://old.example/", now = 100)
        val recent = entry("hello world", now = 200)
        val log = HistoryLog.setLevel(listOf(recent, old), old.id, "caution", now = 300)
        assertEquals(listOf(old.id, recent.id), log.map { it.id })
    }

    @Test
    fun `repeated scans of the same code are all kept`() {
        var log = emptyList<HistoryEntry>()
        repeat(3) { log = HistoryLog.add(log, entry("hello world", now = it.toLong())) }
        assertEquals(3, log.size)
        assertEquals(3, log.map { it.id }.toSet().size)
    }

    @Test
    fun `the log is capped at 500 entries, dropping the oldest`() {
        assertEquals(500, HistoryLog.MAX_ENTRIES)
        var log = emptyList<HistoryEntry>()
        repeat(505) { log = HistoryLog.add(log, entry("scan $it", now = it.toLong())) }
        assertEquals(500, log.size)
        assertEquals("scan 504", log.first().payload)
        assertEquals("scan 5", log.last().payload)
    }

    @Test
    fun `one entry can be deleted`() {
        val a = entry("hello world")
        val b = entry("tel:+3212345678")
        val c = entry("https://example.com/")
        val log = HistoryLog.delete(listOf(c, b, a), b.id)
        assertEquals(listOf(c.id, a.id), log.map { it.id })
        assertEquals(log, HistoryLog.delete(log, "no-such-id"))
    }
}
