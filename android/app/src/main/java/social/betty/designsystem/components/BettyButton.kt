package social.betty.designsystem.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius

enum class BettyButtonVariant {
    /** Orange bg / white heavy uppercase label — the main CTA. */
    PRIMARY,
    /** Transparent with a 1pt textPrimary@25% border. */
    OUTLINE,
    /** Bare text button — nav-level actions. */
    GHOST,
    /** Ink background, cream label — landing CTA. */
    DARK,
    /** Alert red — destructive actions. */
    DESTRUCTIVE,
}

/**
 * Betty design-system button.
 *
 * @param text     Button label (rendered uppercase by the style).
 * @param onClick  Click handler.
 * @param variant  Visual variant.
 * @param enabled  Disabled state renders at 0.4 opacity.
 * @param loading  Replaces label with a small white CircularProgressIndicator.
 * @param block    When true the button stretches to fill its container width (17 sp label).
 * @param modifier Passed through to the outer Box wrapper.
 */
@Composable
fun BettyButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: BettyButtonVariant = BettyButtonVariant.PRIMARY,
    enabled: Boolean = true,
    loading: Boolean = false,
    block: Boolean = false,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.98f else 1f,
        animationSpec = tween(durationMillis = 150),
        label = "buttonScale",
    )

    val backgroundColor = when (variant) {
        BettyButtonVariant.PRIMARY -> Palette.orange
        BettyButtonVariant.OUTLINE, BettyButtonVariant.GHOST -> Color.Transparent
        BettyButtonVariant.DARK -> Palette.ink
        BettyButtonVariant.DESTRUCTIVE -> Palette.alertRed
    }

    val contentColor = when (variant) {
        BettyButtonVariant.PRIMARY, BettyButtonVariant.DESTRUCTIVE -> Color.White
        BettyButtonVariant.OUTLINE, BettyButtonVariant.GHOST -> colors.textPrimary
        // Dark button always uses the dark-theme cream regardless of host theme.
        BettyButtonVariant.DARK -> Color(0xFFFFFAEB)
    }

    val horizontalPadding = when (variant) {
        BettyButtonVariant.GHOST -> 16.dp
        BettyButtonVariant.OUTLINE -> 24.dp
        BettyButtonVariant.DARK -> 32.dp
        else -> 22.dp
    }

    val verticalPadding = when (variant) {
        BettyButtonVariant.GHOST -> 10.dp
        else -> 17.dp
    }

    val labelStyle = when {
        block -> type.kicker.copy(fontSize = 17.sp)
        variant == BettyButtonVariant.DARK -> type.kicker.copy(fontSize = 17.sp)
        else -> type.kicker.copy(fontSize = 14.sp)
    }

    val border: BorderStroke? = if (variant == BettyButtonVariant.OUTLINE) {
        BorderStroke(1.dp, colors.textPrimary.copy(alpha = if (isPressed) 0.5f else 0.25f))
    } else null

    Box(
        modifier = modifier
            .then(if (block) Modifier.fillMaxWidth() else Modifier)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .testTag("BettyButton_${variant.name}"),
    ) {
        Button(
            onClick = onClick,
            enabled = enabled && !loading,
            shape = Radius.sharp,
            colors = ButtonDefaults.buttonColors(
                containerColor = backgroundColor,
                contentColor = contentColor,
                disabledContainerColor = backgroundColor.copy(alpha = 0.4f),
                disabledContentColor = contentColor.copy(alpha = 0.4f),
            ),
            border = border,
            contentPadding = PaddingValues(
                horizontal = horizontalPadding,
                vertical = verticalPadding,
            ),
            interactionSource = interactionSource,
            modifier = if (block) Modifier.fillMaxWidth() else Modifier,
        ) {
            if (loading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    color = contentColor,
                    strokeWidth = 2.dp,
                )
            } else {
                Text(
                    text = text.uppercase(),
                    style = labelStyle,
                    textAlign = if (block) TextAlign.Center else TextAlign.Start,
                )
            }
        }
    }
}
