package social.betty.features.creategroup

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import social.betty.app.AppConfig
import social.betty.core.model.Tournament
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.KickerText
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalNavigator

/**
 * Two-step create-group sheet (web `CreateGroupModal`, screens.md §3.5, components.md §4.2).
 *
 * Step 1: form with tournament picker, name, welcome message, description (≤1000),
 * winning-team points, exact-score points, sneak-peek toggle (default ON), public
 * toggle (default OFF). Create button disabled until name + both point fields non-empty
 * and a running tournament is selected.
 *
 * Step 2: success view with invite link (copy + share Intent) and "Go to group" CTA that
 * dismisses then navigates.
 *
 * The host wraps this composable in a ModalBottomSheet — we render only the column content.
 */
@Composable
fun CreateGroupSheet(onDismiss: () -> Unit) {
    val container = LocalAppContainer.current
    val nav = LocalNavigator.current
    val scope = rememberCoroutineScope()

    val tournaments by container.tournamentStore.tournaments.collectAsStateWithLifecycle()
    val groups by container.groupStore.groups.collectAsStateWithLifecycle()

    val form = remember { CreateGroupFormState() }
    var isCreating by remember { mutableStateOf(false) }

    // Null until the group is successfully created; switches to success step.
    var createdGroupId by remember { mutableStateOf<Int?>(null) }

    val running = container.tournamentStore.running()
    val createdGroup = createdGroupId?.let { id -> groups.firstOrNull { it.id == id } }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("create-group-sheet")
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Space.m, vertical = Space.m),
        verticalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        if (createdGroup != null) {
            // ── Step 2: success ──────────────────────────────────────────────────────
            SuccessStep(
                groupId = createdGroup.id,
                groupName = createdGroup.name,
                inviteCode = createdGroup.inviteCode,
                onGoToGroup = {
                    onDismiss()
                    nav.openGroup(createdGroup.id)
                },
            )
        } else {
            // ── Step 1: form ─────────────────────────────────────────────────────────
            KickerText(text = "★ NEW GROUP", color = Palette.orange)

            Text(
                text = "START A GROUP",
                style = BettyTheme.type.title1,
                color = BettyTheme.colors.textPrimary,
            )

            // Tournament picker
            FormField(label = "Tournament") {
                TournamentPicker(
                    running = running,
                    selectedId = form.tournamentId,
                    onSelect = { form.tournamentId = it },
                )
            }

            // Group name (required)
            FormField(label = "Group name") {
                BettyTextField(
                    value = form.name,
                    onValueChange = { form.name = it },
                    placeholder = "Sunday Roast XI",
                    modifier = Modifier.testTag("create-group-name"),
                )
            }

            // Welcome message (optional, multiline)
            FormField(label = "Welcome message") {
                BettyTextField(
                    value = form.welcomeMessage,
                    onValueChange = { form.welcomeMessage = it },
                    placeholder = "The smack-talk starts here…",
                    singleLine = false,
                    minLines = 2,
                    maxLines = 4,
                )
            }

            // Description (optional, ≤1000 chars)
            FormField(label = "Description") {
                BettyTextField(
                    value = form.description,
                    onValueChange = { new ->
                        // Hard cap at 1000 — mirror web onChange guard (components.md §4.2).
                        form.description =
                            if (new.length > MAX_DESCRIPTION_LENGTH)
                                new.take(MAX_DESCRIPTION_LENGTH)
                            else
                                new
                    },
                    placeholder = "Shown on the public board. Pitch your group in a sentence or two…",
                    singleLine = false,
                    minLines = 2,
                    maxLines = 5,
                )
                // Live N / 1000 counter; highlights when at the limit.
                Text(
                    text = "${form.description.length} / $MAX_DESCRIPTION_LENGTH",
                    style = BettyTheme.type.micro,
                    color = if (form.description.length >= MAX_DESCRIPTION_LENGTH)
                        Palette.orange
                    else
                        BettyTheme.colors.textMuted,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            // Points row — winning team & exact score side-by-side
            Row(horizontalArrangement = Arrangement.spacedBy(Space.s)) {
                FormField(label = "Winning team pts", modifier = Modifier.weight(1f)) {
                    BettyTextField(
                        value = form.winPoints,
                        onValueChange = { form.winPoints = it.filter { c -> c.isDigit() } },
                        placeholder = "2",
                        keyboardType = KeyboardType.Number,
                        modifier = Modifier.testTag("create-group-correct-points"),
                    )
                }
                FormField(label = "Exact score pts", modifier = Modifier.weight(1f)) {
                    BettyTextField(
                        value = form.exactPoints,
                        onValueChange = { form.exactPoints = it.filter { c -> c.isDigit() } },
                        placeholder = "4",
                        keyboardType = KeyboardType.Number,
                        modifier = Modifier.testTag("create-group-exact-points"),
                    )
                }
            }

            // Booster fields (Boosters spec §3.2). Defaults 0 / 2 — boosters OFF on new groups.
            Row(horizontalArrangement = Arrangement.spacedBy(Space.s)) {
                FormField(label = "Boosters per user", modifier = Modifier.weight(1f)) {
                    BettyTextField(
                        value = form.boostCount,
                        onValueChange = { form.boostCount = it.filter { c -> c.isDigit() } },
                        placeholder = "0",
                        keyboardType = KeyboardType.Number,
                        modifier = Modifier.testTag("create-group-boost-count"),
                    )
                }
                FormField(label = "Booster multiplier", modifier = Modifier.weight(1f)) {
                    val multiplierEnabled = (form.boostCount.toIntOrNull() ?: 0) > 0
                    BettyTextField(
                        value = form.boostMultiplier,
                        onValueChange = { form.boostMultiplier = it.filter { c -> c.isDigit() } },
                        placeholder = "2",
                        keyboardType = KeyboardType.Number,
                        enabled = multiplierEnabled,
                        modifier = Modifier.testTag("create-group-boost-multiplier"),
                    )
                }
            }
            Text(
                text = "Members can apply a booster to multiply a single bet's points. Set count to 0 to disable.",
                style = BettyTheme.type.bodyRegular.copy(fontSize = BettyTheme.type.caption.fontSize),
                color = BettyTheme.colors.textSecondary,
                modifier = Modifier.testTag("create-group-boost-help"),
            )

            // Sneak-peek toggle (default ON)
            CheckRow(
                title = "Allow sneak peek",
                subtitle = "Members can see each other's bets before the game starts.",
                checked = form.allowSneakPeek,
                onCheckedChange = { form.allowSneakPeek = it },
                modifier = Modifier.testTag("create-group-sneak"),
            )

            // Public toggle (default OFF)
            CheckRow(
                title = "Make this group public",
                subtitle = "Anyone can discover and bet in this group — no invite link needed.",
                checked = form.isPublic,
                onCheckedChange = { form.isPublic = it },
                modifier = Modifier.testTag("create-group-public"),
            )

            BettyButton(
                text = if (isCreating) "CREATING…" else "CREATE GROUP",
                onClick = {
                    val tournament = form.selectedTournament(running) ?: return@BettyButton
                    val win = form.winPoints.toIntOrNull() ?: return@BettyButton
                    val exact = form.exactPoints.toIntOrNull() ?: return@BettyButton
                    val trimmedDescription =
                        form.description.trim().takeIf { it.isNotEmpty() }

                    val boostCount = form.boostCount.toIntOrNull() ?: 0
                    val boostMultiplier = form.boostMultiplier.toIntOrNull() ?: 2
                    isCreating = true
                    scope.launch {
                        try {
                            val groupId = container.groupStore.create(
                                name = form.name,
                                tournamentId = tournament.id,
                                correctTeamPoints = win,
                                exactResultPoints = exact,
                                allowSneakPeek = form.allowSneakPeek,
                                groupPlayDeadline = tournament.startDate,
                                welcomeMessage = form.welcomeMessage.takeIf { it.isNotEmpty() },
                                description = trimmedDescription,
                                isPublic = form.isPublic,
                                boostCount = boostCount,
                                boostMultiplier = boostMultiplier,
                            )
                            // Reload so byId() can find the new group.
                            container.groupStore.load()
                            createdGroupId = groupId
                        } catch (e: Exception) {
                            container.notify.error("Could not create group. Please try again.")
                        } finally {
                            isCreating = false
                        }
                    }
                },
                enabled = !isCreating && form.canSave(running),
                loading = isCreating,
                block = true,
                modifier = Modifier.testTag("create-group-submit"),
            )

            Spacer(Modifier.height(Space.m))
        }
    }
}

