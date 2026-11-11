package be.appmire.secureqr.ui.history

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import be.appmire.secureqr.R
import be.appmire.secureqr.data.HistoryEntry
import be.appmire.secureqr.data.VerdictLevel
import be.appmire.secureqr.qr.QrClassifier
import be.appmire.secureqr.qr.QrType
import be.appmire.secureqr.ui.components.BrandTopBar
import be.appmire.secureqr.ui.content.titleRes
import be.appmire.secureqr.ui.theme.Brand
import be.appmire.secureqr.ui.theme.Dimens

/** Past scans, newest first. Tapping one checks it again (links) or shows its card (everything else). */
@Composable
fun HistoryScreen(
    entries: List<HistoryEntry>,
    onBack: () -> Unit,
    onOpen: (HistoryEntry) -> Unit,
    onDelete: (HistoryEntry) -> Unit,
    onClear: () -> Unit,
) {
    var confirmClear by rememberSaveable { mutableStateOf(false) }

    Column(
        Modifier
            .fillMaxSize()
            .background(Brand.colors.bg)
            .windowInsetsPadding(WindowInsets.safeDrawing),
    ) {
        BrandTopBar(
            onBack = onBack,
            actions = {
                if (entries.isNotEmpty()) {
                    Text(
                        stringResource(R.string.history_clear),
                        style = Brand.type.bodyStrong,
                        color = Brand.colors.danger,
                        modifier = Modifier
                            .padding(end = 4.dp)
                            .clip(Dimens.pillShape)
                            .clickable(role = Role.Button) { confirmClear = true }
                            .padding(horizontal = 12.dp, vertical = 12.dp),
                    )
                }
            },
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = Dimens.screenPadding,
                end = Dimens.screenPadding,
                top = 4.dp,
                bottom = Dimens.screenPadding,
            ),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item(key = "header") {
                Column(Modifier.padding(bottom = 4.dp)) {
                    Text(
                        stringResource(R.string.history_title),
                        style = Brand.type.heading,
                        color = Brand.colors.ink,
                        modifier = Modifier.semantics { heading() },
                    )
                    Text(
                        stringResource(if (entries.isEmpty()) R.string.history_empty else R.string.history_note),
                        style = Brand.type.small,
                        color = Brand.colors.muted,
                    )
                }
            }
            items(entries, key = { it.id }) { entry ->
                HistoryRow(entry, onClick = { onOpen(entry) }, onDelete = { onDelete(entry) })
            }
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text(stringResource(R.string.history_clear_title)) },
            text = { Text(stringResource(R.string.history_clear_body)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmClear = false
                    onClear()
                }) { Text(stringResource(R.string.history_clear_confirm), color = Brand.colors.danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmClear = false }) { Text(stringResource(R.string.action_cancel)) }
            },
        )
    }
}

@Composable
private fun HistoryRow(entry: HistoryEntry, onClick: () -> Unit, onDelete: () -> Unit) {
    var menuOpen by remember { mutableStateOf(false) }
    val type = QrType.fromId(entry.type) ?: QrType.TEXT
    val (dotColor, levelText) = when (entry.level) {
        VerdictLevel.OK.id -> Brand.colors.ok to R.string.history_level_ok
        VerdictLevel.CAUTION.id -> Brand.colors.warn to R.string.history_level_caution
        VerdictLevel.DANGER.id -> Brand.colors.danger to R.string.history_level_danger
        HistoryEntry.LEVEL_NEUTRAL -> Brand.colors.muted to R.string.history_level_neutral
        HistoryEntry.LEVEL_FAILED -> null to R.string.history_level_failed
        else -> null to R.string.history_level_unchecked
    }
    val levelDescription = stringResource(levelText)
    val now = System.currentTimeMillis()
    val time = if (now - entry.timestamp < DateUtils.MINUTE_IN_MILLIS) {
        stringResource(R.string.history_just_now)
    } else {
        DateUtils.getRelativeTimeSpanString(entry.timestamp, now, DateUtils.MINUTE_IN_MILLIS).toString()
    }
    // Links are listed by host; everything else by what the card is about (stored payloads are already redacted).
    val headline = entry.host ?: remember(entry.payload) { QrClassifier.classify(entry.payload).summary }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Dimens.cardShape)
            .background(Brand.colors.surface)
            .border(1.dp, Brand.colors.line, Dimens.cardShape)
            // Tap opens the entry again; a long press offers to delete just this one.
            .combinedClickable(
                role = Role.Button,
                onClick = onClick,
                onLongClick = { menuOpen = true },
                onLongClickLabel = stringResource(R.string.history_entry_options),
            )
            .semantics { stateDescription = levelDescription }
            .padding(Dimens.cardPadding),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Verdict dot: hollow while a link has not been checked.
        Box(
            Modifier
                .size(12.dp)
                .clip(CircleShape)
                .then(
                    if (dotColor != null) {
                        Modifier.background(dotColor)
                    } else {
                        Modifier.border(2.dp, Brand.colors.muted, CircleShape)
                    },
                ),
        )
        Column(Modifier.weight(1f)) {
            Text(
                headline,
                style = Brand.type.mono,
                color = Brand.colors.ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                if (entry.level == HistoryEntry.LEVEL_FAILED) {
                    stringResource(R.string.history_subtitle_with_state, stringResource(type.titleRes()), levelDescription, time)
                } else {
                    stringResource(R.string.history_subtitle, stringResource(type.titleRes()), time)
                },
                style = Brand.type.small,
                color = Brand.colors.muted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        // Anchored at the end of the row.
        Box {
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.history_delete), color = Brand.colors.danger) },
                    onClick = {
                        menuOpen = false
                        onDelete()
                    },
                )
            }
        }
    }
}
