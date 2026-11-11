package be.appmire.secureqr

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import be.appmire.secureqr.data.CheckProgress
import be.appmire.secureqr.data.HistoryEntry
import be.appmire.secureqr.data.HistoryStore
import be.appmire.secureqr.data.PreviewApi
import be.appmire.secureqr.data.PreviewEvent
import be.appmire.secureqr.data.PreviewOutcome
import be.appmire.secureqr.data.PreviewResponse
import be.appmire.secureqr.qr.QrClassifier
import be.appmire.secureqr.qr.QrContent
import be.appmire.secureqr.qr.QrType
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

sealed interface Screen {
    data object Scan : Screen

    /** The server preview flow for an http(s) link. */
    data class Preview(val url: String, val historyId: String?) : Screen

    /** A typed card for anything that is not a link. [incomplete] when it was reopened from redacted history. */
    data class Content(val content: QrContent, val incomplete: Boolean) : Screen

    data object History : Screen
}

sealed interface PreviewUiState {
    data class Checking(val progress: CheckProgress = CheckProgress()) : PreviewUiState

    data class Result(val response: PreviewResponse, val screenshotUrl: String?) : PreviewUiState

    /** [message] is the server's own wording when it sent one; [offline] when it could not be reached. */
    data class Failed(val code: String?, val message: String?, val offline: Boolean) : PreviewUiState {
        val retryable: Boolean get() = offline || code !in NOT_RETRYABLE

        /** The server turned this build away; trying again cannot help, an app update can. */
        val updateNeeded: Boolean get() = !offline && code == PreviewApi.CODE_UNAUTHORIZED
    }

    companion object {
        private val NOT_RETRYABLE = setOf("invalid_url", "blocked_target", PreviewApi.CODE_UNAUTHORIZED)
    }
}

class AppViewModel(application: Application) : AndroidViewModel(application) {

    private val api = PreviewApi(BuildConfig.API_BASE_URL, BuildConfig.API_KEY)
    private val history = HistoryStore(application)

    var screen by mutableStateOf<Screen>(Screen.Scan)
        private set

    var previewState by mutableStateOf<PreviewUiState>(PreviewUiState.Checking())
        private set

    val historyEntries: StateFlow<List<HistoryEntry>> =
        history.entries.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private val backStack = ArrayList<Screen>()
    private var previewJob: Job? = null

    /** Called once per successful scan, from the camera or from a picked image. */
    fun onScanned(text: String) {
        if (screen != Screen.Scan) return
        val content = QrClassifier.classify(text)
        val entry = HistoryEntry.from(content, System.currentTimeMillis())
        viewModelScope.launch { history.add(entry) }
        open(content, entry.id, incomplete = false)
    }

    fun openHistoryEntry(entry: HistoryEntry) {
        open(QrClassifier.classify(entry.payload), entry.id, incomplete = entry.redacted)
    }

    private fun open(content: QrContent, historyId: String, incomplete: Boolean) {
        if (content.type == QrType.URL) {
            navigate(Screen.Preview(content.raw, historyId))
            startPreview()
        } else {
            navigate(Screen.Content(content, incomplete))
        }
    }

    fun retry() = startPreview()

    private fun startPreview() {
        val target = screen as? Screen.Preview ?: return
        previewJob?.cancel()
        previewState = PreviewUiState.Checking()
        previewJob = viewModelScope.launch {
            var progress = CheckProgress()
            api.previewEvents(target.url).collect { event ->
                if (screen != target) return@collect
                if (event is PreviewEvent.Finished) {
                    previewState = finished(target, event.outcome)
                } else {
                    progress = progress.reduce(event)
                    previewState = PreviewUiState.Checking(progress)
                }
            }
        }
    }

    private suspend fun finished(target: Screen.Preview, outcome: PreviewOutcome): PreviewUiState = when (outcome) {
        is PreviewOutcome.Success -> {
            val response = outcome.response
            target.historyId?.let {
                history.setLevel(it, response.verdict.verdictLevel.id, System.currentTimeMillis())
            }
            PreviewUiState.Result(response, response.screenshotUrl?.let(api::absoluteUrl))
        }
        is PreviewOutcome.ApiError -> {
            markFailed(target)
            PreviewUiState.Failed(outcome.code, outcome.message, offline = false)
        }
        PreviewOutcome.Offline -> {
            markFailed(target)
            PreviewUiState.Failed(null, null, offline = true)
        }
    }

    /** A link whose check did not succeed stays in the history, marked as such. */
    private suspend fun markFailed(target: Screen.Preview) {
        target.historyId?.let { history.setLevel(it, HistoryEntry.LEVEL_FAILED, System.currentTimeMillis()) }
    }

    fun showHistory() = navigate(Screen.History)

    fun deleteHistoryEntry(entry: HistoryEntry) {
        viewModelScope.launch { history.delete(entry.id) }
    }

    fun clearHistory() {
        viewModelScope.launch { history.clear() }
    }

    private fun navigate(to: Screen) {
        backStack += screen
        screen = to
    }

    /** One step back. Returns false when already on the scanner. */
    fun back(): Boolean {
        if (backStack.isEmpty()) return false
        if (screen is Screen.Preview) previewJob?.cancel()
        screen = backStack.removeAt(backStack.lastIndex)
        return true
    }

    /** "Don't open", "Cancel" and after opening a link: straight back to the scanner. */
    fun returnToScanner() {
        previewJob?.cancel()
        backStack.clear()
        screen = Screen.Scan
    }
}
