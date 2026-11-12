package be.appmire.secureqr.qr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId

/** The shared vectors in docs/qr-types.md for sign-in codes, chat links, unsafe links and the other special codes. */
class SpecialCodesTest {

    private fun classify(payload: String) = QrClassifier.classify(payload)

    /** What history keeps, and that it reopens as the same card. */
    private fun kept(content: QrContent): String {
        val redacted = Redaction.redact(content)
        assertEquals(content.type, classify(redacted).type)
        return redacted
    }

    // ---- sign-in codes ------------------------------------------------------

    @Test
    fun `sign-in codes of other services`() {
        val cases = mapOf(
            "https://discord.com/ra/AbCdEf123456" to "Discord",
            "HTTPS://DISCORD.COM/RA/AbCdEf123456" to "Discord",
            "https://s.team/q/1/1234567890" to "Steam",
            "https://login.weixin.qq.com/l/abc==" to "WeChat",
            "tg://login?token=abc" to "Telegram",
            "sgnl://linkdevice?uuid=1&pub_key=2" to "Signal",
            "2@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl,MnOpQrStUvWxYzAb,CdEfGhIjKlMnOpQr" to "WhatsApp",
        )
        for ((payload, service) in cases) {
            val c = classify(payload)
            assertEquals(payload, QrType.LOGIN, c.type)
            assertEquals(service, c.field(FieldLabel.SERVICE))
            assertEquals(listOf(Notice.LOGIN_CODE), c.notices)
            assertEquals(NoticeLevel.DANGER, c.level)
            assertTrue(payload, c.actions.isEmpty())
        }
    }

    @Test
    fun `other pages on a sign-in host are ordinary links`() {
        assertEquals(QrType.URL, classify("https://discord.com/invite/abc").type)
        assertEquals(QrType.URL, classify("https://discord.com.evil.example/ra/abc").type)
        assertEquals(QrType.TEXT, classify("2@short,parts,here").type)
    }

    @Test
    fun `a sign-in code is not kept`() {
        assertEquals("https://discord.com/ra/…", kept(classify("https://discord.com/ra/AbCdEf123456")))
        assertEquals("https://s.team/q/…", kept(classify("https://s.team/q/1/1234567890")))
        assertEquals("tg://login…", kept(classify("tg://login?token=abc")))
        assertEquals("2@…", kept(classify("2@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl,MnOpQrStUvWxYzAb,CdEfGhIjKlMnOpQr")))
    }

    // ---- chat links ---------------------------------------------------------

    @Test
    fun `whatsapp link`() {
        val c = classify("https://wa.me/3212345678?text=Hi%20there")
        assertEquals(QrType.CHAT, c.type)
        assertEquals("WhatsApp", c.field(FieldLabel.SERVICE))
        assertEquals("+3212345678", c.field(FieldLabel.NUMBER))
        assertEquals("Hi there", c.field(FieldLabel.MESSAGE))
        assertEquals(listOf(Notice.CHAT_LINK), c.notices)
        assertEquals(listOf(QrAction.OPEN_IN_APP, QrAction.COPY), c.actions)
        assertEquals("+3212345678", c.summary)

        assertEquals("+3212345678", classify("https://api.whatsapp.com/send?phone=3212345678").field(FieldLabel.NUMBER))
        assertEquals("+3212345678", classify("whatsapp://send?phone=+3212345678").field(FieldLabel.NUMBER))
    }

    @Test
    fun `telegram links`() {
        val c = classify("https://t.me/some_shop")
        assertEquals(QrType.CHAT, c.type)
        assertEquals("Telegram", c.field(FieldLabel.SERVICE))
        assertEquals("@some_shop", c.field(FieldLabel.HANDLE))

        assertEquals("@some_shop", classify("tg://resolve?domain=some_shop").field(FieldLabel.HANDLE))
        assertEquals(SpecialCodes.INVITE, classify("https://t.me/+AbCdEf").field(FieldLabel.HANDLE))
        assertEquals(SpecialCodes.INVITE, classify("https://t.me/joinchat/AbCdEf").field(FieldLabel.HANDLE))
    }

    @Test
    fun `other chat services`() {
        assertEquals("Messenger", classify("https://m.me/some.page").field(FieldLabel.SERVICE))
        assertEquals("Signal", classify("https://signal.me/#p/+3212345678").field(FieldLabel.SERVICE))
        val viber = classify("viber://chat?number=%2B3212345678")
        assertEquals("Viber", viber.field(FieldLabel.SERVICE))
        assertEquals("+3212345678", viber.field(FieldLabel.NUMBER))
    }

    // ---- unsafe links -------------------------------------------------------

