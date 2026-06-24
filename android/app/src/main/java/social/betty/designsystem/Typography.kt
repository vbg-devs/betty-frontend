package social.betty.designsystem

import androidx.compose.runtime.Immutable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextGeometricTransform
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

/**
 * Betty type scale (design.md §2). The web app proper renders in the platform system
 * font; the faithful Android translation is the system sans (no custom font shipped).
 * Identity lives in the weights: 800/900 for display, uppercase + wide tracking for
 * kickers, tight negative tracking for big numerals. Scores use tabular figures.
 *
 * `sp` is used for px parity with the web's fixed-px scale (Dynamic-type scaling is left
 * to the OS; sizes are intentionally fixed like the source).
 */
@Immutable
class BettyTypography {
    private val black = FontWeight(900)
    private val heavy = FontWeight(800)
    private val bold = FontWeight.Bold
    private val semibold = FontWeight.SemiBold

    val displayXL = TextStyle(fontWeight = black, fontSize = 64.sp, letterSpacing = (-0.02).em)
    val displayL = TextStyle(fontWeight = black, fontSize = 40.sp, letterSpacing = (-0.01).em)
    val title1 = TextStyle(fontWeight = black, fontSize = 32.sp, letterSpacing = (-0.01).em)
    val title2 = TextStyle(fontWeight = black, fontSize = 28.sp, letterSpacing = (-0.02).em)
    val title3 = TextStyle(fontWeight = black, fontSize = 22.sp, letterSpacing = (-0.02).em)
    val headline = TextStyle(fontWeight = heavy, fontSize = 17.sp, letterSpacing = (-0.005).em)
    val body = TextStyle(fontWeight = semibold, fontSize = 15.sp)
    val bodyRegular = TextStyle(fontWeight = FontWeight.Normal, fontSize = 15.sp)
    val subhead = TextStyle(fontWeight = bold, fontSize = 14.sp)
    val caption = TextStyle(fontWeight = heavy, fontSize = 12.sp, letterSpacing = 0.13.em)
    val kicker = TextStyle(fontWeight = heavy, fontSize = 11.sp, letterSpacing = 0.15.em)
    val micro = TextStyle(fontWeight = heavy, fontSize = 10.sp, letterSpacing = 0.13.em)

    // Tabular-figure scores. FontFamily.Monospace gives fixed-width digits.
    val scoreXL = TextStyle(
        fontFamily = FontFamily.Monospace, fontWeight = black, fontSize = 56.sp,
        letterSpacing = (-0.02).em,
    )
    val score = TextStyle(
        fontFamily = FontFamily.Monospace, fontWeight = black, fontSize = 28.sp,
        letterSpacing = (-0.02).em,
    )
    val scoreRow = TextStyle(
        fontFamily = FontFamily.Monospace, fontWeight = black, fontSize = 26.sp,
        letterSpacing = (-0.02).em,
    )

    companion object {
        /** Squash transform applied to display text to approximate the web's tight line box. */
        val displaySquash = TextGeometricTransform(scaleX = 1f, skewX = 0f)
    }
}
