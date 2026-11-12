package be.appmire.secureqr.ui

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged

private const val MAX_ZOOM = 5f

/**
 * Pinch to enlarge a picture in place, drag to move it while enlarged, and
 * double-tap to go back to normal size. A single finger on a picture that is
 * not enlarged is left alone, so the page around it still scrolls. [key]
 * resets the zoom when it changes (another picture, another layout).
 */
fun Modifier.pinchZoom(key: Any? = null): Modifier = composed {
    var scale by remember(key) { mutableFloatStateOf(1f) }
    var offset by remember(key) { mutableStateOf(Offset.Zero) }

    this
        .clipToBounds()
        .pointerInput(key) {
            detectTapGestures(onDoubleTap = {
                scale = 1f
                offset = Offset.Zero
            })
        }
        .pointerInput(key) {
            awaitEachGesture {
                awaitFirstDown(requireUnconsumed = false)
                do {
                    val event = awaitPointerEvent()
                    val fingers = event.changes.count { it.pressed }
                    if (fingers >= 2 || scale > 1f) {
                        scale = (scale * event.calculateZoom()).coerceIn(1f, MAX_ZOOM)
                        // Keep the picture inside its frame: it may move by half of what it grew.
                        val maxX = size.width * (scale - 1f) / 2f
                        val maxY = size.height * (scale - 1f) / 2f
                        val moved = offset + event.calculatePan()
                        offset = Offset(moved.x.coerceIn(-maxX, maxX), moved.y.coerceIn(-maxY, maxY))
                        event.changes.forEach { if (it.positionChanged()) it.consume() }
                    }
                } while (event.changes.any { it.pressed })
            }
        }
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
            translationX = offset.x
            translationY = offset.y
        }
}
