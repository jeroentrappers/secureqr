package be.appmire.secureqr.data

import kotlinx.serialization.Serializable

/** What `POST /v1/preview/stream` reports while a link is being checked. */
sealed interface PreviewEvent {
    /** A check started or finished. [label] is the server's wording for the current state. */
    data class Step(val id: String, val done: Boolean, val label: String) : PreviewEvent

    /** A site the link passes through. */
    data class HopReached(val host: String) : PreviewEvent

    /** The server has no step-by-step endpoint; the plain check is running and no steps will follow. */
    data object StepsUnavailable : PreviewEvent

    /** Always the last event. */
    data class Finished(val outcome: PreviewOutcome) : PreviewEvent
}

@Serializable
internal data class StreamLine(
    val type: String = "",
    val id: String = "",
    val state: String = "",
    val label: String = "",
    val hop: Hop? = null,
    val result: PreviewResponse? = null,
    val status: Int? = null,
    val error: ErrorBody? = null,
)

data class CheckStep(val id: String, val done: Boolean, val label: String)

/** The checklist on the Checking screen, built up from the events of one check. */
data class CheckProgress(
    /** In the order each step was first reported. */
    val steps: List<CheckStep> = emptyList(),
    val hopHosts: List<String> = emptyList(),
    /** False when the server cannot report steps, so only a generic wait can be shown. */
    val stepsAvailable: Boolean = true,
) {
    fun reduce(event: PreviewEvent): CheckProgress = when (event) {
        is PreviewEvent.Step -> {
            val step = CheckStep(event.id, event.done, event.label)
            if (steps.any { it.id == event.id }) {
                copy(steps = steps.map { if (it.id == event.id) step else it })
            } else {
                copy(steps = steps + step)
            }
        }
        is PreviewEvent.HopReached ->
            if (event.host == hopHosts.lastOrNull()) this else copy(hopHosts = hopHosts + event.host)
        PreviewEvent.StepsUnavailable -> copy(stepsAvailable = false)
        is PreviewEvent.Finished -> this
    }

    companion object {
        /** The step under which the hop hosts are listed. */
        const val STEP_REDIRECTS = "redirects"
    }
}
