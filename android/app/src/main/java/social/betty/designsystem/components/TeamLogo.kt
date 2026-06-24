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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import social.betty.designsystem.BettyTheme

/**
 * Team logo (web `TeamLogo`). Circular logo on `overlay06` fill + 2dp `overlay08` ring.
 *
 * `imageUrl` follows the same `<type>:<key>` scheme as on iOS/web:
 * - `flag:se` → bundled drawable `flag_se` (or remote fallback; see note below)
 * - `pl:arsenal` → remote `https://betty.social/pl/arsenal.png`
 * - anything else / null → fallback initials from `name`
 *
 * NOTE: The Android build does not bundle flag/club art (iOS ships it in an asset
 * catalog). All images are fetched remotely by Coil — flags as SVG (decoded via the
 * `SvgDecoder` registered on `BettyApplication`'s `ImageLoader`) — or fall back to initials.
 *
 * @param url   `imageUrl` string from the Team model (scheme-prefixed or null).
 * @param name  Team name used to derive the single-initial fallback.
 * @param size  Circle diameter (56dp = game cards, 28dp = bet rows, 19dp = feed items).
 */
@Composable
fun TeamLogo(
    url: String?,
    name: String?,
    size: Dp = 56.dp,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val initialFontSize = (size.value * 0.4f).coerceAtLeast(8f).sp

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(colors.overlay06, CircleShape)
            .border(2.dp, colors.overlay08, CircleShape)
            .testTag("TeamLogo"),
    ) {
        val remoteUrl = resolveTeamLogoUrl(url)
        if (remoteUrl != null) {
            AsyncImage(
                model = remoteUrl,
                contentDescription = name,
                contentScale = ContentScale.Crop,
                modifier = Modifier.matchParentSize(),
            )
        } else {
            val initial = name?.trim()?.firstOrNull()?.uppercaseChar()?.toString() ?: ""
            if (initial.isNotEmpty()) {
                Text(
                    text = initial,
                    fontSize = initialFontSize,
                    fontWeight = FontWeight(800),
                    color = colors.textMuted,
                )
            }
        }
    }
}

/**
 * Resolves a `<type>:<key>` image URL string to a network URL string, or null when the
 * type is unsupported / the input is null.
 *
 * - `pl:<key>` → `https://betty.social/pl/<key>.png`
 * - `flag:<key>` → `https://betty.social/flags/<key>.svg` (SVG, decoded by the `SvgDecoder`
 *   registered on `BettyApplication`'s Coil `ImageLoader`; iOS bundles the same art as a
 *   PNG asset catalog instead, but this remote fetch keeps Android at visual parity)
 * - all other types / null → null (show initials)
 */
private fun resolveTeamLogoUrl(raw: String?): String? {
    if (raw.isNullOrEmpty()) return null
    val colon = raw.indexOf(':')
    if (colon < 0) return null
    val type = raw.substring(0, colon)
    val key = raw.substring(colon + 1)
    if (type.isEmpty() || key.isEmpty()) return null
    return when (type) {
        "pl" -> "https://betty.social/pl/$key.png"
        "flag" -> "https://betty.social/flags/$key.svg"
        else -> null
    }
}