    @Test
    fun `links that must not be opened`() {
        for ((payload, scheme) in mapOf(
            "javascript:alert(1)" to "javascript",
            "intent://scan/#Intent;scheme=zxing;end" to "intent",
            "DATA:text/html,<script>x</script>" to "data",
            "file:///sdcard/x.html" to "file",
        )) {
            val c = classify(payload)
            assertEquals(payload, QrType.UNSAFE, c.type)
            assertEquals(scheme, c.field(FieldLabel.SCHEME))
            assertEquals(NoticeLevel.DANGER, c.level)
            assertEquals(listOf(QrAction.COPY), c.actions)
        }
        assertEquals(QrType.APPLINK, classify("spotify:track:123").type)
    }

    // ---- phone numbers ------------------------------------------------------

    @Test
    fun `ordinary phone number`() {
        val c = classify("tel:+3212345678")
        assertEquals(listOf(Notice.LOCAL_ONLY), c.notices)
        assertEquals(listOf(QrAction.OPEN_IN_APP, QrAction.COPY), c.actions)
    }

    @Test
    fun `service code is never dialled`() {
        val c = classify("tel:*21*0032475000000%23")
        assertEquals(QrType.PHONE, c.type)
        assertEquals("*21*0032475000000#", c.field(FieldLabel.NUMBER))
        assertEquals(listOf(Notice.DIALER_CODE), c.notices)
        assertEquals(listOf(QrAction.COPY), c.actions)
    }

    @Test
    fun `premium numbers get a caution`() {
        for (payload in listOf("tel:090312345", "tel:+32 903 12 345", "tel:+1 900 555 1234", "tel:0900-1234")) {
            val c = classify(payload)
            assertEquals(payload, listOf(Notice.PREMIUM_NUMBER), c.notices)
            assertEquals(listOf(QrAction.OPEN_IN_APP, QrAction.COPY), c.actions)
        }
        assertFalse(SpecialCodes.isPremiumNumber("+32 475 90 00 00"))
    }

    // ---- bank transfers -----------------------------------------------------

    @Test
    fun `swiss qr-bill`() {
        val payload = listOf(
            "SPC", "0200", "1", "CH4431999123000889012", "S", "Robert Schneider AG", "Rue du Lac", "1268", "2501", "Biel", "CH",
            "", "", "", "", "", "", "", "1949.75", "CHF", "", "", "", "", "", "", "",
            "QRR", "210000000003139471430009017", "Order 42", "EPD",
        ).joinToString("\n")
        val c = classify(payload)
        assertEquals(QrType.SWISSQR, c.type)
        assertEquals("Robert Schneider AG", c.field(FieldLabel.BENEFICIARY))
        assertEquals("1949.75 CHF", c.field(FieldLabel.AMOUNT))
        assertEquals("210000000003139471430009017", c.field(FieldLabel.REFERENCE))
        assertEquals("Order 42", c.field(FieldLabel.MESSAGE))
        assertEquals("CH4431999123000889012", c.fields.first { it.label == FieldLabel.IBAN }.copyValue)
        assertEquals(listOf(Notice.EPC_INSTRUCTION, Notice.PAYMENT), c.notices)
        assertEquals(listOf(QrAction.COPY_IBAN, QrAction.COPY_ALL), c.actions)
    }

    @Test
    fun `czech payment code`() {
        val c = classify("SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK*MSG:Platba%20za%20zbozi*RN:Jan Novak*X-VS:1234567890")
        assertEquals(QrType.SPD, c.type)
        assertEquals("Jan Novak", c.field(FieldLabel.BENEFICIARY))
        assertEquals("480.50 CZK", c.field(FieldLabel.AMOUNT))
        assertEquals("Platba za zbozi", c.field(FieldLabel.MESSAGE))
        assertEquals("1234567890", c.field(FieldLabel.REFERENCE))
        assertEquals(listOf(Notice.EPC_INSTRUCTION, Notice.PAYMENT), c.notices)

        val bad = classify("SPD*1.0*ACC:CZ5855000000001265098002+KOMBCZPP*AM:1")
        assertTrue(Notice.INVALID_IBAN in bad.notices)
        assertEquals("CZ5855000000001265098002", bad.fields.first { it.label == FieldLabel.IBAN }.copyValue)
    }

    @Test
    fun `pix code`() {
        val c = classify("00020126360014br.gov.bcb.pix0114+5561999999999520400005303986540510.005802BR5908Loja Sul6008Brasilia6304ABCD")
        assertEquals(QrType.EMV, c.type)
        assertEquals("Pix", c.field(FieldLabel.PROVIDER))
        assertEquals("+5561999999999", c.field(FieldLabel.PAYEE_ADDRESS))
        assertEquals("Loja Sul", c.field(FieldLabel.MERCHANT))
        assertEquals("10.00", c.field(FieldLabel.AMOUNT))
        assertEquals("BRL", c.field(FieldLabel.CURRENCY))
    }

