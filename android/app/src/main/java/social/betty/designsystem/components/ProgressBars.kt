package social.betty.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius

private val capsule = RoundedCornerShape(percent = 50)

/**
 * Single green fill bar. 6dp track in `overlay10`, fill in `accentPositive`.
 *
 * @param progress Completion percentage 0–100f.
 */
@Composable
fun BettyProgressBar(
    progress: Float,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val clamped = progress.coerceIn(0f, 100f)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(6.dp)
            .clip(capsule)
            .background(colors.overlay10)
            .testTag("BettyProgressBar"),
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(fraction = clamped / 100f)
                .clip(capsule)
                .background(colors.accentPositive),
        )
    }
}

/**
 * Home / tie / away bet-distribution bar (design.md §5.9).
 *
 * Three segments: left (home) `accentPositive`, center (draw) `white@35%`, right (away)
 * `bettyYellow`. Each segment has a 1px minimum width so 0% still shows a sliver.
 * Caller guarantees the three percentages sum to 100.
 *
 * @param leftFraction   Home segment percentage 0–100f.
 * @param drawFraction   Draw segment percentage 0–100f.
 * @param rightFraction  Away segment percentage 0–100f.
 */
@Composable
fun SplitProgressBar(
    leftFraction: Float,
    drawFraction: Float,
    rightFraction: Float,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val leftClamped = leftFraction.coerceIn(0f, 100f)
    val drawClamped = drawFraction.coerceIn(0f, 100f)
    val rightClamped = rightFraction.coerceIn(0f, 100f)

    // Custom Layout gives each segment a guaranteed 1px minimum even at 0%.
    Layout(
        modifier = modifier
            .fillMaxWidth()
            .height(6.dp)
            .clip(Radius.sharp)
            .testTag("SplitProgressBar"),
        content = {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .background(colors.accentPositive),
            )
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .background(Color.White.copy(alpha = 0.35f)),
            )
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .background(Palette.yellow),
            )
        },
    ) { measurables, constraints ->
        val totalWidth = constraints.maxWidth
        val minPx = 1

        fun pctToWidth(pct: Float) = (pct / 100f * totalWidth).toInt().coerceAtLeast(minPx)

        val leftW = pctToWidth(leftClamped)
        val drawW = pctToWidth(drawClamped)
        val rightW = pctToWidth(rightClamped)
        val h = constraints.maxHeight

        val lp = measurables[0].measure(constraints.copy(minWidth = leftW, maxWidth = leftW, minHeight = h, maxHeight = h))
        val dp2 = measurables[1].measure(constraints.copy(minWidth = drawW, maxWidth = drawW, minHeight = h, maxHeight = h))
        val rp = measurables[2].measure(constraints.copy(minWidth = rightW, maxWidth = rightW, minHeight = h, maxHeight = h))

        layout(totalWidth, h) {
            lp.placeRelative(0, 0)
            dp2.placeRelative(leftW, 0)
            rp.placeRelative(leftW + drawW, 0)
        }
    }
}
