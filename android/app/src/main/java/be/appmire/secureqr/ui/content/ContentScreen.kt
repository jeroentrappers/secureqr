package be.appmire.secureqr.ui.content

import android.content.Context
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import be.appmire.secureqr.R
import be.appmire.secureqr.qr.FieldLabel
import be.appmire.secureqr.qr.FieldStyle
import be.appmire.secureqr.qr.Notice
import be.appmire.secureqr.qr.NoticeLevel
import be.appmire.secureqr.qr.QrAction
import be.appmire.secureqr.qr.QrContent
import be.appmire.secureqr.qr.QrField
import be.appmire.secureqr.qr.QrType
import be.appmire.secureqr.qr.Redaction
import be.appmire.secureqr.qr.SpecialCodes
import be.appmire.secureqr.ui.SystemActions
import be.appmire.secureqr.ui.components.Banner
import be.appmire.secureqr.ui.components.BannerTone
import be.appmire.secureqr.ui.components.BrandCard
import be.appmire.secureqr.ui.components.BrandScreen
import be.appmire.secureqr.ui.components.CardLabel
import be.appmire.secureqr.ui.components.GhostButton
import be.appmire.secureqr.ui.components.PrimaryButton
import be.appmire.secureqr.ui.theme.Brand
import be.appmire.secureqr.ui.theme.Dimens

private const val MASK = "••••••••"

/**
 * Typed card for anything that is not a link. Everything here was parsed on
 * the phone; nothing is opened, dialled or paid without a tap on a button.
 */
@Composable
fun ContentScreen(
    content: QrContent,
    incomplete: Boolean,
    onBack: () -> Unit,
) {
    val context = LocalContext.current

    BrandScreen(
        onBack = onBack,
        footer = if (content.actions.isEmpty()) null else {
            { ActionButtons(content) { action -> perform(context, content, action) } }
        },
    ) {
        // Instructions come first, in bold: what to do with this code.
        for (notice in content.notices.filter { it.instruction }) {
            Banner(BannerTone.NEUTRAL, title = stringResource(notice.textRes()))
        }

        // A payment-app link is titled with its provider; that row is then not repeated below.
        val provider = if (content.type == QrType.PAYLINK) content.field(FieldLabel.PROVIDER) else null
        BrandCard {
            Text(
                provider ?: stringResource(content.type.titleRes()),
                style = Brand.type.heading,
                color = Brand.colors.ink,
                modifier = Modifier.semantics { heading() },
            )
            Column(
                modifier = Modifier.padding(top = 12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                for (field in content.fields) {
                    if (provider == null || field.label != FieldLabel.PROVIDER) FieldRow(field)
                }
            }
        }

        // One banner per level, most severe first.
        for (level in listOf(NoticeLevel.DANGER, NoticeLevel.CAUTION, NoticeLevel.NEUTRAL)) {
            val notices = content.notices.filter { it.level == level && !it.instruction }
            if (notices.isNotEmpty()) {
                Banner(
                    tone = when (level) {
                        NoticeLevel.DANGER -> BannerTone.DANGER
                        NoticeLevel.CAUTION -> BannerTone.CAUTION
                        NoticeLevel.NEUTRAL -> BannerTone.NEUTRAL
                    },
                    lines = notices.map { stringResource(it.textRes()) },
                )
            }
        }
        if (incomplete) {
            Banner(BannerTone.NEUTRAL, lines = listOf(stringResource(R.string.content_from_history_redacted)))
        }

        RawContent(content)
    }
}

@Composable
private fun FieldRow(field: QrField) {
    var revealed by rememberSaveable(field) { mutableStateOf(false) }
    val secret = field.style == FieldStyle.SECRET

    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        CardLabel(stringResource(field.label.labelRes()))
        Row(verticalAlignment = Alignment.CenterVertically) {
            val value = when {
                secret && !revealed -> MASK
                field.label == FieldLabel.SECURITY && field.value.isEmpty() -> stringResource(R.string.value_none)
                field.label == FieldLabel.HIDDEN -> stringResource(R.string.value_yes)
                field.label == FieldLabel.HANDLE && field.value == SpecialCodes.INVITE -> stringResource(R.string.value_invite)
                else -> field.value
            }
            Text(
                value,
                style = if (field.style == FieldStyle.PLAIN) Brand.type.body else Brand.type.mono,
                color = Brand.colors.ink,
                modifier = Modifier.weight(1f),
            )
            if (secret) {
                Text(
                    stringResource(if (revealed) R.string.content_conceal else R.string.content_reveal),
                    style = Brand.type.bodyStrong,
                    color = Brand.colors.accent,
                    modifier = Modifier
                        .clickable(role = Role.Button) { revealed = !revealed }
                        .padding(horizontal = 8.dp, vertical = 6.dp),
                )
            }
        }
    }
}

/**
 * The accent button is the action that changes nothing outside this app. For
 * a card with a warning that means copying; "Open in app" then stays a ghost
 * button, the same way "Open anyway" does for a link.
 */
