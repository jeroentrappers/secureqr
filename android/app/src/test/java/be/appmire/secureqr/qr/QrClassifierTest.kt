package be.appmire.secureqr.qr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Covers every shared vector in docs/qr-types.md, plus the parsing rules around them. */
class QrClassifierTest {

    private fun classify(payload: String) = QrClassifier.classify(payload)

    // ---- shared test vectors ----------------------------------------------

    @Test
    fun `https url`() {
        val c = classify("https://example.com/a")
        assertEquals(QrType.URL, c.type)
        assertEquals("https://example.com/a", c.raw)
    }

    @Test
    fun `upper-case http url`() {
        assertEquals(QrType.URL, classify("HTTP://EXAMPLE.COM").type)
    }

    @Test
    fun `epc with valid iban`() {
        val c = classify("BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00\n\n\nGift\n")
        assertEquals(QrType.EPC, c.type)
        assertEquals("Rode Kruis", c.field(FieldLabel.BENEFICIARY))
        assertEquals("25.00 EUR", c.field(FieldLabel.AMOUNT))
        assertEquals("BE72 0000 0000 1616", c.field(FieldLabel.IBAN))
        assertEquals("BE72000000001616", c.fields.first { it.label == FieldLabel.IBAN }.copyValue)
        assertEquals("GKCCBEBB", c.field(FieldLabel.BIC))
        assertEquals("Gift", c.field(FieldLabel.MESSAGE))
        assertNull(c.field(FieldLabel.REFERENCE))
        assertTrue(Iban.isValid("BE72000000001616"))
        // The instruction comes first; no danger notice for a valid IBAN.
        assertEquals(listOf(Notice.EPC_INSTRUCTION, Notice.PAYMENT), c.notices)
        assertEquals(NoticeLevel.CAUTION, c.level)
        // Plain text, not a link: nothing to open or share.
        assertEquals(listOf(QrAction.COPY_IBAN, QrAction.COPY_ALL), c.actions)
    }

    @Test
    fun `epc with invalid iban gets a danger notice`() {
        val c = classify("BCD\n002\n1\nSCT\n\nX\nBE72000000001617\nEUR1\n")
        assertEquals(QrType.EPC, c.type)
        assertEquals("X", c.field(FieldLabel.BENEFICIARY))
        assertEquals("1 EUR", c.field(FieldLabel.AMOUNT))
        assertFalse(Iban.isValid("BE72000000001617"))
        assertEquals(listOf(Notice.EPC_INSTRUCTION, Notice.INVALID_IBAN, Notice.PAYMENT), c.notices)
        assertEquals(listOf(QrAction.COPY_IBAN, QrAction.COPY_ALL), c.actions)
        assertEquals(NoticeLevel.DANGER, Notice.INVALID_IBAN.level)
        assertEquals(NoticeLevel.DANGER, c.level)
    }

    @Test
    fun `emv merchant code`() {
        val c = classify(
            "00020101021129370016A000000677010111011300660000000005802TH530376454031005913Test Merchant6007Bangkok6304ABCD",
        )
        assertEquals(QrType.EMV, c.type)
        assertEquals("Test Merchant", c.field(FieldLabel.MERCHANT))
        assertEquals("Bangkok", c.field(FieldLabel.CITY))
        assertEquals("TH", c.field(FieldLabel.COUNTRY))
        assertEquals("100", c.field(FieldLabel.AMOUNT))
        assertEquals("THB", c.field(FieldLabel.CURRENCY))
        assertEquals(listOf(Notice.PAYMENT), c.notices)
    }

    @Test
    fun `upi payment`() {
        val c = classify("upi://pay?pa=shop@bank&pn=Corner%20Shop&am=120.50&cu=INR")
        assertEquals(QrType.UPI, c.type)
        assertEquals("Corner Shop", c.field(FieldLabel.PAYEE_NAME))
        assertEquals("shop@bank", c.field(FieldLabel.PAYEE_ADDRESS))
        assertEquals("120.50", c.field(FieldLabel.AMOUNT))
        assertEquals("INR", c.field(FieldLabel.CURRENCY))
        assertEquals(listOf(Notice.PAYMENT), c.notices)
    }

