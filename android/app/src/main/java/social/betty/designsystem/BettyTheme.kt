package social.betty.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextGeometricTransform
import androidx.compose.ui.text.style.TextDecoration

private val LocalBettyColors = staticCompositionLocalOf { ThemeColors.dark }
private val LocalBettyTypography = staticCompositionLocalOf { BettyTypography() }

/**
 * Entry point for Betty's visual identity. Reads colors from the theme set (dark default)
 * and exposes them + the type scale through composition locals. Views read
 * `BettyTheme.colors` / `BettyTheme.type`, never Material defaults — Betty surfaces are
 * branded, not system.
 */
object BettyTheme {
    val colors: ThemeColors
        @Composable @ReadOnlyComposable get() = LocalBettyColors.current
    val type: BettyTypography
        @Composable @ReadOnlyComposable get() = LocalBettyTypography.current
}

@Composable
fun BettyTheme(
    mode: ThemeMode = ThemeMode.DARK,
    content: @Composable () -> Unit,
) {
    val isLight = when (mode) {
        ThemeMode.LIGHT -> true
        ThemeMode.DARK -> false
        ThemeMode.SYSTEM -> !isSystemInDarkTheme()
    }
    val colors = if (isLight) ThemeColors.light else ThemeColors.dark
    CompositionLocalProvider(
        LocalBettyColors provides colors,
        LocalBettyTypography provides BettyTypography(),
        LocalContentColor provides colors.textPrimary,
        content = content,
    )
}

/**
 * The single most reused style in the app: uppercase, heavy, wide-tracked label.
 * `Modifier`-free helper that returns a styled [TextStyle] for use with `Text(style = ...)`.
 */
fun BettyTypography.kickerStyle(base: TextStyle, color: Color): TextStyle =
    base.copy(color = color)

/** Applies the negative tracking + tight box used by display/score text. */
fun TextStyle.displayTight(): TextStyle =
    copy(textGeometricTransform = TextGeometricTransform(scaleX = 1f))

fun TextStyle.underlined(): TextStyle = copy(textDecoration = TextDecoration.Underline)
