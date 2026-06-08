package social.betty.designsystem.components

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import social.betty.designsystem.BettyTheme

/**
 * Concealed pre-kickoff bet score: eye-off icon · dash · eye-off icon.
 * Rendered in `textMuted` at subhead scale (14sp bold), matching HiddenScoreView on iOS.
 *
 * The eye-slash icon is hand-drawn as a vector path so the component does not depend on
 * the `material-icons-extended` library (only `material-icons-core` ships in this build).
 */
@Composable
fun HiddenScore(modifier: Modifier = Modifier) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier.testTag("HiddenScore"),
    ) {
        Icon(
            imageVector = eyeSlashIcon,
            contentDescription = "hidden",
            tint = colors.textMuted,
            modifier = Modifier.size(18.dp),
        )
        Spacer(Modifier.width(4.dp))
        Text(
            text = "–",
            style = type.subhead,
            color = colors.textMuted,
        )
        Spacer(Modifier.width(4.dp))
        Icon(
            imageVector = eyeSlashIcon,
            contentDescription = "hidden",
            tint = colors.textMuted,
            modifier = Modifier.size(18.dp),
        )
    }
}

/**
 * Minimal eye-slash vector path drawn on a 24×24 viewport, matching the Material
 * `visibility_off` glyph without requiring `material-icons-extended`.
 */
private val eyeSlashIcon: ImageVector by lazy {
    ImageVector.Builder(
        name = "EyeSlash",
        defaultWidth = 24.dp,
        defaultHeight = 24.dp,
        viewportWidth = 24f,
        viewportHeight = 24f,
    ).path {
        // Diagonal strike-through slash
        moveTo(2f, 4.27f)
        lineTo(3.27f, 3f)
        lineTo(21f, 20.73f)
        lineTo(19.73f, 22f)
        lineTo(16.12f, 18.39f)
        // Outer eye curve (lower half) — simplified
        curveTo(14.8f, 18.79f, 13.42f, 19f, 12f, 19f)
        curveTo(7f, 19f, 2.73f, 15.89f, 1f, 12f)
        curveTo(1.77f, 10.18f, 2.97f, 8.58f, 4.47f, 7.33f)
        lineTo(2f, 4.27f)
        close()
        // Upper eye arc
        moveTo(12f, 5f)
        curveTo(17f, 5f, 21.27f, 8.11f, 23f, 12f)
        curveTo(22.18f, 13.9f, 20.87f, 15.55f, 19.24f, 16.78f)
        lineTo(17.81f, 15.35f)
        curveTo(18.99f, 14.47f, 19.99f, 13.32f, 20.65f, 12f)
        curveTo(19.13f, 8.92f, 15.78f, 7f, 12f, 7f)
        curveTo(10.9f, 7f, 9.83f, 7.2f, 8.84f, 7.55f)
        lineTo(7.28f, 5.99f)
        curveTo(8.77f, 5.35f, 10.35f, 5f, 12f, 5f)
        close()
        // Inner pupil cutout
        moveTo(12f, 9f)
        curveTo(13.18f, 9f, 14.24f, 9.47f, 15.02f, 10.25f)
        lineTo(10.25f, 15.02f)
        curveTo(9.47f, 14.24f, 9f, 13.18f, 9f, 12f)
        curveTo(9f, 10.34f, 10.34f, 9f, 12f, 9f)
        close()
    }.build()
}