    @Test
    fun `bitcoin payment`() {
        val c = classify("bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01")
        assertEquals(QrType.CRYPTO, c.type)
        assertEquals("0.01", c.field(FieldLabel.AMOUNT))
        assertEquals("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq", c.field(FieldLabel.ADDRESS))
        assertEquals("Bitcoin", c.field(FieldLabel.NETWORK))
        assertEquals(listOf(Notice.PAYMENT, Notice.CRYPTO_IRREVERSIBLE), c.notices)
    }

    @Test
    fun `wifi with escapes`() {
        val c = classify("WIFI:T:WPA;S:Cafe\\;Bar;P:p\\:ss;;")
        assertEquals(QrType.WIFI, c.type)
        assertEquals("Cafe;Bar", c.field(FieldLabel.NETWORK))
        assertEquals("p:ss", c.field(FieldLabel.PASSWORD))
        assertEquals(FieldStyle.SECRET, c.fields.first { it.label == FieldLabel.PASSWORD }.style)
        assertEquals("WPA", c.field(FieldLabel.SECURITY))
        assertEquals(listOf(Notice.LOCAL_ONLY), c.notices)
        assertEquals(listOf(QrAction.COPY_PASSWORD), c.actions)
    }

    @Test
    fun `open wifi gets a caution notice`() {
        val c = classify("WIFI:T:nopass;S:Open;;")
        assertEquals(QrType.WIFI, c.type)
        assertEquals("Open", c.field(FieldLabel.NETWORK))
        assertEquals(listOf(Notice.WIFI_OPEN), c.notices)
        assertEquals(NoticeLevel.CAUTION, c.level)
        assertNull(c.field(FieldLabel.PASSWORD))
    }

    @Test
    fun `mecard contact`() {
        val c = classify("MECARD:N:Doe,John;TEL:+3212345678;;")
        assertEquals(QrType.CONTACT, c.type)
        assertEquals("John Doe", c.field(FieldLabel.NAME))
        assertEquals(listOf("+3212345678"), c.fields(FieldLabel.PHONE))
        assertEquals(listOf(Notice.LOCAL_ONLY), c.notices)
    }

    @Test
    fun `phone number`() {
        val c = classify("tel:+3212345678")
        assertEquals(QrType.PHONE, c.type)
        assertEquals("+3212345678", c.field(FieldLabel.NUMBER))
    }

    @Test
    fun `sms to a short code gets a caution notice`() {
        val c = classify("smsto:3333:WIN")
        assertEquals(QrType.SMS, c.type)
        assertEquals("3333", c.field(FieldLabel.NUMBER))
        assertEquals("WIN", c.field(FieldLabel.MESSAGE))
        assertEquals(listOf(Notice.SMS_SHORT_CODE), c.notices)
        assertEquals(NoticeLevel.CAUTION, c.level)
    }

    @Test
    fun `geo location`() {
        val c = classify("geo:50.85,4.35?q=Brussels")
        assertEquals(QrType.GEO, c.type)
        assertEquals("50.85", c.field(FieldLabel.LATITUDE))
        assertEquals("4.35", c.field(FieldLabel.LONGITUDE))
        assertEquals("Brussels", c.field(FieldLabel.LABEL))
    }

    @Test
    fun `otp secret is never displayed`() {
        val c = classify("otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme")
        assertEquals(QrType.OTP, c.type)
        assertEquals("Acme", c.field(FieldLabel.ISSUER))
        assertEquals("joe", c.field(FieldLabel.ACCOUNT))
        assertEquals("TOTP", c.field(FieldLabel.TYPE))
        assertTrue(c.fields.none { "JBSWY3DPEHPK3PXP" in it.value || "JBSWY3DPEHPK3PXP" in it.copyValue })
        assertEquals(listOf(Notice.OTP_SECRET), c.notices)
        assertEquals(NoticeLevel.DANGER, c.level)
    }

