package be.appmire.secureqr.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import be.appmire.secureqr.R

/** Brand colour tokens from design/brand.md. */
@Immutable
data class BrandColors(
    val bg: Color,
    val surface: Color,
    val line: Color,
    val ink: Color,
    val muted: Color,
    val accent: Color,
    val onAccent: Color,
    val ok: Color,
    val warn: Color,
    val danger: Color,
    val isDark: Boolean,
) {
    /** Banner fill: the level colour at about 15% over the card surface. */
    fun tint(level: Color): Color = level.copy(alpha = 0.15f).compositeOver(surface)
}

val LightBrandColors = BrandColors(
    bg = Color(0xFFF5F7FB),
    surface = Color(0xFFFFFFFF),
    line = Color(0xFFE1E6F0),
    ink = Color(0xFF111933),
    muted = Color(0xFF5F6B85),
    accent = Color(0xFF3B5BFF),
    onAccent = Color(0xFFFFFFFF),
    ok = Color(0xFF0E9F6E),
    warn = Color(0xFFC77700),
    danger = Color(0xFFD92D3A),
    isDark = false,
)

val DarkBrandColors = BrandColors(
    bg = Color(0xFF0E1324),
    surface = Color(0xFF171D33),
    line = Color(0xFF29314D),
    ink = Color(0xFFEEF1FA),
    muted = Color(0xFF9AA5C0),
    accent = Color(0xFF6B84FF),
    onAccent = Color(0xFF0B1020),
    ok = Color(0xFF34C38F),
    warn = Color(0xFFF0A93B),
    danger = Color(0xFFF2616B),
    isDark = true,
)

/** Shape and spacing tokens. */
object Dimens {
    val radius = 22.dp
    val screenPadding = 16.dp
    val cardPadding = 14.dp
    val gap = 12.dp
    val cardShape = RoundedCornerShape(radius)
    val pillShape = RoundedCornerShape(percent = 50)
}

// One variable font file; each weight is an instance on its wght axis.
@OptIn(ExperimentalTextApi::class)
private fun nunito(weight: FontWeight) = Font(
    resId = R.font.nunito_sans,
    weight = weight,
    variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)),
)

val NunitoSans = FontFamily(
    nunito(FontWeight.Normal),
    nunito(FontWeight.SemiBold),
    nunito(FontWeight.Bold),
    nunito(FontWeight.ExtraBold),
)

/** Text styles used across the app. Mono styles use the system monospace face. */
@Immutable
data class BrandType(
    val wordmark: TextStyle = TextStyle(fontFamily = NunitoSans, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, letterSpacing = (-0.03).em),
    val heading: TextStyle = TextStyle(fontFamily = NunitoSans, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp, lineHeight = 28.sp, letterSpacing = (-0.01).em),
    val title: TextStyle = TextStyle(fontFamily = NunitoSans, fontWeight = FontWeight.Bold, fontSize = 17.sp, lineHeight = 22.sp),
    val body: TextStyle = TextStyle(fontFamily = NunitoSans, fontWeight = FontWeight.Normal, fontSize = 16.sp, lineHeight = 22.sp),
    val bodyStrong: TextStyle = TextStyle(fontFamily = NunitoSans, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 22.sp),
    val small: TextStyle = TextStyle(fontFamily = NunitoSans, fontWeight = FontWeight.Normal, fontSize = 14.sp, lineHeight = 19.sp),
    val button: TextStyle = TextStyle(fontFamily = NunitoSans, fontWeight = FontWeight.Bold, fontSize = 16.sp, lineHeight = 20.sp),
    val label: TextStyle = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, lineHeight = 14.sp, letterSpacing = 0.1.em),
    val mono: TextStyle = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Normal, fontSize = 15.sp, lineHeight = 21.sp),
    val monoSmall: TextStyle = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Normal, fontSize = 12.sp, lineHeight = 17.sp),
    val monoStrong: TextStyle = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, fontSize = 18.sp, lineHeight = 24.sp),
    val chip: TextStyle = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, lineHeight = 14.sp),
)

private val LocalBrandColors = staticCompositionLocalOf { LightBrandColors }
private val LocalBrandType = staticCompositionLocalOf { BrandType() }

object Brand {
    val colors: BrandColors
        @Composable @ReadOnlyComposable get() = LocalBrandColors.current
    val type: BrandType
        @Composable @ReadOnlyComposable get() = LocalBrandType.current
}

/** Maps the brand tokens onto Material 3 so stock components pick them up too. */
private fun BrandColors.toColorScheme(): ColorScheme {
    val base = if (isDark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = accent,
        onPrimary = onAccent,
        primaryContainer = tint(accent),
        onPrimaryContainer = ink,
        secondary = accent,
        onSecondary = onAccent,
        secondaryContainer = tint(accent),
        onSecondaryContainer = ink,
        tertiary = ok,
        onTertiary = surface,
        background = bg,
        onBackground = ink,
        surface = surface,
        onSurface = ink,
        surfaceVariant = surface,
        onSurfaceVariant = muted,
        surfaceTint = Color.Transparent,
        surfaceContainerLowest = surface,
        surfaceContainerLow = surface,
        surfaceContainer = surface,
        surfaceContainerHigh = surface,
        surfaceContainerHighest = surface,
        outline = line,
        outlineVariant = line,
        error = danger,
        onError = surface,
        errorContainer = tint(danger),
        onErrorContainer = ink,
        scrim = Color.Black,
    )
}

private fun BrandType.toTypography(): Typography {
    val d = Typography()
    return Typography(
        displayLarge = d.displayLarge.copy(fontFamily = NunitoSans),
        displayMedium = d.displayMedium.copy(fontFamily = NunitoSans),
        displaySmall = d.displaySmall.copy(fontFamily = NunitoSans),
        headlineLarge = d.headlineLarge.copy(fontFamily = NunitoSans),
        headlineMedium = d.headlineMedium.copy(fontFamily = NunitoSans),
        headlineSmall = heading,
        titleLarge = heading,
        titleMedium = title,
        titleSmall = bodyStrong,
        bodyLarge = body,
        bodyMedium = body,
        bodySmall = small,
        labelLarge = button,
        labelMedium = small,
        labelSmall = small,
    )
}

/**
 * App theme. Follows the system light/dark setting unless [darkTheme] is
 * forced, which the scanner does because it always sits on the camera image.
 */
@Composable
fun SecureQrTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkBrandColors else LightBrandColors
    val type = BrandType()
    CompositionLocalProvider(
        LocalBrandColors provides colors,
        LocalBrandType provides type,
    ) {
        MaterialTheme(
            colorScheme = colors.toColorScheme(),
            typography = type.toTypography(),
            shapes = Shapes(
                extraSmall = RoundedCornerShape(12.dp),
                small = RoundedCornerShape(16.dp),
                medium = Dimens.cardShape,
                large = Dimens.cardShape,
                extraLarge = Dimens.cardShape,
            ),
            content = content,
        )
    }
}