// ── Step 2 — success ─────────────────────────────────────────────────────────────────────

@Composable
private fun SuccessStep(
    groupId: Int,
    groupName: String,
    inviteCode: String,
    onGoToGroup: () -> Unit,
) {
    val inviteLink = AppConfig.INVITE_LINK_PREFIX + inviteCode

    KickerText(text = "★ YOU NAILED IT", color = Palette.orange)

    Text(
        text = "GROUP CREATED.",
        style = BettyTheme.type.title1,
        color = BettyTheme.colors.textPrimary,
    )

    // "GroupName is live. Share the link below…"
    Text(
        text = "$groupName is live. Share the link below to drag your friends in.",
        style = BettyTheme.type.bodyRegular,
        color = BettyTheme.colors.textSecondary,
    )

    KickerText(
        text = "★ INVITE LINK",
        color = BettyTheme.colors.textSecondary,
        modifier = Modifier.padding(top = Space.xs),
    )

    InviteLinkRow(
        link = inviteLink,
        modifier = Modifier.testTag("create-group-invite"),
    )

    BettyButton(
        text = "GO TO GROUP →",
        onClick = onGoToGroup,
        block = true,
        modifier = Modifier
            .padding(top = Space.s)
            .testTag("create-group-go"),
    )

    Spacer(Modifier.height(Space.m))
}

