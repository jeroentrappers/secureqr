package be.appmire.secureqr.ui.scan

import android.content.Context
import android.net.Uri
import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.ZoomSuggestionOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume

/** QR-only scanner on the bundled ML Kit model. [zoom] lets ML Kit ask for a closer look at small codes. */
internal fun qrScanner(zoom: ZoomSuggestionOptions? = null): BarcodeScanner {
    val options = BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE)
    if (zoom != null) options.setZoomSuggestionOptions(zoom)
    return BarcodeScanning.getClient(options.build())
}

private fun List<Barcode>.firstText(): String? = firstNotNullOfOrNull { code -> code.rawValue?.takeIf { it.isNotBlank() } }

/**
 * Feeds camera frames to ML Kit and reports the first QR code exactly once.
 * After that every frame is dropped, so one scan can never trigger twice; a
 * new analyzer is created when the user comes back to the scanner.
 */
internal class QrAnalyzer(
    private val scanner: BarcodeScanner,
    private val onDetected: (String) -> Unit,
) : ImageAnalysis.Analyzer {

    private val detected = AtomicBoolean(false)

    @OptIn(ExperimentalGetImage::class)
    override fun analyze(frame: ImageProxy) {
        val image = frame.image
        if (image == null || detected.get()) {
            frame.close()
            return
        }
        scanner.process(InputImage.fromMediaImage(image, frame.imageInfo.rotationDegrees))
            .addOnSuccessListener { codes ->
                val text = codes.firstText()
                if (text != null && detected.compareAndSet(false, true)) onDetected(text)
            }
            .addOnCompleteListener { frame.close() }
    }
}

internal sealed interface ImageScanResult {
    data class Found(val text: String) : ImageScanResult
    data object NothingFound : ImageScanResult
    data object Unreadable : ImageScanResult
}

/** Scans a picture chosen in the photo picker. */
internal suspend fun scanImage(context: Context, uri: Uri): ImageScanResult {
    val image = try {
        withContext(Dispatchers.IO) { InputImage.fromFilePath(context, uri) }
    } catch (e: Exception) {
        return ImageScanResult.Unreadable
    }
    val scanner = qrScanner()
    return suspendCancellableCoroutine { continuation ->
        scanner.process(image)
            .addOnSuccessListener { codes ->
                val text = codes.firstText()
                continuation.resume(if (text != null) ImageScanResult.Found(text) else ImageScanResult.NothingFound)
            }
            .addOnFailureListener { continuation.resume(ImageScanResult.Unreadable) }
            .addOnCompleteListener { scanner.close() }
    }
}
