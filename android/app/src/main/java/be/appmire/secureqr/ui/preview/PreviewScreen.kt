package be.appmire.secureqr.ui.preview

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import be.appmire.secureqr.PreviewUiState
import be.appmire.secureqr.R
import be.appmire.secureqr.data.CheckProgress
import be.appmire.secureqr.data.Hop
import be.appmire.secureqr.data.PreviewResponse
import be.appmire.secureqr.data.ReputationStatus
import be.appmire.secureqr.data.VerdictLevel
import be.appmire.secureqr.qr.hostOf
import be.appmire.secureqr.ui.components.Banner
import be.appmire.secureqr.ui.components.BannerTone
import be.appmire.secureqr.ui.components.BrandCard
import be.appmire.secureqr.ui.components.BrandScreen
import be.appmire.secureqr.ui.components.CardLabel
import be.appmire.secureqr.ui.components.Chip
import be.appmire.secureqr.ui.components.GhostButton
import be.appmire.secureqr.ui.components.PrimaryButton
import be.appmire.secureqr.ui.components.color
import be.appmire.secureqr.ui.theme.Brand
import be.appmire.secureqr.ui.theme.Dimens
import coil3.compose.AsyncImage

/** Screenshot size from the API: a 390pt-wide phone viewport rendered at 2x. */
private const val SCREENSHOT_ASPECT = 780f / 1688f
private val SCREENSHOT_COLLAPSED_HEIGHT = 300.dp

/** The link flow: checking, then the decision, or a failure that still lets the user choose. */
@Composable
fun PreviewScreen(
    url: String,
    state: PreviewUiState,
    onBack: () -> Unit,
    onRetry: () -> Unit,
    onOpen: () -> Unit,
    onDontOpen: () -> Unit,
) {
    when (state) {
        is PreviewUiState.Checking -> Checking(url, state.progress, onBack)
        is PreviewUiState.Result -> Decide(state.response, state.screenshotUrl, onBack, onOpen, onDontOpen)
        is PreviewUiState.Failed -> Failed(url, state, onBack, onRetry, onOpen, onDontOpen)
    }
}

@Composable
private fun ScannedUrlCard(url: String) {
    BrandCard(label = stringResource(R.string.checking_label_says)) {
        Text(url, style = Brand.type.mono, color = Brand.colors.ink)
    }
}

