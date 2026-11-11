package be.appmire.secureqr.ui.scan

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.DrawableRes
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import be.appmire.secureqr.R
import be.appmire.secureqr.ui.SystemActions
import be.appmire.secureqr.ui.components.BrandCard
import be.appmire.secureqr.ui.components.BrandTopBar
import be.appmire.secureqr.ui.components.GhostButton
import be.appmire.secureqr.ui.components.PrimaryButton
import be.appmire.secureqr.ui.theme.Brand
import be.appmire.secureqr.ui.theme.Dimens
import kotlinx.coroutines.launch

private enum class CameraAccess {
    GRANTED,

    /** Not granted yet: explain first, then ask. */
    EXPLAIN,

    /** The user said no: point at Settings, keep gallery scanning available. */
    DENIED,
}

private fun hasCameraPermission(context: Context) =
    ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

/** Scanner. Always dark: it sits on the camera image (the caller applies the dark theme). */
@Composable
fun ScanScreen(
    onScanned: (String) -> Unit,
    onHistory: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var denied by rememberSaveable { mutableStateOf(false) }
    var granted by remember { mutableStateOf(hasCameraPermission(context)) }
    val access = when {
        granted -> CameraAccess.GRANTED
        denied -> CameraAccess.DENIED
        else -> CameraAccess.EXPLAIN
    }

    // Pick up a change made in system Settings while the app was in the background.
    LifecycleResumeEffect(Unit) {
        granted = hasCameraPermission(context)
        onPauseOrDispose { }
    }

    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        granted = ok
        denied = !ok
    }

    // System photo picker: no storage permission involved.
    val imagePicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            scope.launch {
                when (val result = scanImage(context, uri)) {
                    is ImageScanResult.Found -> onScanned(result.text)
                    ImageScanResult.NothingFound -> SystemActions.toast(context, R.string.scan_no_qr_in_image)
                    ImageScanResult.Unreadable -> SystemActions.toast(context, R.string.scan_image_failed)
                }
            }
        }
    }
    val pickImage = {
        imagePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
    }

    var torchOn by rememberSaveable { mutableStateOf(false) }
    var torchAvailable by remember { mutableStateOf(false) }

    Box(
        Modifier
            .fillMaxSize()
            .background(if (access == CameraAccess.GRANTED) Color.Black else Brand.colors.bg),
    ) {
        if (access == CameraAccess.GRANTED) {
            CameraPreview(
                torchOn = torchOn,
                onTorchAvailable = { torchAvailable = it },
                onDetected = onScanned,
                onError = { SystemActions.toast(context, R.string.scan_camera_failed) },
                modifier = Modifier.fillMaxSize(),
            )
            // Keep the bars and the hint readable over a bright scene.
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            0f to Color.Black.copy(alpha = 0.8f),
                            0.12f to Color.Black.copy(alpha = 0.65f),
                            0.3f to Color.Transparent,
                            0.65f to Color.Transparent,
                            1f to Color.Black.copy(alpha = 0.75f),
                        ),
                    ),
            )
            Reticle(Modifier.fillMaxSize())
        }

        Column(
            Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing),
        ) {
            BrandTopBar()

            when (access) {
                CameraAccess.GRANTED -> {
                    Spacer(Modifier.weight(1f))
                    HintPill(
                        Modifier
                            .align(Alignment.CenterHorizontally)
                            .padding(horizontal = Dimens.screenPadding),
                    )
                }

                else -> PermissionPanel(
                    denied = access == CameraAccess.DENIED,
                    onAllow = { permissionLauncher.launch(Manifest.permission.CAMERA) },
                    onOpenSettings = { SystemActions.openAppSettings(context) },
                    onPickImage = pickImage,
                    // After a hard "don't ask again" the system dialog no longer appears; Settings is the way.
                    canAskAgain = context.findActivity()?.let {
                        ActivityCompat.shouldShowRequestPermissionRationale(it, Manifest.permission.CAMERA)
                    } ?: false,
                    modifier = Modifier.weight(1f),
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Dimens.screenPadding)
                    .padding(top = 16.dp, bottom = 24.dp),
                horizontalArrangement = Arrangement.SpaceAround,
            ) {
                if (access == CameraAccess.GRANTED) {
                    ToolButton(
                        icon = if (torchOn) R.drawable.ic_flash_on else R.drawable.ic_flash_off,
                        label = stringResource(if (torchOn) R.string.scan_torch_off else R.string.scan_torch_on),
                        enabled = torchAvailable,
                        active = torchOn,
                        onClick = { torchOn = !torchOn },
                    )
                }
                ToolButton(R.drawable.ic_image, stringResource(R.string.scan_pick_image), onClick = pickImage)
                ToolButton(R.drawable.ic_history, stringResource(R.string.scan_history), onClick = onHistory)
            }
        }
    }
}

