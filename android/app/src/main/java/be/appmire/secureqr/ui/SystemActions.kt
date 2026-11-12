package be.appmire.secureqr.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiNetworkSuggestion
import android.os.Build
import android.os.PersistableBundle
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.Settings
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.annotation.StringRes
import androidx.core.net.toUri
import be.appmire.secureqr.R
import be.appmire.secureqr.qr.FieldLabel
import be.appmire.secureqr.qr.QrClassifier
import be.appmire.secureqr.qr.QrContent
import be.appmire.secureqr.qr.QrType
import be.appmire.secureqr.qr.WifiKind
import be.appmire.secureqr.qr.wifiKind

/** The only places where the app hands something to the rest of the system. Each needs an explicit tap. */
object SystemActions {

    fun toast(context: Context, @StringRes message: Int) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    /**
     * Opens the scanned link with a plain VIEW intent for the original URL:
     * no forced browser, no Custom Tabs. An installed app that owns the link
     * (Android App Links, for example a bank or wallet) therefore takes over;
     * otherwise the user's browser opens it.
     */
    fun openLink(context: Context, url: String): Boolean = view(context, url)

    /**
     * Hands a non-link payload to whichever app handles it, as the original
     * scanned string. The only payloads that are rewritten are the two forms
     * Android cannot open as they are: `smsto:number:message` and `MATMSG:`.
     */
    fun openInApp(context: Context, content: QrContent): Boolean {
        val raw = content.raw
        val rewritten = when {
            content.type == QrType.SMS && raw.substringAfter(':').substringBefore('?').contains(':') -> Intent(
                Intent.ACTION_SENDTO,
                Uri.fromParts("smsto", content.field(FieldLabel.NUMBER).orEmpty(), null),
            ).putExtra("sms_body", content.field(FieldLabel.MESSAGE).orEmpty())

            content.type == QrType.EMAIL && !raw.startsWith("mailto:", ignoreCase = true) -> Intent(
                Intent.ACTION_SENDTO,
                Uri.fromParts("mailto", content.field(FieldLabel.TO).orEmpty(), null),
            )
                .putExtra(Intent.EXTRA_SUBJECT, content.field(FieldLabel.SUBJECT).orEmpty())
                .putExtra(Intent.EXTRA_TEXT, content.field(FieldLabel.BODY).orEmpty())

            else -> null
        }
        return if (rewritten != null) start(context, rewritten) else view(context, raw)
    }

    /**
     * VIEW intent for [payload] exactly as scanned. Android matches schemes
     * case-sensitively, so only when nothing accepts the original is it tried
     * once more with the scheme in lower case (`HTTP://…` becomes `http://…`);
     * nothing else is ever changed.
     */
    private fun view(context: Context, payload: String): Boolean {
        val original = payload.toUri()
        if (start(context, Intent(Intent.ACTION_VIEW, original))) return true
        val normalized = original.normalizeScheme()
        return normalized != original && start(context, Intent(Intent.ACTION_VIEW, normalized))
    }

    /**
     * Opens the contacts app's new-contact screen, filled in from the scanned
     * card. Nothing is saved until the user confirms there, and the app needs
     * no contacts permission.
     */
    fun addContact(context: Context, content: QrContent): Boolean {
        val phones = content.fields(FieldLabel.PHONE)
        val emails = content.fields(FieldLabel.EMAIL)
        val intent = Intent(Intent.ACTION_INSERT).setType(ContactsContract.RawContacts.CONTENT_TYPE)
        fun put(key: String, value: String?) {
            if (!value.isNullOrEmpty()) intent.putExtra(key, value)
        }
        put(ContactsContract.Intents.Insert.NAME, content.field(FieldLabel.NAME))
        put(ContactsContract.Intents.Insert.PHONE, phones.getOrNull(0))
        put(ContactsContract.Intents.Insert.SECONDARY_PHONE, phones.getOrNull(1))
        put(ContactsContract.Intents.Insert.TERTIARY_PHONE, phones.getOrNull(2))
        put(ContactsContract.Intents.Insert.EMAIL, emails.getOrNull(0))
        put(ContactsContract.Intents.Insert.SECONDARY_EMAIL, emails.getOrNull(1))
        put(ContactsContract.Intents.Insert.COMPANY, content.field(FieldLabel.ORGANISATION))
        put(ContactsContract.Intents.Insert.POSTAL, content.field(FieldLabel.ADDRESS))
        return start(context, intent)
    }

