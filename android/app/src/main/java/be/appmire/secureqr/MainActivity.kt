package be.appmire.secureqr

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.Base64
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import be.appmire.secureqr.ui.SystemActions
import be.appmire.secureqr.ui.content.ContentScreen
import be.appmire.secureqr.ui.history.HistoryScreen
import be.appmire.secureqr.ui.preview.PreviewScreen
import be.appmire.secureqr.ui.scan.ScanScreen
import be.appmire.secureqr.ui.theme.SecureQrTheme

class MainActivity : ComponentActivity() {

    private val viewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { SecureQrApp(viewModel, onDarkBars = ::applySystemBars) }
        // Not on re-creation (rotation, theme change): the scan was already handled.
        if (savedInstanceState == null) injectDebugScan(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        injectDebugScan(intent)
    }

    /**
     * Debug builds only: treats an intent extra as a scanned QR code, for
     * emulators and UI tests where no real code is in front of the camera.
     * `scanPayload` is the text itself, `scanPayloadBase64` the same text
     * Base64-encoded (for payloads with line breaks). See README.md.
     */
    private fun injectDebugScan(intent: Intent?) {
        if (!BuildConfig.DEBUG || intent == null) return
        val payload = intent.getStringExtra("scanPayload")
            ?: intent.getStringExtra("scanPayloadBase64")?.let {
                try {
                    String(Base64.decode(it, Base64.DEFAULT), Charsets.UTF_8)
                } catch (e: IllegalArgumentException) {
                    null
                }
            }
            ?: return
        viewModel.returnToScanner()
        viewModel.onScanned(payload)
    }

    /** Keeps status and navigation bar icons readable over the current screen. */
    private fun applySystemBars(dark: Boolean) {
        val style = if (dark) {
            SystemBarStyle.dark(Color.TRANSPARENT)
        } else {
            SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
        }
        enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
    }
}

@Composable
private fun SecureQrApp(viewModel: AppViewModel, onDarkBars: (Boolean) -> Unit) {
    val screen = viewModel.screen
    // The scanner always sits on the camera image, so it is always dark.
    val dark = screen == Screen.Scan || isSystemInDarkTheme()
    LaunchedEffect(dark) { onDarkBars(dark) }

    SecureQrTheme(darkTheme = dark) {
        val context = LocalContext.current
        BackHandler(enabled = screen != Screen.Scan) { viewModel.back() }

        // A new scan is a new screen: expanded sections and revealed fields must not carry over.
        key(screen) {
            when (screen) {
                Screen.Scan -> ScanScreen(
                    onScanned = viewModel::onScanned,
                    onHistory = viewModel::showHistory,
                )

                is Screen.Preview -> PreviewScreen(
                    url = screen.url,
                    state = viewModel.previewState,
                    onBack = { viewModel.back() },
                    onRetry = viewModel::retry,
                    onOpen = {
                        // Always the scanned link, never the final URL: see docs/api.md.
                        if (SystemActions.openLink(context, screen.url)) {
                            viewModel.returnToScanner()
                        } else {
                            SystemActions.toast(context, R.string.error_no_browser)
                        }
                    },
                    onDontOpen = viewModel::returnToScanner,
                )

                is Screen.Content -> ContentScreen(
                    content = screen.content,
                    incomplete = screen.incomplete,
                    onBack = { viewModel.back() },
                )

                Screen.History -> {
                    val entries by viewModel.historyEntries.collectAsStateWithLifecycle()
                    HistoryScreen(
                        entries = entries,
                        onBack = { viewModel.back() },
                        onOpen = viewModel::openHistoryEntry,
                        onDelete = viewModel::deleteHistoryEntry,
                        onClear = viewModel::clearHistory,
                    )
                }
            }
        }
    }
}
