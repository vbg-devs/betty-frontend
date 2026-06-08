package social.betty.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Radius
import social.betty.designsystem.Space

/**
 * Surface card — `colors.surface` background, 2dp radius (Radius.sharp), 22dp body padding.
 *
 * @param imageUrl   Optional header image URL. When non-null a 16:9 AsyncImage is shown
 *                   with a bottom scrim gradient and the [badgeSlot] overlay.
 * @param badgeSlot  Composable overlaid at the bottom-start of the header image.
 * @param content    Card body content.
 */
@Composable
fun SurfaceCard(
    modifier: Modifier = Modifier,
    imageUrl: String? = null,
    badgeSlot: (@Composable BoxScope.() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val colors = BettyTheme.colors
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.surface),
    ) {
        if (imageUrl != null) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f),
            ) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
                // Bottom scrim: `#141938 @ 0% → 82%` (design.md §1.3 scrimGradient).
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Transparent,
                                    Color(0xFF141938).copy(alpha = 0.82f),
                                ),
                            )
                        ),
                )
                if (badgeSlot != null) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(Space.s),
                        content = badgeSlot,
                    )
                }
            }
        }
        Box(modifier = Modifier.padding(Space.l)) {
            content()
        }
    }
}

/**
 * Inset panel — `colors.surfaceDeep` background, 2dp radius, **3dp left accent bar**
 * in `colors.accentPositive`. The accent bar is a signature Betty element.
 *
 * @param accent  Override accent bar color. Defaults to `colors.accentPositive`.
 * @param content Panel content.
 */
@Composable
fun InsetPanel(
    modifier: Modifier = Modifier,
    accent: Color? = null,
    content: @Composable () -> Unit,
) {
    val colors = BettyTheme.colors
    val accentColor = accent ?: colors.accentPositive

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.surfaceDeep)
            .height(IntrinsicSize.Min),
    ) {
        // 3dp left accent bar — the signature element.
        Box(
            modifier = Modifier
                .width(3.dp)
                .fillMaxHeight()
                .background(accentColor),
        )
        Box(modifier = Modifier.padding(Space.m)) {
            content()
        }
    }
}