    @Test
    fun `other scheme is an app link`() {
        val c = classify("spotify:track:123")
        assertEquals(QrType.APPLINK, c.type)
        assertEquals("spotify", c.field(FieldLabel.SCHEME))
        assertEquals("spotify:track:123", c.field(FieldLabel.TEXT))
        assertEquals(listOf(Notice.APP_LINK), c.notices)
    }

    @Test
    fun `plain text`() {
        val c = classify("hello world")
        assertEquals(QrType.TEXT, c.type)
        assertEquals("hello world", c.field(FieldLabel.TEXT))
        assertEquals(listOf(Notice.LOCAL_ONLY), c.notices)
        assertEquals(listOf(QrAction.COPY), c.actions)
    }

    @Test
    fun `emv prefix that is not clean tlv falls through to text`() {
        assertEquals(QrType.TEXT, classify("000201 not tlv").type)
    }

    // ---- rules around the vectors -----------------------------------------

    @Test
    fun `surrounding whitespace is trimmed and prefixes are case-insensitive`() {
        assertEquals(QrType.URL, classify("  \n https://example.com \n").type)
        assertEquals("https://example.com", classify("  https://example.com \n").raw)
        assertEquals(QrType.WIFI, classify("wifi:T:WPA;S:x;P:y;;").type)
        assertEquals(QrType.PHONE, classify("TEL:123").type)
        assertEquals(QrType.UPI, classify("UPI://PAY?pa=a@b").type)
        assertEquals(QrType.OTP, classify("OTPAUTH://totp/x?secret=A").type)
        assertEquals(QrType.CONTACT, classify("begin:vcard\nFN:A\nend:vcard").type)
    }

    @Test
    fun `epc with crlf line endings and missing trailing lines`() {
        val c = classify("BCD\r\n001\r\n1\r\nSCT\r\nGKCCBEBB\r\nRode Kruis\r\nBE72000000001616")
        assertEquals(QrType.EPC, c.type)
        assertEquals("Rode Kruis", c.field(FieldLabel.BENEFICIARY))
        assertNull(c.field(FieldLabel.AMOUNT))
        assertEquals(listOf(Notice.EPC_INSTRUCTION, Notice.PAYMENT), c.notices)
    }

    @Test
    fun `epc structured reference`() {
        val c = classify("BCD\n002\n1\nSCT\n\nShop\nBE72000000001616\nEUR9.99\n\n+++123/4567/89012+++\n\n")
        assertEquals("+++123/4567/89012+++", c.field(FieldLabel.REFERENCE))
        assertNull(c.field(FieldLabel.BIC))
    }

    @Test
    fun `iban check`() {
        assertTrue(Iban.isValid("BE72 0000 0000 1616"))
        assertTrue(Iban.isValid("GB82 WEST 1234 5698 7654 32"))
        assertTrue(Iban.isValid("de89370400440532013000"))
        assertFalse(Iban.isValid("GB82 WEST 1234 5698 7654 33"))
        assertFalse(Iban.isValid(""))
        assertFalse(Iban.isValid("BE72"))
        assertFalse(Iban.isValid("BE72-0000-0000-1616"))
    }

    @Test
    fun `emv unknown currency shows the number and truncated tlv is text`() {
        val c = classify("0002015303999")
        assertEquals(QrType.EMV, c.type)
        assertEquals("999", c.field(FieldLabel.CURRENCY))
        assertEquals(QrType.TEXT, classify("00020153039").type)
        assertEquals(QrType.TEXT, classify("0002015").type)
    }

