package social.betty.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.BettyScaffold

/**
 * Placeholders for feature entry points until each feature screen is implemented. Each carries
 * the screen's stable test tag so the navigation shell + smoke tests are exercised before the
 * real UI lands. Feature implementations replace the body, keeping the function signature.
 */
@Composable
fun ScreenStub(tag: String, label: String) {
    BettyScaffold {
        Text(
            text = label,
            style = BettyTheme.type.title2.copy(color = BettyTheme.colors.textPrimary),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxSize().testTag(tag).padding(Space.xxl),
        )
    }
}

@Composable
fun SheetStub(tag: String, label: String, onDismiss: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().testTag(tag).padding(Space.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.l),
    ) {
        Text(label, style = BettyTheme.type.title2.copy(color = BettyTheme.colors.textPrimary))
        BettyButton(text = "Close", onClick = onDismiss, variant = BettyButtonVariant.OUTLINE)
    }
}
