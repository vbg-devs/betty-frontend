package social.betty.designsystem

import androidx.compose.ui.graphics.Color

/**
 * Theme-independent brand constants and fixed-alpha tints (design.md §1.1, §1.3).
 * These never change between light and dark.
 */
object Palette {
    val orange = Color(0xFFFF5A3A)
    val yellow = Color(0xFFFFD84A)
    val ink = Color(0xFF0D0E15)
    val indigo = Color(0xFF434F8E)
    val legacyGreen = Color(0xFF78CC14)
    val alertRed = Color(0xFFF44336)
    val dropdownDanger = Color(0xFFD8412F)

    // Derived / fixed-alpha tints (design.md §1.3)
    val orangeTint12 = orange.copy(alpha = 0.12f)
    val orangeTint15 = orange.copy(alpha = 0.15f)
    val orangeTint18 = orange.copy(alpha = 0.18f)
    val modalBackdrop = Color(0xFF0A0E23).copy(alpha = 0.82f)
    val pillDark = Color(0xFF141938).copy(alpha = 0.78f)
    val surfaceWhite = Color(0xFFFFFFFF)

    /** White-surface menu constants — do NOT adapt to theme (design.md §1.3). */
    object Menu {
        val title = Color(0xFF1F2752)
        val secondary = Color(0xFF6B7090)
        val hairline = Color(0xFFEEF0F5)
        val hover = Color(0xFFF4F5FA)
        val danger = Color(0xFFD8412F)
        val dangerHover = Color(0xFFFDF0EE)
    }
}