    /** Opens the calendar app's new-event screen, filled in. The user saves or cancels there. */
    fun addEvent(context: Context, content: QrContent): Boolean {
        val times = QrClassifier.eventTimes(content.raw) ?: return false
        val intent = Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI)
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, times.start)
            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, times.end)
            .putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, times.allDay)
        content.field(FieldLabel.TITLE)?.let { intent.putExtra(CalendarContract.Events.TITLE, it) }
        content.field(FieldLabel.LOCATION)?.let { intent.putExtra(CalendarContract.Events.EVENT_LOCATION, it) }
        content.field(FieldLabel.DESCRIPTION)?.let { intent.putExtra(CalendarContract.Events.DESCRIPTION, it) }
        return start(context, intent)
    }

    enum class WifiJoin { ASKED, SETTINGS_OPENED, FAILED }

    /**
     * Asks the system to save the scanned Wi-Fi network (Android 11 and up):
     * the system shows its own "Save this network?" question, and the app
     * needs no Wi-Fi permission. On older phones, and for kinds of network
     * the system cannot take this way (WEP, company sign-in), the password is
     * copied and the Wi-Fi settings open so the user can pick the network.
     */
    fun joinWifi(context: Context, content: QrContent): WifiJoin {
        val ssid = content.field(FieldLabel.NETWORK).orEmpty()
        val password = content.fields.firstOrNull { it.label == FieldLabel.PASSWORD }?.copyValue.orEmpty()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val suggestion = wifiSuggestion(
                ssid = ssid,
                kind = wifiKind(content.field(FieldLabel.SECURITY).orEmpty(), password),
                password = password,
                hidden = content.field(FieldLabel.HIDDEN) != null,
            )
            if (suggestion != null) {
                val intent = Intent(Settings.ACTION_WIFI_ADD_NETWORKS)
                    .putParcelableArrayListExtra(Settings.EXTRA_WIFI_NETWORK_LIST, arrayListOf(suggestion))
                if (start(context, intent)) return WifiJoin.ASKED
            }
        }
        if (password.isNotEmpty()) copy(context, password, sensitive = true)
        return if (start(context, Intent(Settings.ACTION_WIFI_SETTINGS))) WifiJoin.SETTINGS_OPENED else WifiJoin.FAILED
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun wifiSuggestion(ssid: String, kind: WifiKind, password: String, hidden: Boolean): WifiNetworkSuggestion? = try {
        val builder = WifiNetworkSuggestion.Builder().setSsid(ssid).setIsHiddenSsid(hidden)
        when (kind) {
            WifiKind.OPEN -> builder.build()
            WifiKind.WPA2 -> builder.setWpa2Passphrase(password).build()
            WifiKind.WPA3 -> builder.setWpa3Passphrase(password).build()
            WifiKind.UNSUPPORTED -> null
        }
    } catch (e: IllegalArgumentException) {
        // A name or password the system does not accept (for example a WPA password under 8 characters).
        null
    }

    fun openAppSettings(context: Context) {
        start(
            context,
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)),
        )
    }

    private fun start(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: RuntimeException) {
        // No matching app, or the system refused the URI (for example a file: link).
        false
    }

    /** Copies [text]. [sensitive] keeps it out of the clipboard preview on Android 13+. */
    fun copy(context: Context, text: String, sensitive: Boolean = false) {
        val clipboard = context.getSystemService(ClipboardManager::class.java) ?: return
        val clip = ClipData.newPlainText(context.getString(R.string.app_name), text)
        if (sensitive) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean("android.content.extra.IS_SENSITIVE", true)
            }
        }
        clipboard.setPrimaryClip(clip)
        // Android 13+ shows its own confirmation.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) toast(context, R.string.copied)
    }
}
