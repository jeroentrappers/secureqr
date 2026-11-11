package be.appmire.secureqr.ui.scan

import android.util.Size
import android.view.HapticFeedbackConstants
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.ZoomSuggestionOptions
import java.util.concurrent.Executors

/**
 * Live camera preview that reports the first QR code it sees, once.
 *
 * The camera and the analyzer only exist while this composable is on screen,
 * so nothing is analysed after a scan until the user returns to the scanner.
 */
@Composable
internal fun CameraPreview(
    torchOn: Boolean,
    onTorchAvailable: (Boolean) -> Unit,
    onDetected: (String) -> Unit,
    onError: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnDetected by rememberUpdatedState(onDetected)
    val currentOnTorchAvailable by rememberUpdatedState(onTorchAvailable)
    val currentOnError by rememberUpdatedState(onError)

    val previewView = remember {
        PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER }
    }
    var camera by remember { mutableStateOf<Camera?>(null) }

    DisposableEffect(lifecycleOwner) {
        val analysisExecutor = Executors.newSingleThreadExecutor()
        val providerFuture = ProcessCameraProvider.getInstance(context)
        var provider: ProcessCameraProvider? = null
        var scanner: BarcodeScanner? = null
        var disposed = false

        providerFuture.addListener({
            if (disposed) return@addListener
            try {
                val cameraProvider = providerFuture.get().also { provider = it }
                val selector = if (cameraProvider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) {
                    CameraSelector.DEFAULT_BACK_CAMERA
                } else {
                    CameraSelector.DEFAULT_FRONT_CAMERA
                }
                val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setResolutionSelector(
                        ResolutionSelector.Builder()
                            .setResolutionStrategy(
                                ResolutionStrategy(
                                    Size(1280, 720),
                                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                                ),
                            )
                            .build(),
                    )
                    .build()

                cameraProvider.unbindAll()
                val bound = cameraProvider.bindToLifecycle(lifecycleOwner, selector, preview, analysis)

                // ML Kit suggests a zoom ratio when it sees a code that is too small to read.
                val maxZoom = bound.cameraInfo.zoomState.value?.maxZoomRatio ?: 1f
                val zoom = ZoomSuggestionOptions.Builder { ratio ->
                    bound.cameraControl.setZoomRatio(ratio)
                    true
                }.setMaxSupportedZoomRatio(maxZoom).build()

                val qrScanner = qrScanner(zoom).also { scanner = it }
                analysis.setAnalyzer(
                    analysisExecutor,
                    QrAnalyzer(qrScanner) { text ->
                        analysis.clearAnalyzer()
                        previewView.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        currentOnDetected(text)
                    },
                )
                camera = bound
                currentOnTorchAvailable(bound.cameraInfo.hasFlashUnit())
            } catch (e: Exception) {
                currentOnError()
            }
        }, ContextCompat.getMainExecutor(context))

        onDispose {
            disposed = true
            provider?.unbindAll()
            scanner?.close()
            analysisExecutor.shutdown()
            camera = null
        }
    }

    LaunchedEffect(camera, torchOn) {
        val bound = camera ?: return@LaunchedEffect
        if (bound.cameraInfo.hasFlashUnit()) bound.cameraControl.enableTorch(torchOn)
    }

    AndroidView(factory = { previewView }, modifier = modifier)
}