    @Test
    fun `crypto schemes`() {
        assertEquals("Ethereum", classify("ethereum:0xAbC?value=1e18").field(FieldLabel.NETWORK))
        assertEquals("1e18", classify("ethereum:0xAbC?value=1e18").field(FieldLabel.AMOUNT))
        assertEquals("Litecoin", classify("litecoin:Labc").field(FieldLabel.NETWORK))
        assertEquals("Bitcoin Cash", classify("bitcoincash:qabc").field(FieldLabel.NETWORK))
        val lightning = classify("LIGHTNING:lnbc1abc")
        assertEquals(QrType.CRYPTO, lightning.type)
        assertEquals("lnbc1abc", lightning.field(FieldLabel.ADDRESS))
        val labelled = classify("bitcoin:abc?label=Shop%20One&message=Order%2042")
        assertEquals("Shop One", labelled.field(FieldLabel.LABEL))
        assertEquals("Order 42", labelled.field(FieldLabel.MESSAGE))
    }

    @Test
    fun `wifi details`() {
        val hidden = classify("WIFI:S:Home;T:WPA;P:a\\\\b\\,c;H:true;;")
        assertEquals("a\\b,c", hidden.field(FieldLabel.PASSWORD))
        assertEquals("true", hidden.field(FieldLabel.HIDDEN))
        val noType = classify("WIFI:S:Lobby;;")
        assertEquals("", noType.field(FieldLabel.SECURITY))
        assertEquals(listOf(Notice.WIFI_OPEN), noType.notices)
        assertNull(noType.field(FieldLabel.HIDDEN))
    }

    @Test
    fun `mecard with escaped comma and several numbers`() {
        val c = classify("MECARD:N:Doe\\, Jr,John;TEL:1;TEL:2;EMAIL:a@b.c;ORG:Acme;ADR:1 Main St, Town;URL:https\\://a.b;;")
        assertEquals("John Doe, Jr", c.field(FieldLabel.NAME))
        assertEquals(listOf("1", "2"), c.fields(FieldLabel.PHONE))
        assertEquals("a@b.c", c.field(FieldLabel.EMAIL))
        assertEquals("Acme", c.field(FieldLabel.ORGANISATION))
        assertEquals("1 Main St, Town", c.field(FieldLabel.ADDRESS))
        assertEquals("https://a.b", c.field(FieldLabel.URL))
    }

    @Test
    fun `vcard ignores parameters`() {
        val c = classify(
            "BEGIN:VCARD\r\nVERSION:3.0\r\nN:Doe;Jane;;;\r\nTEL;TYPE=CELL:+3211\r\nTEL;TYPE=WORK:+3222\r\n" +
                "EMAIL;TYPE=INTERNET:jane@example.com\r\nORG:Acme;Sales\r\nADR;TYPE=WORK:;;1 Main St;Ghent;;9000;Belgium\r\n" +
                "item1.URL:https://example.com\r\nEND:VCARD",
        )
        assertEquals(QrType.CONTACT, c.type)
        assertEquals("Jane Doe", c.field(FieldLabel.NAME))
        assertEquals(listOf("+3211", "+3222"), c.fields(FieldLabel.PHONE))
        assertEquals("jane@example.com", c.field(FieldLabel.EMAIL))
        assertEquals("Acme, Sales", c.field(FieldLabel.ORGANISATION))
        assertEquals("1 Main St, Ghent, 9000, Belgium", c.field(FieldLabel.ADDRESS))
        assertEquals("https://example.com", c.field(FieldLabel.URL))

        assertEquals("Jane Q. Doe", classify("BEGIN:VCARD\nN:Doe;Jane\nFN:Jane Q. Doe\nEND:VCARD").field(FieldLabel.NAME))
    }

