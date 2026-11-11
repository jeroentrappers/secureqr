package be.appmire.secureqr.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PersistableBundle
import android.provider.Settings
import android.widget.Toast
import androidx.annotation.StringRes
import androidx.core.net.toUri
import be.appmire.secureqr.R
import be.appmire.secureqr.qr.FieldLabel
import be.appmire.secureqr.qr.QrContent
import be.appmire.secureqr.qr.QrType

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
