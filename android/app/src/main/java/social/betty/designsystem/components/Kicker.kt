package social.betty.designsystem.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import social.betty.designsystem.BettyTheme

/**
 * Renders a kicker label: uppercase, 11sp heavy, wide letter spacing (+1.5em per the type
 * token). The type token in [BettyTypography.kicker] already encodes the weight and
 * tracking, so this is a thin convenience composable — use it whenever you'd reach for
 * `Text(style = BettyTheme.type.kicker, ...)` with an uppercase transform.
 *
 * For inline use inside a Row/Column you can also call
 * `Text(text.uppercase(), style = BettyTheme.type.kicker, color = …)` directly.
 *
 * @param text  Label text (auto-uppercased).
 * @param color Text color.
 */
@Composable
fun KickerText(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    val type = BettyTheme.type
    Text(
        text = text.uppercase(),
        style = type.kicker,
        color = color,
        modifier = modifier.testTag("KickerText"),
    )
}
