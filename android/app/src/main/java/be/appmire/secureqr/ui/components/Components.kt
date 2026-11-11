package be.appmire.secureqr.ui.components

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import be.appmire.secureqr.R
import be.appmire.secureqr.ui.theme.Brand
import be.appmire.secureqr.ui.theme.Dimens

/** Mark plus two-tone wordmark, with an optional back button and trailing actions. */
@Composable
fun BrandTopBar(
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .padding(start = if (onBack != null) 4.dp else Dimens.screenPadding, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            IconAction(R.drawable.ic_arrow_back, stringResource(R.string.action_back), onBack)
        }
        Image(
            painter = painterResource(R.drawable.ic_mark),
            contentDescription = null,
            modifier = Modifier.size(28.dp),
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = buildAnnotatedString {
                append(stringResource(R.string.wordmark_secure))
                withStyle(SpanStyle(color = Brand.colors.accent)) { append(stringResource(R.string.wordmark_qr)) }
            },
            style = Brand.type.wordmark,
            color = Brand.colors.ink,
            modifier = Modifier.semantics { heading() },
        )
        Spacer(Modifier.weight(1f))
        actions()
    }
}

/** A 48dp touch target around a 24dp icon. */
@Composable
fun IconAction(
    @DrawableRes icon: Int,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = Brand.colors.ink,
) {
    Box(
        modifier = modifier
            .size(48.dp)
            .clip(CircleShape)
            .clickable(role = Role.Button, onClickLabel = contentDescription, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(painterResource(icon), contentDescription, tint = tint, modifier = Modifier.size(24.dp))
    }
}

/** Small uppercase mono label used at the top of cards and above field values. */
@Composable
fun CardLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text.uppercase(),
        style = Brand.type.label,
        color = Brand.colors.muted,
        modifier = modifier,
    )
}

@Composable
fun BrandCard(
    modifier: Modifier = Modifier,
    label: String? = null,
    contentPadding: PaddingValues = PaddingValues(Dimens.cardPadding),
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(Dimens.cardShape)
            .background(Brand.colors.surface)
            .border(1.dp, Brand.colors.line, Dimens.cardShape)
            .padding(contentPadding),
    ) {
        if (label != null) {
            CardLabel(label, Modifier.padding(bottom = 8.dp))
        }
        content()
    }
}

@Composable
fun PrimaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    ButtonBox(
        text = text,
        onClick = onClick,
        modifier = modifier,
        background = Brand.colors.accent,
        border = Brand.colors.accent,
        content = Brand.colors.onAccent,
    )
}

@Composable
fun GhostButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, emphasised: Boolean = false) {
    ButtonBox(
        text = text,
        onClick = onClick,
        modifier = modifier,
        background = Color.Transparent,
        border = if (emphasised) Brand.colors.accent else Brand.colors.line,
        content = if (emphasised) Brand.colors.accent else Brand.colors.muted,
    )
}

@Composable
private fun ButtonBox(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier,
    background: Color,
    border: Color,
    content: Color,
) {
    Box(
        modifier = modifier
            .heightIn(min = 52.dp)
            .clip(Dimens.cardShape)
            .background(background)
            .border(1.dp, border, Dimens.cardShape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = Brand.type.button, color = content, textAlign = TextAlign.Center)
    }
}

enum class BannerTone { OK, CAUTION, DANGER, NEUTRAL }

@Composable
fun BannerTone.color(): Color = when (this) {
    BannerTone.OK -> Brand.colors.ok
    BannerTone.CAUTION -> Brand.colors.warn
    BannerTone.DANGER -> Brand.colors.danger
    BannerTone.NEUTRAL -> Brand.colors.muted
}

@DrawableRes
fun BannerTone.icon(): Int = when (this) {
    BannerTone.OK -> R.drawable.ic_check_circle
    BannerTone.CAUTION -> R.drawable.ic_warning
    BannerTone.DANGER -> R.drawable.ic_error
    BannerTone.NEUTRAL -> R.drawable.ic_info
}

/**
 * Verdict / notice banner: level colour at 15% over the surface, 1dp border in
 * the level colour, text in ink.
 */
@Composable
fun Banner(
    tone: BannerTone,
    modifier: Modifier = Modifier,
    title: String? = null,
    lines: List<String> = emptyList(),
) {
    val color = tone.color()
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(Dimens.cardShape)
            .background(Brand.colors.tint(color))
            .border(1.dp, color, Dimens.cardShape)
            .padding(horizontal = Dimens.cardPadding, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = if (title != null && lines.isEmpty()) Alignment.CenterVertically else Alignment.Top,
    ) {
        Icon(
            painter = painterResource(tone.icon()),
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(22.dp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            if (title != null) {
                Text(title, style = Brand.type.title, color = Brand.colors.ink)
            }
            for (line in lines) {
                Text(line, style = Brand.type.small, color = Brand.colors.ink)
            }
        }
    }
}

/** Fully rounded mono chip. [color] overrides the muted text and border, e.g. for a danger chip. */
@Composable
fun Chip(text: String, modifier: Modifier = Modifier, color: Color? = null) {
    Text(
        text = text,
        style = Brand.type.chip,
        color = color ?: Brand.colors.muted,
        modifier = modifier
            .clip(Dimens.pillShape)
            .border(1.dp, color ?: Brand.colors.line, Dimens.pillShape)
            .padding(horizontal = 10.dp, vertical = 7.dp),
    )
}

/**
 * Standard screen frame: brand background, top bar, a scrolling body with the
 * brand padding and gaps, and an optional pinned footer (buttons or a note).
 */
@Composable
fun BrandScreen(
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
    footer: (@Composable ColumnScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Brand.colors.bg)
            .windowInsetsPadding(WindowInsets.safeDrawing),
    ) {
        BrandTopBar(onBack = onBack, actions = actions)
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Dimens.screenPadding)
                .padding(top = 4.dp, bottom = Dimens.gap),
            verticalArrangement = Arrangement.spacedBy(Dimens.gap),
            content = content,
        )
        if (footer != null) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Dimens.screenPadding)
                    .padding(top = 4.dp, bottom = Dimens.screenPadding),
                verticalArrangement = Arrangement.spacedBy(Dimens.gap),
                content = footer,
            )
        }
    }
}
