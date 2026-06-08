package social.betty.designsystem.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space

/** Visual kind for a toast notification. */
enum class ToastKind { SUCCESS, INFO, ERROR }

/**
 * Data for a single toast notification. The NotifyCenter / screen state machine creates
 * these; this file is purely the visual layer.
 *
 * @param message Human-readable message text.
 * @param kind    Visual style (SUCCESS = green, INFO = orange, ERROR = red).
 */
data class ToastData(
    val message: String,
    val kind: ToastKind = ToastKind.INFO,
)

/**
 * Single toast item: colored indicator dot + message on a styled pill, auto-dismissed
 * after [durationMs]. Renders with a slide-up / fade-in animation.
 *
 * The indicator is a 10dp filled circle in the kind's accent color (no extended-icons dep).
 *
 * @param data        Toast content.
 * @param onDismiss   Called when the toast should be removed from state.
 * @param durationMs  How long the toast stays visible (default 3 000 ms).
 */
@Composable
fun BettyToast(
    data: ToastData,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    durationMs: Long = 3_000L,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    var visible by remember { mutableStateOf(false) }

    LaunchedEffect(data) {
        visible = true
        delay(durationMs)
        visible = false
        delay(300L)
        onDismiss()
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(200)) + slideInVertically(tween(200)) { it },
        exit = fadeOut(tween(200)) + slideOutVertically(tween(200)) { it },
        modifier = modifier.testTag("BettyToast_${data.kind.name}"),
    ) {
        val indicatorColor = when (data.kind) {
            ToastKind.SUCCESS -> colors.accentPositive
            ToastKind.INFO -> Palette.orange
            ToastKind.ERROR -> Palette.alertRed
        }
        // Single-character label inside the indicator dot (✓ / i / !)
        val indicatorChar = when (data.kind) {
            ToastKind.SUCCESS -> "✓"
            ToastKind.INFO -> "i"
            ToastKind.ERROR -> "!"
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .clip(Radius.sharp)
                .background(colors.surface)
                .padding(Space.s),
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(20.dp)
                    .clip(CircleShape)
                    .background(indicatorColor),
            ) {
                Text(
                    text = indicatorChar,
                    fontSize = 11.sp,
                    fontWeight = FontWeight(800),
                    color = if (data.kind == ToastKind.SUCCESS) Palette.ink else Color.White,
                )
            }
            Spacer(Modifier.width(Space.xs))
            Text(
                text = data.message,
                style = type.body,
                color = colors.textPrimary,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

/**
 * Toast host overlay. Place this as the top-most layer in your screen hierarchy (e.g.
 * inside a [BettyScaffold]). It stacks pending toasts at the bottom of the screen.
 *
 * The NotifyCenter state lives in your feature layer; pass its list here.
 *
 * @param toasts    Ordered list of pending toasts (most recent last).
 * @param onDismiss Called with the [ToastData] item that should be removed from the list.
 */
@Composable
fun ToastHost(
    toasts: List<ToastData>,
    onDismiss: (ToastData) -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        contentAlignment = Alignment.BottomCenter,
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = Space.screenEdge, vertical = Space.l)
            .testTag("ToastHost"),
    ) {
        toasts.forEach { toast ->
            BettyToast(
                data = toast,
                onDismiss = { onDismiss(toast) },
                modifier = Modifier.padding(bottom = Space.xs),
            )
        }
    }
}
