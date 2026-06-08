package social.betty.features.profile

import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import kotlinx.coroutines.launch
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.navigation.LocalAppContainer

/**
 * Web `/support`: "NEED A HAND?" header + email card (`hi@betty.social` mailto) +
 * feature-request form (`POST /feature-requests`, ≤5000 chars, trimmed payload, success
 * clears / failure keeps the text).
 */
@Composable
fun SupportScreen() {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    var description by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }

    fun submit() {
        if (!SupportFormLogic.canSubmit(description, isSubmitting)) return
        val trimmed = SupportFormLogic.trimmed(description)
        isSubmitting = true
        scope.launch {
            try {
                container.api.postFeatureRequest(trimmed)
                description = ""
                container.notify.success("Your idea is in. Betty appreciates it.")
            } catch (e: Exception) {
                container.notify.error("Couldn't send that just now. Try again in a moment?")
            } finally {
                isSubmitting = false
            }
        }
    }

    BettyScaffold(modifier = Modifier.testTag("support-screen")) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(Space.m)
                .padding(bottom = Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.grid),
        ) {
            // Hero
            Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
                KickerText(text = "★ NEED A HAND?", color = Palette.orange)
                Text(text = "GET IN", style = type.displayL, color = colors.textPrimary)
                Text(text = "TOUCH.", style = type.displayL, color = Palette.orange)
                Text(
                    text = "Bug reports, feature requests, smack-talk about the math — Betty's listening.",
                    style = type.body,
                    color = colors.textSecondary,
                )
            }

            // Email card
            InsetPanel(accent = Palette.orange) {
                Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                    KickerText(text = "★ EMAIL", color = Palette.orange)
                    Row(
                        modifier = Modifier.clickable {
                            runCatching {
                                context.startActivity(
                                    Intent(Intent.ACTION_SENDTO, "mailto:hi@betty.social".toUri()),
                                )
                            }
                        },
                        horizontalArrangement = Arrangement.spacedBy(Space.xs),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(text = "hi@betty.social", style = type.title3, color = colors.textPrimary)
                        Text(text = "→", style = type.title3, color = Palette.orange)
                    }
                }
            }

            // Feature-request card
            InsetPanel(accent = colors.accentPositive) {
                Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
                    KickerText(text = "● FEATURE REQUEST", color = colors.accentPositive)
                    Text(text = "PITCH BETTY AN IDEA.", style = type.title2, color = colors.textPrimary)
                    Text(
                        text = "Something missing? A bet type, a stat, a rule tweak — tell us. We read every one.",
                        style = type.body,
                        color = colors.textSecondary,
                    )

                    TextField(
                        value = description,
                        onValueChange = { description = SupportFormLogic.clamped(it) },
                        placeholder = {
                            Text(
                                text = "What would make Betty better?",
                                style = type.body,
                                color = colors.textMuted,
                            )
                        },
                        enabled = !isSubmitting,
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = colors.overlay06,
                            unfocusedContainerColor = colors.overlay06,
                            disabledContainerColor = colors.overlay06,
                            focusedTextColor = colors.textPrimary,
                            unfocusedTextColor = colors.textPrimary,
                            disabledTextColor = colors.textPrimary,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent,
                            disabledIndicatorColor = Color.Transparent,
                            cursorColor = colors.textPrimary,
                        ),
                        shape = Radius.sharp,
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 120.dp)
                            .testTag("support-input"),
                    )

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        // Plain string interpolation: web shows "5000 LEFT" (no grouping).
                        KickerText(
                            text = "${SupportFormLogic.remaining(description)} LEFT",
                            color = if (SupportFormLogic.warnsLowBudget(description)) {
                                Palette.orange
                            } else {
                                colors.textMuted
                            },
                        )
                        Spacer(Modifier.weight(1f))
                        BettyButton(
                            text = if (isSubmitting) "SENDING…" else "SEND IT →",
                            onClick = ::submit,
                            modifier = Modifier.testTag("support-submit"),
                            enabled = SupportFormLogic.canSubmit(description, isSubmitting),
                            loading = isSubmitting,
                        )
                    }
                }
            }

            KickerText(
                text = "LAST UPDATED · SEPTEMBER 24, 2022",
                color = colors.textMuted,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
