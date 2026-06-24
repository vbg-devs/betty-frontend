package social.betty.features.join

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import social.betty.core.model.GroupPeek
import social.betty.core.net.ApiError
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.KickerText
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalNavigator

// ---------------------------------------------------------------------------
// Local phase + outcome types
// ---------------------------------------------------------------------------

private sealed interface Phase {
    data object Loading : Phase
    data class Preview(val peek: GroupPeek) : Phase
    data object PreviewError : Phase
}

/** Result of `POST /join/:code`, mirroring the iOS `JoinInviteOutcome`. */
private sealed interface JoinOutcome {
    data class Joined(val groupId: Int) : JoinOutcome
    data class AlreadyMember(val groupId: Int) : JoinOutcome
    data object InvalidInvite : JoinOutcome
    data object Blocked : JoinOutcome
    data object Failed : JoinOutcome
}

private fun mapJoinError(e: Throwable, fallbackGroupId: Int): JoinOutcome =
    when ((e as? ApiError)?.statusCode) {
        409 -> JoinOutcome.AlreadyMember(fallbackGroupId)
        404 -> JoinOutcome.InvalidInvite
        403 -> JoinOutcome.Blocked
        else -> JoinOutcome.Failed
    }

/**
 * The invite deep-link landing sheet (screens.md §3.6, components.md §4.3).
 *
 * Loads the group preview via GET /group/:code, then joins via POST /join/:code.
 * Called by the shell's SheetHost when Sheet.JoinInvite(code) is active.
 *
 * Column content only — the ModalBottomSheet wrapper is provided by SheetHost.
 */
@Composable
fun JoinInviteSheet(code: String, onDismiss: () -> Unit) {
    val container = LocalAppContainer.current
    val nav = LocalNavigator.current
    val scope = rememberCoroutineScope()

    var phase by remember { mutableStateOf<Phase>(Phase.Loading) }
    var isJoining by remember { mutableStateOf(false) }

    // Pending confirm dialog: holds the question text + the action to run on "Go there now?"
    var pendingConfirm by remember { mutableStateOf<Pair<String, () -> Unit>?>(null) }

    LaunchedEffect(code) {
        phase = try {
            Phase.Preview(container.api.getGroupByCode(code))
        } catch (_: Exception) {
            Phase.PreviewError
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("join-invite-sheet"),
    ) {
        when (val p = phase) {
            Phase.Loading -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = Space.xxl),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(
                        color = BettyTheme.colors.textPrimary,
                        modifier = Modifier.size(36.dp),
                    )
                }
            }

            is Phase.Preview -> {
                InvitePreview(
                    peek = p.peek,
                    isJoining = isJoining,
                    onDecline = onDismiss,
                    onAccept = {
                        isJoining = true
                        scope.launch {
                            val outcome = try {
                                val groupId = container.groupStore.joinByCode(code)
                                JoinOutcome.Joined(groupId)
                            } catch (e: Exception) {
                                mapJoinError(e, p.peek.id)
                            }
                            isJoining = false
                            when (outcome) {
                                is JoinOutcome.Joined -> {
                                    onDismiss()
                                    pendingConfirm = Pair(
                                        "You are now a proud member of ${p.peek.name}. Go there now?",
                                        { nav.openGroup(outcome.groupId) },
                                    )
                                }
                                is JoinOutcome.AlreadyMember -> {
                                    onDismiss()
                                    pendingConfirm = Pair(
                                        "It looks like you're already member of ${p.peek.name}. Go there now?",
                                        { nav.openGroup(outcome.groupId) },
                                    )
                                }
                                JoinOutcome.InvalidInvite ->
                                    container.notify.error("This invite link is invalid or has expired.")
                                JoinOutcome.Blocked ->
                                    container.notify.error("You have been blocked from ${p.peek.name}.")
                                JoinOutcome.Failed ->
                                    container.notify.critical("Something went wrong while joining the group. Please try again.")
                            }
                        }
                    },
                )
            }

            Phase.PreviewError -> {
                LoadError(
                    onGoToDashboard = {
                        onDismiss()
                        nav.selectTab(social.betty.navigation.Tab.HOME)
                    },
                )
            }
        }
    }

    // Post-join / already-member confirm dialog — rendered outside the phase Column so it
    // survives after onDismiss() clears the sheet (the dialog state is remembered here).
    pendingConfirm?.let { (question, goThere) ->
        AlertDialog(
            onDismissRequest = { pendingConfirm = null },
            title = {
                Text(
                    text = question,
                    style = BettyTheme.type.body,
                    color = BettyTheme.colors.textPrimary,
                    modifier = Modifier.testTag("join-confirm"),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    pendingConfirm = null
                    goThere()
                }) {
                    Text(
                        text = "GO THERE NOW",
                        style = BettyTheme.type.kicker,
                        color = Palette.orange,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingConfirm = null }) {
                    Text(
                        text = "STAY",
                        style = BettyTheme.type.kicker,
                        color = BettyTheme.colors.textMuted,
                    )
                }
            },
            containerColor = BettyTheme.colors.surface,
            titleContentColor = BettyTheme.colors.textPrimary,
        )
    }
}