    @Test
    fun `calendar event`() {
        val c = classify(
            "BEGIN:VCALENDAR\nBEGIN:VTIMEZONE\nDTSTART:19700101T000000\nEND:VTIMEZONE\nBEGIN:VEVENT\nSUMMARY:Team lunch\n" +
                "DTSTART;TZID=Europe/Brussels:20260314T123000\nDTEND:20260314T133000Z\nLOCATION:Canteen\\, floor 2\n" +
                "DESCRIPTION:Bring\n  your badge\nEND:VEVENT\nEND:VCALENDAR",
        )
        assertEquals(QrType.EVENT, c.type)
        assertEquals("Team lunch", c.field(FieldLabel.TITLE))
        assertEquals("2026-03-14 12:30", c.field(FieldLabel.START))
        assertEquals("2026-03-14 13:30 UTC", c.field(FieldLabel.END))
        assertEquals("Canteen, floor 2", c.field(FieldLabel.LOCATION))
        assertEquals("Bring your badge", c.field(FieldLabel.DESCRIPTION))

        val bare = classify("BEGIN:VEVENT\nSUMMARY:Day off\nDTSTART;VALUE=DATE:20260501\nEND:VEVENT")
        assertEquals(QrType.EVENT, bare.type)
        assertEquals("2026-05-01", bare.field(FieldLabel.START))
    }

    @Test
    fun `email forms`() {
        val mailto = classify("mailto:a@b.c?subject=Hi%20there&body=Line%201")
        assertEquals(QrType.EMAIL, mailto.type)
        assertEquals("a@b.c", mailto.field(FieldLabel.TO))
        assertEquals("Hi there", mailto.field(FieldLabel.SUBJECT))
        assertEquals("Line 1", mailto.field(FieldLabel.BODY))

        val matmsg = classify("MATMSG:TO:a@b.c;SUB:Hi;BODY:Text;;")
        assertEquals(QrType.EMAIL, matmsg.type)
        assertEquals("a@b.c", matmsg.field(FieldLabel.TO))
        assertEquals("Hi", matmsg.field(FieldLabel.SUBJECT))
        assertEquals("Text", matmsg.field(FieldLabel.BODY))
    }

    @Test
    fun `sms forms`() {
        val query = classify("sms:+3212345678?body=Hello%20you")
        assertEquals("+3212345678", query.field(FieldLabel.NUMBER))
        assertEquals("Hello you", query.field(FieldLabel.MESSAGE))
        assertEquals(listOf(Notice.LOCAL_ONLY), query.notices)
        assertEquals(listOf(Notice.SMS_SHORT_CODE), classify("sms:123").notices)
        assertEquals(listOf(Notice.LOCAL_ONLY), classify("sms:1234567").notices)
        assertEquals(listOf(Notice.LOCAL_ONLY), classify("sms:12").notices)
    }

    @Test
    fun `otp without issuer prefix`() {
        val c = classify("otpauth://hotp/joe%40example.com?secret=ABC&counter=1")
        assertEquals("joe@example.com", c.field(FieldLabel.ACCOUNT))
        assertNull(c.field(FieldLabel.ISSUER))
        assertEquals("HOTP", c.field(FieldLabel.TYPE))
    }

    @Test
    fun `app link scheme limits`() {
        assertEquals(QrType.APPLINK, classify("ab:c").type)
        assertEquals(QrType.TEXT, classify("a:c").type)
        assertEquals(QrType.TEXT, classify("1ab:c").type)
        assertEquals(QrType.TEXT, classify("").type)
        assertEquals(QrType.TEXT, classify("not a scheme: text").type)
    }

    @Test
    fun `copying a sign-in secret never copies the secret`() {
        val secret = "JBSWY3DPEHPK3PXP"
        val full = classify("otpauth://totp/Acme:joe?secret=$secret&issuer=Acme")
        assertEquals(listOf(QrAction.COPY), full.actions)
        assertEquals("Acme (joe)", full.copyText)
        assertFalse(secret in full.copyText)

        val cases = listOf(
            "otpauth://totp/joe%40example.com?secret=$secret" to "joe@example.com",
            "otpauth://totp/?secret=$secret&issuer=Acme" to "Acme",
            "otpauth://totp?secret=$secret" to "otpauth://totp",
            "otpauth://hotp/Acme:joe?SECRET=$secret&counter=1" to "Acme (joe)",
        )
        for ((payload, expected) in cases) {
            val text = classify(payload).copyText
            assertEquals(expected, text)
            assertFalse(secret in text)
        }
        // Everything else copies the scanned text unchanged.
        assertEquals("hello world", classify(" hello world ").copyText)
        assertEquals("tel:+3212345678", classify("tel:+3212345678").copyText)
    }