@Composable
private fun Checking(url: String, progress: CheckProgress, onBack: () -> Unit) {
    BrandScreen(
        onBack = onBack,
        footer = {
            Text(
                stringResource(R.string.checking_note),
                style = Brand.type.small,
                color = Brand.colors.muted,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        },
    ) {
        ScannedUrlCard(url)
        BrandCard(label = stringResource(R.string.checking_label_following)) {
            if (progress.stepsAvailable) CheckList(progress) else PlainProgress(url)
        }
    }
}

/** The wait without steps, for a server that cannot report them. */
@Composable
private fun PlainProgress(url: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        CircularProgressIndicator(
            modifier = Modifier.size(22.dp),
            color = Brand.colors.accent,
            trackColor = Brand.colors.line,
            strokeWidth = 2.5.dp,
        )
        Column {
            Text(hostOf(url) ?: url, style = Brand.type.mono, color = Brand.colors.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(stringResource(R.string.checking_progress), style = Brand.type.small, color = Brand.colors.muted)
        }
    }
}

private val STEP_ICON_SIZE = 18.dp
private val STEP_ICON_GAP = 10.dp

@Composable
private fun CheckList(progress: CheckProgress) {
    Column {
        if (progress.steps.isEmpty()) {
            StepRow(done = false, label = stringResource(R.string.checking_contacting))
        }
        progress.steps.forEachIndexed { index, step ->
            key(step.id) {
                // The first step takes the place of the "contacting" row; later ones slide in below.
                Appearing(animate = index > 0) {
                    Column {
                        StepRow(step.done, step.label)
                        if (step.id == CheckProgress.STEP_REDIRECTS) {
                            progress.hopHosts.forEachIndexed { hopIndex, host ->
                                key(hopIndex) {
                                    Appearing {
                                        Text(
                                            host,
                                            style = Brand.type.monoSmall,
                                            color = Brand.colors.muted,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis,
                                            modifier = Modifier.padding(start = STEP_ICON_SIZE + STEP_ICON_GAP, bottom = 3.dp),
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Fades and unfolds its content the first time it is shown. */
@Composable
private fun Appearing(animate: Boolean = true, content: @Composable () -> Unit) {
    val visible = remember { MutableTransitionState(!animate).apply { targetState = true } }
    AnimatedVisibility(
        visibleState = visible,
        enter = fadeIn() + expandVertically(expandFrom = Alignment.Top),
    ) {
        content()
    }
}

@Composable
private fun StepRow(done: Boolean, label: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 5.dp),
        horizontalArrangement = Arrangement.spacedBy(STEP_ICON_GAP),
    ) {
        // As tall as the first line of the label, so the icon stays on it when the label wraps.
        Box(Modifier.size(STEP_ICON_SIZE, 22.dp), contentAlignment = Alignment.Center) {
            Crossfade(done, label = "step state") { isDone ->
                if (isDone) {
                    Icon(
                        painterResource(R.drawable.ic_check),
                        contentDescription = stringResource(R.string.checking_step_done),
                        tint = Brand.colors.ok,
                        modifier = Modifier.size(STEP_ICON_SIZE),
                    )
                } else {
                    CircularProgressIndicator(
                        modifier = Modifier.size(STEP_ICON_SIZE).padding(2.dp),
                        color = Brand.colors.accent,
                        trackColor = Brand.colors.line,
                        strokeWidth = 2.dp,
                    )
                }
            }
        }
        Text(label, style = Brand.type.body, color = Brand.colors.ink)
    }
}

private fun VerdictLevel.tone() = when (this) {
    VerdictLevel.OK -> BannerTone.OK
    VerdictLevel.CAUTION -> BannerTone.CAUTION
    VerdictLevel.DANGER -> BannerTone.DANGER
}

@Composable
private fun Decide(
    response: PreviewResponse,
    screenshotUrl: String?,
    onBack: () -> Unit,
    onOpen: () -> Unit,
    onDontOpen: () -> Unit,
) {
    val level = response.verdict.verdictLevel
    val tone = level.tone()

    BrandScreen(
        onBack = onBack,
        footer = {
            Row(horizontalArrangement = Arrangement.spacedBy(Dimens.gap)) {
                if (level == VerdictLevel.OK) {
                    GhostButton(stringResource(R.string.action_cancel), onDontOpen, Modifier.weight(1f))
                    PrimaryButton(stringResource(R.string.action_open), onOpen, Modifier.weight(1f))
                } else {
                    GhostButton(stringResource(R.string.action_open_anyway), onOpen, Modifier.weight(1f))
                    PrimaryButton(stringResource(R.string.action_dont_open), onDontOpen, Modifier.weight(1f))
                }
            }
        },
    ) {
        Banner(
            tone = tone,
            title = stringResource(
                when (level) {
                    VerdictLevel.OK -> R.string.verdict_ok
                    VerdictLevel.CAUTION -> R.string.verdict_caution
                    VerdictLevel.DANGER -> R.string.verdict_danger
                },
            ),
            // Every reason is shown with the server's wording, whatever its code.
            lines = response.verdict.reasons.map { it.message }.filter { it.isNotBlank() },
        )
        // The server reuses a recent answer for the same link; say how old it is.
        val minutesAgo = remember(response) { response.cachedMinutesAgo(System.currentTimeMillis()) }
        if (minutesAgo != null) {
            Text(
                text = if (minutesAgo == 0L) {
                    stringResource(R.string.decide_checked_just_now)
                } else {
                    pluralStringResource(R.plurals.decide_checked_minutes, minutesAgo.toInt(), minutesAgo.toInt())
                },
                style = Brand.type.small,
                color = Brand.colors.muted,
                modifier = Modifier.padding(horizontal = Dimens.cardPadding),
            )
        }
        Screenshot(screenshotUrl, response.finalHost, response.https)
        LandingCard(response, tone)
        if (response.hops.isNotEmpty()) HopsCard(response.hops)
    }
}

@Composable
private fun Screenshot(url: String?, host: String, https: Boolean) {
    var loaded by remember(url) { mutableStateOf(false) }
    var failed by remember(url) { mutableStateOf(url == null) }
    var expanded by rememberSaveable(url) { mutableStateOf(false) }
    val chromeText = Color(0xFF555555)
    val chromeBackground = Color(0xFFECEEF2)

    Column(
        Modifier
            .fillMaxWidth()
            .clip(Dimens.cardShape)
            .background(Color.White)
            .border(1.dp, Brand.colors.line, Dimens.cardShape),
    ) {
        // A strip that looks like a browser address bar, so it reads as a picture of a page.
        Row(
            Modifier
                .fillMaxWidth()
                .background(chromeBackground)
                .padding(horizontal = 14.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                painterResource(if (https) R.drawable.ic_lock else R.drawable.ic_warning),
                contentDescription = null,
                tint = chromeText,
                modifier = Modifier.size(13.dp),
            )
            Text(host, style = Brand.type.monoSmall, color = chromeText, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }

        if (failed || url == null) {
            ScreenshotMessage(stringResource(R.string.screenshot_unavailable))
        } else {
            Box {
                // Always scaled to the card width (the image is 780 x 1688). Collapsed, only the
                // top of the page shows, so where the link lands stays in view without scrolling.
                AsyncImage(
                    model = url,
                    contentDescription = stringResource(R.string.screenshot_description),
                    contentScale = ContentScale.FillWidth,
                    alignment = Alignment.TopCenter,
                    onSuccess = { loaded = true },
                    onError = { failed = true },
                    modifier = if (expanded) {
                        Modifier
                            .fillMaxWidth()
                            .aspectRatio(SCREENSHOT_ASPECT)
                    } else {
                        Modifier
                            .fillMaxWidth()
                            .height(SCREENSHOT_COLLAPSED_HEIGHT)
                    },
                )
                if (!loaded) ScreenshotMessage(stringResource(R.string.screenshot_loading))
            }
            if (loaded) {
                Text(
                    stringResource(if (expanded) R.string.screenshot_collapse else R.string.screenshot_expand),
                    style = Brand.type.small,
                    color = chromeText,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(chromeBackground)
                        .clickable(role = Role.Button) { expanded = !expanded }
                        .padding(vertical = 10.dp),
                )
            }
        }
    }
}

@Composable
private fun ScreenshotMessage(text: String) {
    Box(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 120.dp)
            .padding(16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = Brand.type.small, color = Color(0xFF555555), textAlign = TextAlign.Center)
    }
}

@Composable
private fun LandingCard(response: PreviewResponse, tone: BannerTone) {
    val highlight = tone.color().copy(alpha = 0.3f)
    val host = response.finalHost
    val domain = response.finalDomain

    BrandCard(label = stringResource(R.string.decide_label_land)) {
        Text(
            text = buildAnnotatedString {
                // The registrable domain is the part that says who really owns the page.
                if (domain.isNotEmpty() && host.endsWith(domain)) {
                    append(host.dropLast(domain.length))
                    withStyle(SpanStyle(background = highlight)) { append(domain) }
                } else {
                    append(host)
                }
            },
            style = Brand.type.monoStrong,
            color = Brand.colors.ink,
        )
        if (response.title.isNotBlank()) {
            Text(
                response.title,
                style = Brand.type.small,
                color = Brand.colors.muted,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
        FlowRow(
            modifier = Modifier.padding(top = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (response.https) {
                Chip(stringResource(R.string.chip_https))
            } else {
                Chip(stringResource(R.string.chip_not_encrypted), color = Brand.colors.danger)
            }
            val redirects = response.redirectCount
            Chip(
                if (redirects == 0) {
                    stringResource(R.string.chip_no_redirects)
                } else {
                    pluralStringResource(R.plurals.chip_redirects, redirects, redirects)
                },
            )
            when (response.reputation?.status) {
                ReputationStatus.FLAGGED -> Chip(stringResource(R.string.chip_blocklisted), color = Brand.colors.danger)
                ReputationStatus.CLEAR -> Chip(stringResource(R.string.chip_not_blocklisted))
                ReputationStatus.UNKNOWN, null -> Unit
            }
        }
    }
}

@Composable
private fun HopsCard(hops: List<Hop>) {
    var expanded by rememberSaveable { mutableStateOf(false) }

    BrandCard(contentPadding = PaddingValues(0.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(role = Role.Button) { expanded = !expanded }
                .padding(Dimens.cardPadding),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                CardLabel(stringResource(R.string.decide_label_path))
                Text(
                    stringResource(if (expanded) R.string.decide_hide_path else R.string.decide_show_path),
                    style = Brand.type.bodyStrong,
                    color = Brand.colors.accent,
                )
            }
            Icon(
                painterResource(R.drawable.ic_expand_more),
                contentDescription = null,
                tint = Brand.colors.muted,
                modifier = Modifier.rotate(if (expanded) 180f else 0f),
            )
        }
        AnimatedVisibility(expanded) {
            Column(Modifier.padding(horizontal = Dimens.cardPadding)) {
                for (hop in hops) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(Brand.colors.line),
                    )
                    HopRow(hop)
                }
            }
        }
    }
}

@Composable
private fun HopRow(hop: Hop) {
    Row(Modifier.padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(
            Modifier
                .padding(top = 1.dp)
                .size(20.dp)
                .clip(CircleShape)
                .background(Brand.colors.ok),
            contentAlignment = Alignment.Center,
        ) {
            Icon(painterResource(R.drawable.ic_check), null, tint = Brand.colors.surface, modifier = Modifier.size(13.dp))
        }
        Column {
            Text(hop.host.ifEmpty { hop.url }, style = Brand.type.mono, color = Brand.colors.ink)
            val kind = stringResource(
                when (hop.kind) {
                    "start" -> R.string.hop_start
                    "client" -> R.string.hop_client
                    else -> R.string.hop_http
                },
            )
            Text(
                if (hop.status != null) stringResource(R.string.hop_with_status, kind, hop.status) else kind,
                style = Brand.type.small,
                color = Brand.colors.muted,
            )
            if (hop.host.isNotEmpty()) {
                Text(
                    hop.url,
                    style = Brand.type.monoSmall,
                    color = Brand.colors.muted,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

@Composable
private fun Failed(
    url: String,
    state: PreviewUiState.Failed,
    onBack: () -> Unit,
    onRetry: () -> Unit,
    onOpen: () -> Unit,
    onDontOpen: () -> Unit,
) {
    val message = when {
        state.offline -> stringResource(R.string.error_offline)
        !state.message.isNullOrBlank() -> state.message
        state.updateNeeded -> stringResource(R.string.error_update_needed)
        else -> stringResource(R.string.error_generic)
    }
    val title = stringResource(if (state.updateNeeded) R.string.error_update_title else R.string.error_title)
    BrandScreen(
        onBack = onBack,
        footer = {
            if (state.retryable) {
                PrimaryButton(stringResource(R.string.action_retry), onRetry, Modifier.fillMaxWidth())
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Dimens.gap)) {
                GhostButton(stringResource(R.string.action_open_anyway), onOpen, Modifier.weight(1f))
                if (state.retryable) {
                    GhostButton(stringResource(R.string.action_dont_open), onDontOpen, Modifier.weight(1f), emphasised = true)
                } else {
                    PrimaryButton(stringResource(R.string.action_dont_open), onDontOpen, Modifier.weight(1f))
                }
            }
        },
    ) {
        Banner(BannerTone.CAUTION, title = title, lines = listOf(message))
        ScannedUrlCard(url)
        Banner(BannerTone.DANGER, lines = listOf(stringResource(R.string.error_unchecked_warning)))
    }
}
