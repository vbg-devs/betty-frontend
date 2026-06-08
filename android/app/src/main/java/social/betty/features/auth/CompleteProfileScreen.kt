package social.betty.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import kotlinx.coroutines.launch
import social.betty.core.net.ApiError
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.Avatar
import social.betty.designsystem.components.AvatarSize
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalAppState

@Composable
fun CompleteProfileScreen() {
    val container = LocalAppContainer.current
    val appState = LocalAppState.current
    val scope = rememberCoroutineScope()

    val provider = container.sessionManager.providerProfile

    var name by remember { mutableStateOf(provider?.displayName.orEmpty()) }
    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Prefill name from the provider profile once on entry (mirrors iOS .task behavior).
    LaunchedEffect(Unit) {
        if (name.isEmpty()) {
            name = provider?.displayName.orEmpty()
        }
    }

    val canSave = name.trim().isNotEmpty()

    BettyScaffold(
        modifier = Modifier.testTag("complete-profile"),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(Space.m)
                .padding(bottom = Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.l),
        ) {
            Spacer(Modifier.height(Space.xl))

            KickerText(
                text = "★ ONE LAST STEP",
                color = Palette.orange,
            )

            Text(
                text = "COMPLETE YOUR PROFILE",
                style = BettyTheme.type.title1,
                color = BettyTheme.colors.textPrimary,
            )

            Text(
                text = "Pick a name your friends will recognize when you land in the standings.",
                style = BettyTheme.type.subhead,
                color = BettyTheme.colors.textSecondary,
            )

            // Avatar preview — shows provider photo or initials from the name being typed.
            Avatar(
                url = provider?.photoUrl,
                name = name.ifEmpty { provider?.displayName },
                size = AvatarSize.large,
                modifier = Modifier.align(Alignment.CenterHorizontally),
            )

            // Name field
            Column(
                verticalArrangement = Arrangement.spacedBy(Space.xs),
            ) {
                KickerText(
                    text = "YOUR NAME",
                    color = BettyTheme.colors.textMuted,
                )
                CompleteProfileTextField(
                    value = name,
                    onValueChange = { name = it },
                    placeholder = "Betty",
                    modifier = Modifier.testTag("complete-profile-name"),
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Text,
                        capitalization = KeyboardCapitalization.Words,
                    ),
                )
            }

            // Inline error
            errorMessage?.let { msg ->
                InsetPanel(accent = Palette.orange) {
                    Text(
                        text = msg,
                        style = BettyTheme.type.subhead,
                        color = BettyTheme.colors.textPrimary,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            BettyButton(
                text = if (isSaving) "SAVING…" else "SAVE PROFILE",
                onClick = {
                    val trimmed = name.trim()
                    errorMessage = null
                    isSaving = true
                    scope.launch {
                        try {
                            val email = provider?.email.orEmpty()
                            val imageUrl = provider?.photoUrl
                            // POST /user to create the profile.
                            container.api.createUser(email, trimmed, imageUrl)
                            // Re-fetch the canonical profile so the store + AppState are
                            // seeded with the server-assigned id and any normalizations.
                            val profile = container.api.getUserMe()
                            appState.onProfileCompleted(profile)
                        } catch (e: ApiError.Status) {
                            errorMessage = profileSaveErrorMessage(e.code)
                        } catch (e: Exception) {
                            errorMessage = "Couldn't save your profile. Please try again."
                        } finally {
                            isSaving = false
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("complete-profile-save"),
                enabled = !isSaving && canSave,
                loading = isSaving,
                block = true,
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Shared text-field (reuses the same visual treatment as AuthScreen)
// ---------------------------------------------------------------------------

@Composable
private fun CompleteProfileTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
) {
    val colors = BettyTheme.colors
    TextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = {
            Text(
                text = placeholder,
                style = BettyTheme.type.body,
                color = colors.textMuted,
            )
        },
        singleLine = true,
        keyboardOptions = keyboardOptions,
        colors = TextFieldDefaults.colors(
            focusedContainerColor = colors.overlay06,
            unfocusedContainerColor = colors.overlay06,
            focusedTextColor = colors.textPrimary,
            unfocusedTextColor = colors.textPrimary,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            cursorColor = colors.textPrimary,
        ),
        shape = Radius.sharp,
        modifier = modifier.fillMaxWidth(),
    )
}

// ---------------------------------------------------------------------------
// Error message mapping — mirrors iOS CompleteProfileView.message(for:)
// ---------------------------------------------------------------------------

internal fun profileSaveErrorMessage(httpCode: Int): String = when (httpCode) {
    401, 403 -> "Your session expired. Please sign in again."
    in 500..599 -> "Something went wrong on our end. We're looking into it — please try again in a moment."
    else -> "Couldn't save your profile. Please try again."
}