    @Test
    fun `what is opened is the scanned string itself`() {
        // Payment codes with an app scheme keep "Open in app" and their original string, whatever its case.
        val payloads = listOf(
            "upi://pay?pa=shop@bank&pn=Corner%20Shop&am=120.50&cu=INR",
            "bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01",
            "BEP://1BE.MOB.BANCONTACT.NET/ABC123\$XYZ",
            "bankapp://pay?id=42",
        )
        for (payload in payloads) {
            val c = classify(payload)
            assertTrue(payload, QrAction.OPEN_IN_APP in c.actions)
            assertEquals(payload, c.raw)
        }
        assertEquals(QrType.APPLINK, classify(payloads[2]).type)

        // A web payment link that is not in the payment-app table is an ordinary link:
        // preview first, then the original URL.
        val link = classify("https://pay.example-bank.be/p/9f3a?amount=12.50&ref=A%2FB")
        assertEquals(QrType.URL, link.type)
        assertEquals("https://pay.example-bank.be/p/9f3a?amount=12.50&ref=A%2FB", link.raw)

        // Surrounding whitespace is the only thing ever removed.
        assertEquals("https://example.com/a", classify("  https://example.com/a \n").raw)

        // No card offers to share or to open a bank transfer.
        for (type in QrAction.entries) assertFalse(type.name, type.name == "SHARE" || type.name == "OPEN_IN_BANKING_APP")
    }

    // ---- payment-app links ----------------------------------------------------

    @Test
    fun `payconiq invoice link`() {
        val payload = "https://payconiq.com/t/1/5f2a9c0e1b?D=Invoice%2042&A=1250&R=INV42"
        val c = classify(payload)
        assertEquals(QrType.PAYLINK, c.type)
        assertEquals("Bancontact (Payconiq)", c.field(FieldLabel.PROVIDER))
        assertEquals("12.50 EUR", c.field(FieldLabel.AMOUNT))
        assertEquals("Invoice 42", c.field(FieldLabel.DESCRIPTION))
        assertEquals("INV42", c.field(FieldLabel.REFERENCE))
        assertEquals(listOf(Notice.PAYLINK), c.notices)
        assertEquals(NoticeLevel.CAUTION, c.level)
        assertEquals(listOf(QrAction.OPEN_IN_PAYMENT_APP, QrAction.COPY), c.actions)
        // What gets opened and copied is the scanned link, untouched.
        assertEquals(payload, c.raw)
        assertEquals(payload, c.copyText)
        assertEquals("Bancontact (Payconiq)", c.summary)
    }

    @Test
    fun `upper-case payconiq sticker link has no amount`() {
        val payload = "HTTPS://PAYCONIQ.COM/L/1/5F2A9C0E1B/POS01"
        val c = classify(payload)
        assertEquals(QrType.PAYLINK, c.type)
        assertEquals("Bancontact (Payconiq)", c.field(FieldLabel.PROVIDER))
        assertNull(c.field(FieldLabel.AMOUNT))
        assertNull(c.field(FieldLabel.DESCRIPTION))
        assertNull(c.field(FieldLabel.REFERENCE))
        assertEquals(payload, c.raw)
    }

    @Test
    fun `look-alike payconiq host is an ordinary link`() {
        val c = classify("https://payconiq.com.evil.example/t/1/x")
        assertEquals(QrType.URL, c.type)
        assertTrue(c.fields.isEmpty())
    }

