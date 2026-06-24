package social.betty.designsystem

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/**
 * Semantic color set (design.md §1.2). Dark indigo is the default; light is an explicit
 * user toggle. Green remaps to indigo in light (`accentPositive`). Brand colors live in
 * [Palette] and are constant across themes.
 */
@Immutable
data class ThemeColors(
    val background: Color,
    val surface: Color,
    val surfaceDeep: Color,
    val surfaceSoft: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val textBody: Color,
    val accentPositive: Color,
    val overlay04: Color,
    val overlay06: Color,
    val overlay08: Color,
    val overlay10: Color,
    val isLight: Boolean,
) {
    companion object {
        val dark = ThemeColors(
            background = Palette.indigo,
            surface = Color(0xFF1F2752),
            surfaceDeep = Color(0xFF141938),
            surfaceSoft = Color(0xFFFFF5E4),
            textPrimary = Color(0xFFFFFAEB),
            textSecondary = Color(0xFFFFFAEB).copy(alpha = 0.78f),
            textMuted = Color(0xFFFFFAEB).copy(alpha = 0.50f),
            textBody = Color(0xFFCDD1E5),
            accentPositive = Color(0xFF9BFF3D),
            overlay04 = Color.White.copy(alpha = 0.04f),
            overlay06 = Color.White.copy(alpha = 0.06f),
            overlay08 = Color.White.copy(alpha = 0.08f),
            overlay10 = Color.White.copy(alpha = 0.10f),
            isLight = false,
        )

        private val inkTint = Color(0xFF141938)

        val light = ThemeColors(
            background = Color(0xFFFFFAEB),
            surface = Color.White,
            surfaceDeep = Color(0xFFF1EAD4),
            surfaceSoft = Color(0xFF1F2752),
            textPrimary = inkTint,
            textSecondary = inkTint.copy(alpha = 0.82f),
            textMuted = inkTint.copy(alpha = 0.55f),
            textBody = Color(0xFF525874),
            accentPositive = Palette.indigo,
            overlay04 = inkTint.copy(alpha = 0.04f),
            overlay06 = inkTint.copy(alpha = 0.06f),
            overlay08 = inkTint.copy(alpha = 0.08f),
            overlay10 = inkTint.copy(alpha = 0.10f),
            isLight = true,
        )
    }
}
