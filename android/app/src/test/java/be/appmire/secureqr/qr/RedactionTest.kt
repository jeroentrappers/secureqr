package be.appmire.secureqr.qr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RedactionTest {

    @Test
    fun `otp secret is removed`() {
        val content = QrClassifier.classify("otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme")
        val redacted = Redaction.redact(content)
        assertEquals("otpauth://totp/Acme:joe?issuer=Acme", redacted)
        assertTrue(Redaction.hasSecret(content))

        // The redacted payload still parses into the same card.
        val again = QrClassifier.classify(redacted)
        assertEquals(QrType.OTP, again.type)
        assertEquals("Acme", again.field(FieldLabel.ISSUER))
        assertEquals("joe", again.field(FieldLabel.ACCOUNT))
    }

    @Test
    fun `otp secret is removed whatever its position or case`() {
        assertEquals(
            "otpauth://totp/x?issuer=A&digits=6",
            Redaction.redact(QrClassifier.classify("otpauth://totp/x?issuer=A&SECRET=ABC&digits=6")),
        )
        assertEquals("otpauth://totp/x", Redaction.redact(QrClassifier.classify("otpauth://totp/x?secret=ABC")))
    }

    @Test
    fun `wifi password is removed`() {
        val content = QrClassifier.classify("WIFI:T:WPA;S:Cafe\\;Bar;P:p\\:ss;;")
        val redacted = Redaction.redact(content)
        assertEquals("WIFI:T:WPA;S:Cafe\\;Bar;;", redacted)
        assertFalse("p\\:ss" in redacted)
        assertTrue(Redaction.hasSecret(content))

        val again = QrClassifier.classify(redacted)
        assertEquals(QrType.WIFI, again.type)
        assertEquals("Cafe;Bar", again.field(FieldLabel.NETWORK))
        assertNull(again.field(FieldLabel.PASSWORD))
        assertEquals(listOf(Notice.LOCAL_ONLY), again.notices)
    }

    @Test
    fun `wifi password containing an escaped separator is removed completely`() {
        val redacted = Redaction.redact(QrClassifier.classify("WIFI:S:Home;P:a\\;b\\;c;T:WPA;;"))
        assertEquals("WIFI:S:Home;T:WPA;;", redacted)
    }

    @Test
    fun `payloads without secrets are untouched`() {
        for (payload in listOf("WIFI:T:nopass;S:Open;;", "hello world", "tel:+3212345678", "https://example.com/?secret=1")) {
            val content = QrClassifier.classify(payload)
            assertEquals(payload, Redaction.redact(content))
            assertFalse(Redaction.hasSecret(content))
        }
    }
}
