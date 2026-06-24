package social.betty.designsystem.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius

/** Orange bg / white micro text — current user's row. */
@Composable
fun YouBadge(modifier: Modifier = Modifier) {
    val type = BettyTheme.type
    Text(
        text = "YOU",
        style = type.micro,
        letterSpacing = type.micro.letterSpacing,
        color = Color.White,
        modifier = modifier
            .clip(Radius.sharp)
            .background(Palette.orange)
            .padding(vertical = 3.dp, horizontal = 7.dp)
            .testTag("YouBadge"),
    )
}

/**
 * Pulsing orange blob + "LIVE" — the 150-minute kickoff window indicator.
 * The outer ring pulses from scale 1 → ~2.2 while fading from 0.7 → 0, on a 2s loop.
 */
@Composable
fun LiveBadge(modifier: Modifier = Modifier) {
    val type = BettyTheme.type
    val infiniteTransition = rememberInfiniteTransition(label = "livePulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 2.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2000),
            repeatMode = RepeatMode.Restart,
        ),
        label = "pulseScale",
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.7f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2000),
            repeatMode = RepeatMode.Restart,
        ),
        label = "pulseAlpha",
    )

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier.testTag("LiveBadge"),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(16.dp),
        ) {
            // Pulse ring
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .scale(pulseScale)
                    .clip(CircleShape)
                    .background(Palette.orange.copy(alpha = pulseAlpha)),
            )
            // Solid inner dot
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(Palette.orange),
            )
        }
        Spacer(Modifier.width(6.dp))
        Text(
            text = "LIVE",
            style = type.kicker,
            color = Palette.orange,
        )
    }
}

/** Yellow bg / ink text — finished groups. Accepts custom text (e.g. "JUST ENDED"). */
@Composable
fun EndedBadge(
    text: String = "ENDED",
    modifier: Modifier = Modifier,
) {
    val type = BettyTheme.type
    Text(
        text = text,
        style = type.kicker,
        color = Palette.ink,
        modifier = modifier
            .clip(Radius.sharp)
            .background(Palette.yellow)
            .padding(vertical = 3.dp, horizontal = 8.dp)
            .testTag("EndedBadge"),
    )
}

/**
 * Dark translucent pill over images — "PUBLIC" with an acid-green dot.
 * Background uses `pillDark` per design.md §1.3 (web adds blur(4), which is not natively
 * composable without a RenderEffect; the color + text are correct; blur is omitted).
 */
@Composable
fun PublicBadge(modifier: Modifier = Modifier) {
    val type = BettyTheme.type
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .clip(Radius.sharp)
            .background(Palette.pillDark)
            .padding(vertical = 4.dp, horizontal = 8.dp)
            .testTag("PublicBadge"),
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(Color(0xFF9BFF3D)),
        )
        Spacer(Modifier.width(5.dp))
        Text(
            text = "PUBLIC",
            style = type.kicker,
            color = Color.White,
        )
    }
}

/**
 * Capsule count pill used by tabs and list rows.
 *
 * @param count    Number to display.
 * @param isActive When true renders in `orangeTint18` bg + orange text.
 */
@Composable
fun CountPill(
    count: Int,
    isActive: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Text(
        text = count.toString(),
        style = type.micro,
        color = if (isActive) Palette.orange else colors.textSecondary,
        modifier = modifier
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(percent = 50))
            .background(if (isActive) Palette.orangeTint18 else colors.overlay08)
            .padding(vertical = 2.dp, horizontal = 8.dp)
            .testTag("CountPill"),
    )
}