@Composable
private fun ActionButtons(content: QrContent, onAction: (QrAction) -> Unit) {
    val actions = content.actions
    val primary = when {
        // Opening the payment app is the whole point of a payment-app link.
        QrAction.OPEN_IN_PAYMENT_APP in actions -> QrAction.OPEN_IN_PAYMENT_APP
        content.level == NoticeLevel.NEUTRAL -> actions.first()
        else -> actions.firstOrNull { it != QrAction.OPEN_IN_APP && it != QrAction.JOIN_WIFI } ?: actions.first()
    }
    val secondary = actions.filter { it != primary }

    if (secondary.size >= 2 || primary == QrAction.OPEN_IN_PAYMENT_APP) {
        // Too many, or too long a label, for one row: secondary actions first, the main one below at full width.
        Row(horizontalArrangement = Arrangement.spacedBy(Dimens.gap)) {
            for (action in secondary) {
                GhostButton(stringResource(action.labelRes()), { onAction(action) }, Modifier.weight(1f))
            }
        }
        PrimaryButton(stringResource(primary.labelRes()), { onAction(primary) }, Modifier.fillMaxWidth())
    } else {
        Row(horizontalArrangement = Arrangement.spacedBy(Dimens.gap)) {
            for (action in secondary) {
                GhostButton(stringResource(action.labelRes()), { onAction(action) }, Modifier.weight(1f))
            }
            PrimaryButton(stringResource(primary.labelRes()), { onAction(primary) }, Modifier.weight(1f))
        }
    }
}

@Composable
private fun RawContent(content: QrContent) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    // Never put an OTP secret or a Wi-Fi password on screen through the back door.
    val raw = Redaction.redact(content)
    val redacted = raw != content.raw

    BrandCard(contentPadding = PaddingValues(0.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(role = Role.Button) { expanded = !expanded }
                .padding(Dimens.cardPadding),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(if (expanded) R.string.content_hide_raw else R.string.content_show_raw),
                style = Brand.type.bodyStrong,
                color = Brand.colors.accent,
                modifier = Modifier.weight(1f),
            )
            Icon(
                painterResource(R.drawable.ic_expand_more),
                contentDescription = null,
                tint = Brand.colors.muted,
                modifier = Modifier.rotate(if (expanded) 180f else 0f),
            )
        }
        AnimatedVisibility(expanded) {
            Column(
                modifier = Modifier.padding(start = Dimens.cardPadding, end = Dimens.cardPadding, bottom = Dimens.cardPadding),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SelectionContainer {
                    Text(raw, style = Brand.type.monoSmall, color = Brand.colors.ink)
                }
                if (redacted) {
                    Text(stringResource(R.string.content_secret_hidden), style = Brand.type.small, color = Brand.colors.muted)
                }
            }
        }
    }
}

private fun perform(context: Context, content: QrContent, action: QrAction) {
    fun copyField(label: FieldLabel, sensitive: Boolean = false) {
        content.fields.firstOrNull { it.label == label }?.let { SystemActions.copy(context, it.copyValue, sensitive) }
    }
    when (action) {
        QrAction.OPEN_IN_APP ->
            if (!SystemActions.openInApp(context, content)) SystemActions.toast(context, R.string.content_no_app)

        // The scanned link, unchanged: the installed payment app claims it, else the provider's page opens.
        QrAction.OPEN_IN_PAYMENT_APP ->
            if (!SystemActions.openLink(context, content.raw)) SystemActions.toast(context, R.string.content_no_payment_app)

        QrAction.ADD_CONTACT ->
            if (!SystemActions.addContact(context, content)) SystemActions.toast(context, R.string.content_no_app)

        QrAction.ADD_EVENT ->
            if (!SystemActions.addEvent(context, content)) SystemActions.toast(context, R.string.content_no_app)

        QrAction.JOIN_WIFI -> when (SystemActions.joinWifi(context, content)) {
            SystemActions.WifiJoin.ASKED -> Unit
            SystemActions.WifiJoin.SETTINGS_OPENED -> SystemActions.toast(
                context,
                if (content.field(FieldLabel.PASSWORD) == null) R.string.wifi_choose_in_settings else R.string.wifi_password_copied,
            )
            SystemActions.WifiJoin.FAILED -> SystemActions.toast(context, R.string.wifi_cannot_join)
        }

        // For a sign-in secret this is issuer and account only, never the secret.
        QrAction.COPY -> SystemActions.copy(context, content.copyText)

        QrAction.COPY_ALL -> SystemActions.copy(
            context,
            content.fields.joinToString("\n") { "${context.getString(it.label.labelRes())}: ${it.copyValue}" },
        )

        QrAction.COPY_IBAN -> copyField(FieldLabel.IBAN)
        QrAction.COPY_ADDRESS -> copyField(FieldLabel.ADDRESS)
        QrAction.COPY_PASSWORD -> copyField(FieldLabel.PASSWORD, sensitive = true)
    }
}
