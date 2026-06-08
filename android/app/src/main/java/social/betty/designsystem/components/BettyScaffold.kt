package social.betty.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Space

/**
 * Minimal screen wrapper: fills `colors.background`, applies system bars WindowInsets so
 * content is not obscured by the status / navigation bar.
 *
 * @param content Screen content.
 */
@Composable
fun BettyScaffold(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val colors = BettyTheme.colors
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(colors.background)
            .windowInsetsPadding(WindowInsets.systemBars)
            .testTag("BettyScaffold"),
    ) {
        content()
    }
}

/**
 * Empty-state layout used across many screens: kicker, title, body message, optional CTA.
 *
 * Design matches ScreenPlaceholder on iOS (kicker orange, title displayL black uppercase,
 * message in textBody, optional orange primary button).
 *
 * @param title    Heading text — rendered uppercase in displayL.
 * @param message  Body copy in textBody.
 * @param ctaText  When non-null, a primary [BettyButton] is shown below the message.
 * @param onCta    Click handler for the CTA button.
 */
@Composable
fun EmptyState(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    ctaText: String? = null,
    onCta: (() -> Unit)? = null,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(Space.m)
            .testTag("EmptyState"),
        horizontalAlignment = Alignment.Start,
    ) {
        KickerText(
            text = "Betty",
            color = Palette.orange,
        )
        Spacer(Modifier.height(Space.xs))
        Text(
            text = title.uppercase(),
            style = type.displayL,
            color = colors.textPrimary,
        )
        Spacer(Modifier.height(Space.s))
        Text(
            text = message,
            style = type.bodyRegular,
            color = colors.textBody,
        )
        if (ctaText != null && onCta != null) {
            Spacer(Modifier.height(Space.l))
            BettyButton(
                text = ctaText,
                onClick = onCta,
                variant = BettyButtonVariant.PRIMARY,
            )
        }
    }
}