/** Four accent corner brackets, centred a little above the middle like the mock-up. */
@Composable
private fun Reticle(modifier: Modifier = Modifier) {
    val color = Brand.colors.accent
    Canvas(modifier) {
        val side = minOf(size.width * 0.68f, 300.dp.toPx())
        val arm = side * 0.19f
        val radius = (Dimens.radius + 2.dp).toPx()
        val stroke = 5.dp.toPx()
        val center = Offset(size.width / 2f, size.height * 0.44f)
        val left = center.x - side / 2f
        val top = center.y - side / 2f

        val corner = Path().apply {
            moveTo(left, top + arm)
            lineTo(left, top + radius)
            arcTo(Rect(Offset(left, top), Size(radius * 2, radius * 2)), 180f, 90f, false)
            lineTo(left + arm, top)
        }
        val style = Stroke(width = stroke, cap = StrokeCap.Round, join = StrokeJoin.Round)
        for ((sx, sy) in listOf(1f to 1f, -1f to 1f, 1f to -1f, -1f to -1f)) {
            scale(sx, sy, pivot = center) { drawPath(corner, color, style = style) }
        }
    }
}

@Composable
private fun HintPill(modifier: Modifier = Modifier) {
    val emphasis = stringResource(R.string.scan_hint_emphasis)
    val template = stringResource(R.string.scan_hint, "\u0000")
    val text = buildAnnotatedString {
        append(template.substringBefore('\u0000'))
        withStyle(SpanStyle(color = Brand.colors.accent, fontWeight = FontWeight.Bold)) { append(emphasis) }
        append(template.substringAfter('\u0000', ""))
    }
    Text(
        text = text,
        style = Brand.type.small,
        color = Color.White,
        textAlign = TextAlign.Center,
        modifier = modifier
            .clip(Dimens.cardShape)
            .background(Color.Black.copy(alpha = 0.6f))
            .padding(horizontal = 16.dp, vertical = 12.dp),
    )
}

@Composable
private fun ToolButton(
    @DrawableRes icon: Int,
    label: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    active: Boolean = false,
) {
    Box(
        modifier = Modifier
            .size(56.dp)
            .clip(CircleShape)
            // A dark base under the translucent white keeps the button visible over a bright scene.
            .background(if (active) Color.White else Color.Black.copy(alpha = 0.35f))
            .background(if (active) Color.White else Color.White.copy(alpha = 0.14f))
            .clickable(enabled = enabled, role = Role.Button, onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            painter = painterResource(icon),
            contentDescription = label,
            tint = when {
                active -> Color.Black
                enabled -> Color.White
                else -> Color.White.copy(alpha = 0.35f)
            },
            modifier = Modifier.size(24.dp),
        )
    }
}

/** Shown instead of the camera: first the reason for the permission, and after a refusal the way out. */
@Composable
private fun PermissionPanel(
    denied: Boolean,
    canAskAgain: Boolean,
    onAllow: () -> Unit,
    onOpenSettings: () -> Unit,
    onPickImage: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(Dimens.screenPadding),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        BrandCard(Modifier.widthIn(max = 480.dp)) {
            Text(
                stringResource(if (denied) R.string.permission_denied_title else R.string.permission_title),
                style = Brand.type.heading,
                color = Brand.colors.ink,
            )
            Spacer(Modifier.size(8.dp))
            Text(
                stringResource(if (denied) R.string.permission_denied_body else R.string.permission_rationale),
                style = Brand.type.body,
                color = Brand.colors.muted,
            )
            Spacer(Modifier.size(16.dp))
            Column(verticalArrangement = Arrangement.spacedBy(Dimens.gap)) {
                if (denied) {
                    PrimaryButton(stringResource(R.string.permission_open_settings), onOpenSettings, Modifier.fillMaxWidth())
                    if (canAskAgain) {
                        GhostButton(stringResource(R.string.permission_allow), onAllow, Modifier.fillMaxWidth(), emphasised = true)
                    }
                } else {
                    PrimaryButton(stringResource(R.string.permission_allow), onAllow, Modifier.fillMaxWidth())
                }
                GhostButton(stringResource(R.string.permission_pick_image), onPickImage, Modifier.fillMaxWidth())
            }
        }
    }
}