    @Test
    fun `payment-app host matching`() {
        val paylinks = listOf(
            "https://payconiq.com",
            "http://payconiq.com/t/1/x",
            "https://www.payconiq.com/t/1/x",
            "https://portal.Payconiq.COM/t/1/x",
            "https://a.b.payconiq.com/l/1/x/y",
            "https://payconiq.com:443/t/1/x",
            "https://payconiq.com./t/1/x",
            "https://payconiq.com?A=100",
        )
        for (payload in paylinks) assertEquals(payload, QrType.PAYLINK, classify(payload).type)

        val ordinary = listOf(
            "https://payconiq.com.evil.example/t/1/x",
            "https://evil-payconiq.com/t/1/x",
            "https://notpayconiq.com/t/1/x",
            "https://payconiq.co/t/1/x",
            "https://payconiq.com.be/t/1/x",
            "https://payconiq.com@evil.example/t/1/x",
            "https://user:pw@evil.example/payconiq.com",
            "https://evil.example/payconiq.com/t/1/x",
            "https://evil.example/?next=https://payconiq.com/t/1/x",
            "https://evil.example/#payconiq.com",
            "https://example.com/a",
        )
        for (payload in ordinary) {
            assertEquals(payload, QrType.URL, classify(payload).type)
            assertNull(payload, PaymentHosts.providerFor(payload))
        }
        // Only web links: other schemes on that name are not payment-app links.
        assertEquals(QrType.APPLINK, classify("ftp://payconiq.com/x").type)
    }

    @Test
    fun `payconiq amount and text parsing`() {
        assertEquals("0.05 EUR", classify("https://payconiq.com/t/1/x?A=5").field(FieldLabel.AMOUNT))
        assertEquals("1.00 EUR", classify("https://payconiq.com/t/1/x?a=100").field(FieldLabel.AMOUNT))
        assertEquals("1234.56 EUR", classify("https://payconiq.com/t/1/x?A=123456").field(FieldLabel.AMOUNT))
        // Anything that is not whole cents is not shown as an amount.
        assertNull(classify("https://payconiq.com/t/1/x?A=12.50").field(FieldLabel.AMOUNT))
        assertNull(classify("https://payconiq.com/t/1/x?A=-5").field(FieldLabel.AMOUNT))
        assertNull(classify("https://payconiq.com/t/1/x?A=").field(FieldLabel.AMOUNT))
        val decoded = classify("https://payconiq.com/t/1/x?D=Caf%C3%A9%20%26%20co&R=A%2FB+1")
        assertEquals("Café & co", decoded.field(FieldLabel.DESCRIPTION))
        assertEquals("A/B 1", decoded.field(FieldLabel.REFERENCE))
    }

    @Test
    fun `summary line for lists`() {
        assertEquals("Rode Kruis", classify("BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00").summary)
        assertEquals("Cafe;Bar", classify("WIFI:T:WPA;S:Cafe\\;Bar;P:p\\:ss;;").summary)
        assertEquals("Acme", classify("otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme").summary)
        assertEquals("John Doe", classify("MECARD:N:Doe,John;TEL:+3212345678;;").summary)
        assertEquals("3333", classify("smsto:3333:WIN").summary)
        assertEquals("hello world", classify("hello world\nsecond line").summary)
        assertEquals("spotify:track:123", classify("spotify:track:123").summary)
        assertEquals("BCD", classify("BCD\n002\n1\nSCT").summary)
    }

    @Test
    fun `percent decoding`() {
        assertEquals("a b", percentDecode("a%20b"))
        assertEquals("é€", percentDecode("%C3%A9%E2%82%AC"))
        assertEquals("100%", percentDecode("100%"))
        assertEquals("%zz", percentDecode("%zz"))
        assertEquals("a+b", percentDecode("a+b"))
        assertEquals("a b", percentDecode("a+b", plusAsSpace = true))
    }

    @Test
    fun `host extraction`() {
        assertEquals("example.com", hostOf("HTTPS://Example.COM/a?b"))
        assertEquals("example.com", hostOf("https://user:pw@example.com:8443/a"))
        assertEquals("[::1]", hostOf("http://[::1]:8080/"))
        assertNull(hostOf("hello world"))
    }
}
