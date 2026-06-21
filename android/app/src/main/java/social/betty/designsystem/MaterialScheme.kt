package social.betty.designsystem

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Maps Betty's semantic [ThemeColors] + brand [Palette] onto a Material 3 [ColorScheme], so
 * stock M3 components (TopAppBar, NavigationBar, Button, Chip, ModalBottomSheet…) inherit the
 * brand palette instead of the M3 baseline purple. Colors are *reused*, never invented.
 *
 * Sharp 2dp corners remain the identity — see [BettyShapes]; only the brand palette feeds M3.
 * Android intentionally diverges from the shared iOS/web look here (Material is the native idiom).
 */
fun bettyColorScheme(c: ThemeColors): ColorScheme {
    val base = if (c.isLight) lightColorScheme() else darkColorScheme()
    return base.copy(
        primary = Palette.orange,
        onPrimary = Color.White,
        primaryContainer = Palette.orangeTint18,
        onPrimaryContainer = Palette.orange,
        secondary = Palette.indigo,
        onSecondary = Color.White,
        // NavigationBar's default active-pill (secondaryContainer) → branded orange tint.
        secondaryContainer = Palette.orangeTint18,
        onSecondaryContainer = Palette.orange,
        tertiary = Palette.yellow,
        onTertiary = Palette.ink,
        background = c.background,
        onBackground = c.textPrimary,
        surface = c.surface,
        onSurface = c.textPrimary,
        surfaceVariant = c.surfaceDeep,
        onSurfaceVariant = c.textSecondary,
        outline = c.textMuted,
        outlineVariant = c.overlay10,
        error = Palette.alertRed,
        onError = Color.White,
        scrim = Palette.ink,
    )
}

/**
 * M3 shape scale pinned to Betty's near-square corners (design.md §3.2 — "THE Betty radius",
 * a core identity trait). Kept sharp on purpose; only the ModalBottomSheet top is softened
 * slightly via [extraLarge] for the standard Material pulled-sheet feel.
 */
val BettyShapes = Shapes(
    extraSmall = RoundedCornerShape(2.dp),
    small = RoundedCornerShape(2.dp),
    medium = RoundedCornerShape(2.dp),
    large = RoundedCornerShape(4.dp),
    extraLarge = RoundedCornerShape(10.dp),
)
