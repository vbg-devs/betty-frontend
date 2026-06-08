package social.betty.designsystem.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import social.betty.designsystem.BettyTheme

/**
 * Large monospaced score — 56sp / black / tabular (bet modal score input, hero scores).
 * Color defaults to `textPrimary`.
 */
@Composable
fun ScoreXL(
    text: String,
    modifier: Modifier = Modifier,
    color: Color? = null,
    textAlign: TextAlign = TextAlign.Start,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Text(
        text = text,
        style = type.scoreXL,
        color = color ?: colors.textPrimary,
        textAlign = textAlign,
        modifier = modifier.testTag("ScoreXL"),
    )
}

/**
 * Game tile score — 28sp / black / tabular (displayed in game cards for finished scores).
 * Color defaults to `textPrimary`.
 */
@Composable
fun ScoreText(
    text: String,
    modifier: Modifier = Modifier,
    color: Color? = null,
    textAlign: TextAlign = TextAlign.Start,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Text(
        text = text,
        style = type.score,
        color = color ?: colors.textPrimary,
        textAlign = textAlign,
        modifier = modifier.testTag("ScoreText"),
    )
}

/**
 * Leaderboard points row — 26sp / black / tabular.
 * Color defaults to `textPrimary`.
 */
@Composable
fun ScoreRow(
    text: String,
    modifier: Modifier = Modifier,
    color: Color? = null,
    textAlign: TextAlign = TextAlign.Start,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Text(
        text = text,
        style = type.scoreRow,
        color = color ?: colors.textPrimary,
        textAlign = textAlign,
        modifier = modifier.testTag("ScoreRow"),
    )
}