    // ---- codes that are only explained --------------------------------------

    @Test
    fun `authenticator export`() {
        val c = classify("otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU")
        assertEquals(QrType.OTP_EXPORT, c.type)
        assertEquals(NoticeLevel.DANGER, c.level)
        assertTrue(c.fields.isEmpty())
        assertTrue(c.actions.isEmpty())
        assertEquals("otpauth-migration://…", kept(c))
    }

    @Test
    fun `esim plan`() {
        val c = classify("LPA:1\$smdp.example.com\$ABCD-1234-EFGH")
        assertEquals(QrType.ESIM, c.type)
        assertEquals("smdp.example.com", c.field(FieldLabel.ADDRESS))
        assertEquals(FieldStyle.SECRET, c.fields.first { it.label == FieldLabel.ACTIVATION_CODE }.style)
        assertEquals(listOf(Notice.ESIM_INSTRUCTION, Notice.ESIM), c.notices)
        assertEquals(NoticeLevel.CAUTION, c.level)
        assertEquals(listOf(QrAction.COPY), c.actions)
        assertEquals("LPA:1\$smdp.example.com\$…", kept(c))
        assertEquals("smdp.example.com", classify(kept(c)).summary)
    }

    @Test
    fun `smart-home setup codes`() {
        val matter = classify("MT:Y.K9042C00KA0648G00")
        assertEquals(QrType.DEVICE, matter.type)
        assertEquals("Matter", matter.field(FieldLabel.TYPE))
        assertTrue(matter.actions.isEmpty())
        assertEquals("MT:…", kept(matter))

        val homekit = classify("X-HM://0023ISYWYABCD")
        assertEquals("HomeKit", homekit.field(FieldLabel.TYPE))
        assertEquals("X-HM://…", kept(homekit))
        assertEquals("Wi-Fi Easy Connect", classify("DPP:C:81/1;M:5254005828e5;K:abc;;").field(FieldLabel.TYPE))
    }

    @Test
    fun `health certificates`() {
        val c = classify("HC1:6BF+70790T9WJWG.FKY*4GO0.O1CV2 O5 N2FBBRW1*70HS8WY04AC*WIFN0AHCD8KD97TK0F90KECTHGWJC0FDC:5AIA%G7X+AQB9746HS80")
        assertEquals(QrType.HEALTHCERT, c.type)
        assertEquals(NoticeLevel.CAUTION, c.level)
        assertTrue(c.actions.isEmpty())
        assertEquals("HC1:…", kept(c))
        assertEquals("shc:/…", kept(classify("shc:/5676290952432060346029243740446031222959")))
    }

    // ---- contacts and calendar ----------------------------------------------

    @Test
    fun `contact can be added`() {
        assertEquals(
            listOf(QrAction.ADD_CONTACT, QrAction.COPY_ALL),
            classify("MECARD:N:Doe,John;TEL:+3212345678;;").actions,
        )
    }

    @Test
    fun `event can be added when its start parses`() {
        val event = "BEGIN:VEVENT\nSUMMARY:Team lunch\nDTSTART:20261203T120000Z\nDTEND:20261203T130000Z\nLOCATION:Canteen\nEND:VEVENT"
        assertEquals(listOf(QrAction.ADD_EVENT, QrAction.COPY_ALL), classify(event).actions)
        val times = QrClassifier.eventTimes(event)
        assertNotNull(times)
        assertEquals(1796299200000L, times!!.start)
        assertEquals(1796302800000L, times.end)
        assertFalse(times.allDay)

        assertEquals(listOf(QrAction.COPY_ALL), classify("BEGIN:VEVENT\nSUMMARY:No date\nEND:VEVENT").actions)
    }

    @Test
    fun `event times`() {
        val brussels = ZoneId.of("Europe/Brussels")
        // Local time without Z is the phone's own zone: 12:00 in Brussels in December is 11:00 UTC.
        val local = SpecialCodes.eventTimes("20261203T1200", null, brussels)!!
        assertEquals(1796295600000L, local.start)
        assertEquals(local.start + 3_600_000L, local.end)

        val allDay = SpecialCodes.eventTimes("20261203", "20261203", brussels)!!
        assertTrue(allDay.allDay)
        assertEquals(1796256000000L, allDay.start)
        assertEquals(allDay.start + 86_400_000L, allDay.end)

        assertNull(SpecialCodes.eventTimes("next week", null, brussels))
        assertNull(SpecialCodes.eventTimes("20261340", null, brussels))
    }
}
