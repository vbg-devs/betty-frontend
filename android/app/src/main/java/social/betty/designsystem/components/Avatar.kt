package social.betty.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette

/** Pre-defined size tokens matching the web/iOS size presets. */
object AvatarSize {
    val small: Dp = 32.dp
    val default: Dp = 42.dp
    val medium: Dp = 64.dp
    val large: Dp = 124.dp
}

/**
 * User avatar (web `UserBadge`). Shows `url` image when non-null/non-empty, otherwise
 * initials from `name` (nil/empty → blank circle; single word → first char; two+ words
 * → first chars of words 1 & 2, uppercased). Ring = `overlay10`, 5pt at large, scaled
 * proportionally at smaller sizes.
 *
 * @param url   Remote image URL string. Null/empty triggers the initials fallback.
 * @param name  Display name used to derive initials. May be null.
 * @param size  Circle diameter in dp. Use [AvatarSize] constants for standard sizes.
 */
@Composable
fun Avatar(
    url: String?,
    name: String?,
    size: Dp = AvatarSize.default,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    // Ring lineWidth scaled from 5dp (at 124dp) proportionally, clamped 2..5.
    val ringWidth = (5f * (size.value / 124f)).coerceIn(2f, 5f).dp
    val initials = computeInitials(name)
    val initialsFontSize = (size.value * 0.38f).coerceAtLeast(10f).sp

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .border(ringWidth, colors.overlay10, CircleShape)
            .testTag("Avatar"),
    ) {
        if (!url.isNullOrEmpty()) {
            AsyncImage(
                model = url,
                contentDescription = name,
                contentScale = ContentScale.Crop,
                onError = { /* silently fall through to initials below */ },
                modifier = Modifier.matchParentSize(),
            )
        } else {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .matchParentSize()
                    .background(Palette.surfaceWhite, CircleShape),
            ) {
                if (initials.isNotEmpty()) {
                    Text(
                        text = initials,
                        fontSize = initialsFontSize,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF333333),
                    )
                }
            }
        }
    }
}

/**
 * Derives display initials from a nullable display name, matching iOS AvatarView.initials:
 * - null/empty → ""
 * - single word → first character (no case transform)
 * - two+ words → first char of word 1 + first char of word 2, uppercased
 */
fun computeInitials(name: String?): String {
    if (name.isNullOrEmpty()) return ""
    val words = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
    if (words.isEmpty()) return ""
    return if (words.size == 1) {
        words[0].first().toString() // no case transform — matches iOS
    } else {
        ("${words[0].first()}${words[1].first()}").uppercase()
    }
}