// ── Local design components ──────────────────────────────────────────────────────────────

/** Kicker-labelled form field wrapper. */
@Composable
private fun FormField(
    label: String,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        Text(
            text = label.uppercase(),
            style = BettyTheme.type.kicker,
            color = BettyTheme.colors.textSecondary,
        )
        content()
    }
}

/** Betty text input with overlay06 background and sharp corners. */
@Composable
private fun BettyTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
    minLines: Int = 1,
    maxLines: Int = 1,
    keyboardType: KeyboardType = KeyboardType.Text,
    enabled: Boolean = true,
) {
    val colors = BettyTheme.colors
    TextField(
        value = value,
        onValueChange = onValueChange,
        enabled = enabled,
        placeholder = {
            Text(
                placeholder,
                style = BettyTheme.type.body,
                color = colors.textMuted,
                overflow = TextOverflow.Ellipsis,
                maxLines = 1,
            )
        },
        singleLine = singleLine,
        minLines = minLines,
        maxLines = if (singleLine) 1 else maxLines,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        textStyle = BettyTheme.type.body.copy(color = colors.textPrimary),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = colors.overlay06,
            unfocusedContainerColor = colors.overlay06,
            disabledContainerColor = colors.overlay04,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            disabledIndicatorColor = Color.Transparent,
            focusedTextColor = colors.textPrimary,
            unfocusedTextColor = colors.textPrimary,
            disabledTextColor = colors.textMuted,
        ),
        shape = Radius.sharp,
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, colors.overlay10, Radius.sharp),
    )
}

/** Tournament dropdown (Menu-style, web analogue to the iOS `Menu` picker). */
@Composable
private fun TournamentPicker(
    running: List<Tournament>,
    selectedId: Int?,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    val selected = selectedId?.let { id -> running.firstOrNull { it.id == id } }
    val colors = BettyTheme.colors

    Box(modifier = modifier) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.overlay06, Radius.sharp)
                .border(1.dp, colors.overlay10, Radius.sharp)
                .clickable { expanded = true }
                .padding(Space.s)
                .testTag("create-group-tournament"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = selected?.name ?: "Select tournament",
                style = BettyTheme.type.body,
                color = if (selected == null) colors.textMuted else colors.textPrimary,
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Icon(
                imageVector = Icons.Default.ArrowDropDown,
                contentDescription = null,
                tint = colors.textSecondary,
            )
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            running.forEach { tournament ->
                DropdownMenuItem(
                    text = {
                        Text(
                            tournament.name,
                            style = BettyTheme.type.body,
                            color = colors.textPrimary,
                        )
                    },
                    onClick = {
                        onSelect(tournament.id)
                        expanded = false
                    },
                )
            }
        }
    }
}

/** Checkbox row with title + subtitle copy (web `.check`, iOS `GroupFormCheckRow`). */
@Composable
private fun CheckRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.overlay04, Radius.sharp)
            .border(1.dp, colors.overlay08, Radius.sharp)
            .padding(Space.s),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = Space.s)) {
            Text(
                text = title,
                style = BettyTheme.type.subhead,
                color = colors.textPrimary,
            )
            Text(
                text = subtitle,
                style = BettyTheme.type.bodyRegular,
                color = colors.textSecondary,
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Palette.orange,
                uncheckedThumbColor = colors.textMuted,
                uncheckedTrackColor = colors.overlay08,
            ),
        )
    }
}

/**
 * Invite-link row — truncated link text, COPY button (label flips to "COPIED ✓" for 1.5 s),
 * and an Android share Intent.
 */
@Composable
private fun InviteLinkRow(link: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    val scope = rememberCoroutineScope()
    var copied by remember { mutableStateOf(false) }
    val colors = BettyTheme.colors

    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.overlay06, Radius.sharp)
            .border(1.dp, colors.overlay10, Radius.sharp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Link text
        Text(
            text = link,
            style = BettyTheme.type.caption,
            color = colors.textSecondary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = Space.s, vertical = Space.s),
        )

        // Copy button
        Box(
            modifier = Modifier
                .background(Palette.orange)
                .clickable {
                    clipboardManager.setText(AnnotatedString(link))
                    copied = true
                    scope.launch {
                        delay(1_500)
                        copied = false
                    }
                }
                .padding(horizontal = Space.m, vertical = Space.s),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = if (copied) "COPIED ✓" else "COPY →",
                style = BettyTheme.type.kicker,
                color = Color.White,
            )
        }

        // Share button — Android share Intent
        Box(
            modifier = Modifier
                .background(Palette.ink)
                .clickable {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, link)
                    }
                    context.startActivity(Intent.createChooser(intent, null))
                }
                .padding(horizontal = Space.s, vertical = Space.s),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "↑",
                style = BettyTheme.type.headline,
                color = Color.White,
            )
        }
    }
}