// ---------------------------------------------------------------------------
// Invite preview (web JoinGroupModal)
// ---------------------------------------------------------------------------

@Composable
private fun InvitePreview(
    peek: GroupPeek,
    isJoining: Boolean,
    onDecline: () -> Unit,
    onAccept: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column {
        Column(
            modifier = Modifier
                .weight(1f, fill = false)
                .verticalScroll(rememberScrollState()),
        ) {
            // Header: 16:9 hero image with tournament icon overlay, or standalone round logo.
            val hasHeader = peek.headerImageUrl != null
            if (hasHeader) {
                HeroImage(
                    imageUrl = peek.headerImageUrl!!,
                    tournamentImageUrl = peek.tournamentImageUrl,
                )
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Space.l)
                    .padding(top = if (hasHeader) Space.m else Space.s),
                verticalArrangement = Arrangement.spacedBy(Space.xs),
            ) {
                // Large round tournament logo when no header image.
                if (!hasHeader && peek.tournamentImageUrl != null) {
                    RoundLogo(url = peek.tournamentImageUrl, size = 96.dp)
                    Spacer(Modifier.height(Space.s))
                }

                KickerText(text = "★ INVITED TO BET", color = Palette.orange)

                Text(
                    text = peek.name.uppercase(),
                    style = type.displayL,
                    color = colors.textPrimary,
                )

                if (!peek.tournamentName.isNullOrEmpty()) {
                    Text(
                        text = peek.tournamentName.uppercase(),
                        style = type.subhead,
                        color = colors.textSecondary,
                    )
                }

                // Description behind an orange left accent bar (components.md §4.3).
                // GroupPeek doesn't carry description — the field is absent in the wire model,
                // so this block is intentionally omitted. If the API is extended to include
                // description in GroupPeek, add it here via InsetPanel(accent = Palette.orange).

                Text(
                    text = "Lock in your bets every matchday, climb the standings, settle the banter.",
                    style = type.bodyRegular,
                    color = colors.textSecondary,
                )
            }
        }

        Divider(color = colors.overlay06)

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Space.m),
            horizontalArrangement = Arrangement.spacedBy(Space.xs),
        ) {
            BettyButton(
                text = "NO THANKS",
                onClick = onDecline,
                variant = BettyButtonVariant.GHOST,
                modifier = Modifier
                    .weight(1f)
                    .testTag("join-decline"),
                block = true,
            )
            BettyButton(
                text = if (isJoining) "PLACING…" else "I'M IN →",
                onClick = onAccept,
                variant = BettyButtonVariant.PRIMARY,
                enabled = !isJoining,
                loading = isJoining,
                modifier = Modifier
                    .weight(1f)
                    .testTag("join-confirm"),
                block = true,
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Hero image with optional tournament icon overlay
// ---------------------------------------------------------------------------

@Composable
private fun HeroImage(imageUrl: String, tournamentImageUrl: String?) {
    val colors = BettyTheme.colors
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
        // Fallback tint while image loads.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(colors.overlay04),
        )
        // Tournament logo overlaid bottom-start — offset downward so it bleeds into the
        // content below, matching the iOS `offset(y: 22)` treatment.
        if (tournamentImageUrl != null) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = Space.l)
                    .padding(bottom = (-22).dp),
            ) {
                RoundLogo(url = tournamentImageUrl, size = 56.dp)
            }
        }
    }
    // Compensate for the overlapping tournament logo.
    if (tournamentImageUrl != null) {
        Spacer(Modifier.height(22.dp))
    }
}

// ---------------------------------------------------------------------------
// Round logo (used both inline and as hero overlay)
// ---------------------------------------------------------------------------

@Composable
private fun RoundLogo(url: String, size: androidx.compose.ui.unit.Dp) {
    val colors = BettyTheme.colors
    AsyncImage(
        model = url,
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(colors.surface),
    )
}

// ---------------------------------------------------------------------------
// Preview fetch failure state
// ---------------------------------------------------------------------------

@Composable
private fun LoadError(onGoToDashboard: () -> Unit) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(Space.l)
            .testTag("join-error"),
        verticalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        KickerText(text = "★ INVITED TO BET", color = Palette.orange)

        Text(
            text = "COULD NOT LOAD THIS INVITE",
            style = type.title2,
            color = colors.textPrimary,
        )

        Text(
            text = "The invite link may be invalid or expired. Please check the link and try again.",
            style = type.bodyRegular,
            color = colors.textSecondary,
        )

        BettyButton(
            text = "GO TO DASHBOARD",
            onClick = onGoToDashboard,
            variant = BettyButtonVariant.OUTLINE,
        )

        Spacer(Modifier.height(Space.m))
    }
}
