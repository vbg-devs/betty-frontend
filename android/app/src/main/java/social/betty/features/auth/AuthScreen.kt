package social.betty.features.auth

import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.core.net.toUri
import kotlinx.coroutines.launch
import social.betty.core.auth.AuthException
import social.betty.core.auth.GoogleOAuth
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.SurfaceCard
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalAppState

@Composable
fun AuthScreen() {
    val container = LocalAppContainer.current
    val appState = LocalAppState.current
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isSignUpMode by remember { mutableStateOf(false) }
    var showEmailForm by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isBusy by remember { mutableStateOf(false) }

    val copy = AuthCopy.forMode(isSignUpMode)

    fun runAuth(operation: suspend () -> Unit) {
        errorMessage = null
        isBusy = true
        scope.launch {
            try {
                operation()
                appState.onInteractiveSignIn()
            } catch (e: AuthException) {
                errorMessage = e.friendlyMessage
            } catch (e: Exception) {
                errorMessage = "Something went wrong. Please try again."
            } finally {
                isBusy = false
            }
        }
    }

    BettyScaffold(
        modifier = Modifier.testTag("auth-screen"),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(Space.m)
                .padding(bottom = Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.xl),
        ) {
            AuthHero()
            AuthValueProps()
            SurfaceCard {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(Space.m),
                ) {
                    KickerText(
                        text = copy.pitchKicker,
                        color = Palette.orange,
                    )
                    Text(
                        text = copy.pitchTitle,
                        style = BettyTheme.type.title2,
                        color = BettyTheme.colors.textPrimary,
                    )

                    // Google sign-in: PKCE in a Custom Tab; the reversed-client-id redirect
                    // re-enters MainActivity, which completes it via GoogleSignInCoordinator.
                    BettyButton(
                        text = copy.googleTitle,
                        onClick = {
                            errorMessage = null
                            val pending = GoogleOAuth.begin(social.betty.app.AppConfig.GOOGLE_OAUTH_CLIENT_ID)
                            social.betty.app.GoogleSignInCoordinator.begin(pending)
                            runCatching {
                                CustomTabsIntent.Builder().build()
                                    .launchUrl(context, pending.authUrl.toUri())
                            }.onFailure {
                                errorMessage = "Could not open Google sign-in. Please use email."
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("auth-google"),
                        variant = BettyButtonVariant.OUTLINE,
                        enabled = !isBusy,
                        block = true,
                    )

                    // Apple sign-in — not available on Android; stub with a notice.
                    BettyButton(
                        text = copy.appleTitle,
                        onClick = {
                            container.notify.info("Apple sign-in coming soon")
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("auth-apple"),
                        variant = BettyButtonVariant.OUTLINE,
                        enabled = !isBusy,
                        block = true,
                    )

                    // Email toggle / expanded form
                    AnimatedVisibility(
                        visible = showEmailForm,
                        enter = expandVertically(),
                        exit = shrinkVertically(),
                    ) {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            verticalArrangement = Arrangement.spacedBy(Space.s),
                        ) {
                            AuthTextField(
                                value = email,
                                onValueChange = { email = it },
                                placeholder = "Email",
                                modifier = Modifier.testTag("auth-email-field"),
                                keyboardOptions = KeyboardOptions(
                                    keyboardType = KeyboardType.Email,
                                    imeAction = ImeAction.Next,
                                ),
                            )
                            AuthTextField(
                                value = password,
                                onValueChange = { password = it },
                                placeholder = "Password",
                                isPassword = true,
                                modifier = Modifier.testTag("auth-password-field"),
                                keyboardOptions = KeyboardOptions(
                                    keyboardType = KeyboardType.Password,
                                    imeAction = ImeAction.Done,
                                ),
                                keyboardActions = KeyboardActions(
                                    onDone = {
                                        if (!isBusy && email.isNotEmpty() && password.isNotEmpty()) {
                                            val trimmed = email.trim()
                                            runAuth {
                                                val session = if (isSignUpMode) {
                                                    container.authClient.signUp(trimmed, password)
                                                } else {
                                                    container.authClient.signInWithPassword(trimmed, password)
                                                }
                                                container.sessionManager.signIn(session)
                                            }
                                        }
                                    }
                                ),
                            )
                            BettyButton(
                                text = copy.submitTitle,
                                onClick = {
                                    val trimmed = email.trim()
                                    val validation = emailValidationMessage(trimmed, password, isSignUpMode)
                                    if (validation != null) {
                                        errorMessage = validation
                                        return@BettyButton
                                    }
                                    runAuth {
                                        val session = if (isSignUpMode) {
                                            container.authClient.signUp(trimmed, password)
                                        } else {
                                            container.authClient.signInWithPassword(trimmed, password)
                                        }
                                        container.sessionManager.signIn(session)
                                    }
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("auth-submit"),
                                enabled = !isBusy && email.isNotEmpty() && password.isNotEmpty(),
                                loading = isBusy,
                                block = true,
                            )
                        }
                    }

                    if (!showEmailForm) {
                        BettyButton(
                            text = copy.emailTitle,
                            onClick = { showEmailForm = true },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("auth-email-toggle"),
                            variant = BettyButtonVariant.OUTLINE,
                            enabled = !isBusy,
                            block = true,
                        )
                    }

                    // Inline error panel
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

                    // Sign-in / sign-up mode toggle
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(Space.xxs),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = copy.togglePrompt,
                            style = BettyTheme.type.subhead,
                            color = BettyTheme.colors.textSecondary,
                        )
                        BettyButton(
                            text = copy.toggleAction,
                            onClick = {
                                isSignUpMode = !isSignUpMode
                                errorMessage = null
                            },
                            modifier = Modifier.testTag("auth-mode-toggle"),
                            variant = BettyButtonVariant.GHOST,
                            enabled = !isBusy,
                        )
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Hero + value props
// ---------------------------------------------------------------------------

@Composable
private fun AuthHero() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        Spacer(Modifier.height(Space.xl))
        // Wordmark: the Betty logo is expressed as styled text (no image asset
        // in the Android project yet — mirrors the web fallback).
        Text(
            text = "betty",
            style = type.displayL,
            color = colors.textPrimary,
        )
        KickerText(
            text = "★ Home for bragging rights",
            color = Palette.orange,
        )
        Text(
            text = "Betty handles the math, you handle the banter.",
            style = type.bodyRegular,
            color = colors.textSecondary,
            textAlign = TextAlign.Start,
        )
    }
}

@Composable
private fun AuthValueProps() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    InsetPanel {
        Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
            KickerText(text = "A social predictions game", color = colors.textMuted)
            listOf(
                "Free forever." to "No paywalls, no ads, no nonsense.",
                "Your house rules." to "Each group sets its own scoring.",
                "Receipts forever." to "Leaderboards remember every call.",
            ).forEach { (lead, detail) ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    Text(
                        text = "★",
                        style = type.caption,
                        color = Palette.orange,
                    )
                    Text(
                        buildAnnotatedStringBold(lead, detail, colors.textPrimary, colors.textSecondary),
                        style = type.subhead,
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Shared text-field
// ---------------------------------------------------------------------------

@Composable
private fun AuthTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    isPassword: Boolean = false,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
) {
    val colors = BettyTheme.colors
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = {
            Text(
                text = placeholder,
                style = BettyTheme.type.body,
                color = colors.textMuted,
            )
        },
        visualTransformation = if (isPassword) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedContainerColor = colors.overlay06,
            unfocusedContainerColor = colors.overlay06,
            focusedTextColor = colors.textPrimary,
            unfocusedTextColor = colors.textPrimary,
            focusedBorderColor = Palette.orange,
            unfocusedBorderColor = colors.overlay10,
            cursorColor = colors.textPrimary,
        ),
        shape = social.betty.designsystem.Radius.sharp,
        modifier = modifier.fillMaxWidth(),
    )
}

// ---------------------------------------------------------------------------
// Copy object
// ---------------------------------------------------------------------------

private data class AuthCopy(
    val pitchKicker: String,
    val pitchTitle: String,
    val googleTitle: String,
    val appleTitle: String,
    val emailTitle: String,
    val submitTitle: String,
    val togglePrompt: String,
    val toggleAction: String,
) {
    companion object {
        fun forMode(isSignUp: Boolean): AuthCopy = if (isSignUp) {
            AuthCopy(
                pitchKicker = "★ NEW HERE?",
                pitchTitle = "Create account",
                googleTitle = "SIGN UP WITH GOOGLE",
                appleTitle = "SIGN UP WITH APPLE",
                emailTitle = "SIGN UP WITH EMAIL",
                submitTitle = "CREATE ACCOUNT →",
                togglePrompt = "Already have an account?",
                toggleAction = "Log in",
            )
        } else {
            AuthCopy(
                pitchKicker = "★ WELCOME BACK",
                pitchTitle = "Sign in",
                googleTitle = "CONTINUE WITH GOOGLE",
                appleTitle = "CONTINUE WITH APPLE",
                emailTitle = "CONTINUE WITH EMAIL",
                submitTitle = "SIGN IN →",
                togglePrompt = "Don't have an account?",
                toggleAction = "Create one",
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/**
 * Pre-flight form validation matching iOS parity. Returns an error message or null when
 * the form may be submitted. Sign-up enforces a 6-char minimum (mirrors Firebase rule);
 * sign-in defers to the server so old accounts without the rule can still sign in.
 */
internal fun emailValidationMessage(email: String, password: String, isSignUp: Boolean): String? {
    if (!isPlausibleEmail(email)) return "Enter a valid email address."
    if (password.isEmpty()) return "Enter your password."
    if (isSignUp && password.length < 6) return "Password should be at least 6 characters."
    return null
}

internal fun isPlausibleEmail(email: String): Boolean {
    if (email.isEmpty() || email.contains(" ")) return false
    val parts = email.split("@")
    if (parts.size != 2 || parts[0].isEmpty()) return false
    val domain = parts[1]
    return domain.contains(".") && !domain.startsWith(".") && !domain.endsWith(".")
}

// ---------------------------------------------------------------------------
// AnnotatedString helper for bold lead + regular detail in a single Text
// ---------------------------------------------------------------------------

private fun buildAnnotatedStringBold(
    lead: String,
    detail: String,
    leadColor: androidx.compose.ui.graphics.Color,
    detailColor: androidx.compose.ui.graphics.Color,
): androidx.compose.ui.text.AnnotatedString {
    return androidx.compose.ui.text.buildAnnotatedString {
        pushStyle(
            androidx.compose.ui.text.SpanStyle(
                color = leadColor,
                fontWeight = androidx.compose.ui.text.font.FontWeight.ExtraBold,
            )
        )
        append("$lead ")
        pop()
        pushStyle(androidx.compose.ui.text.SpanStyle(color = detailColor))
        append(detail)
        pop()
    }
}
