package social.betty.designsystem

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextGeometricTransform
import androidx.compose.ui.text.style.TextDecoration
import androidx.core.view.WindowCompat

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

    // Drive the system status / navigation bar ICON color from the in-app theme. The app
    // forces its own theme (commonly DARK while the OS is in light mode), so we can't rely on
    // enableEdgeToEdge()'s OS-driven default — dark status icons on Betty's dark indigo bar
    // were invisible. isAppearanceLight* = true → dark icons (light bg); false → white icons.
    val view = LocalView.current
    if (!view.isInEditMode) {
        (view.context as? Activity)?.window?.let { window ->
            SideEffect {
                val controller = WindowCompat.getInsetsController(window, view)
                controller.isAppearanceLightStatusBars = isLight
                controller.isAppearanceLightNavigationBars = isLight
            }
        }
    }

    // Wrap in MaterialTheme so stock M3 components inherit Betty's brand palette + sharp
    // corners (otherwise they fall back to the baseline M3 purple). Betty's own bespoke
    // tokens still flow through the composition locals below.
    MaterialTheme(
        colorScheme = bettyColorScheme(colors),
        shapes = BettyShapes,
    ) {
        CompositionLocalProvider(
            LocalBettyColors provides colors,
            LocalBettyTypography provides BettyTypography(),
            LocalContentColor provides colors.textPrimary,
            content = content,
        )
    }
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
