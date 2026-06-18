package social.betty.features.groupdetail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.launch
import social.betty.core.net.ApiError
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.navigation.LocalAppContainer

private const val MAX_DESCRIPTION = 1000

/**
 * `.groupSettings` sheet (author only): welcome message, description (≤1000), winning /
 * exact points, sneak-peek toggle → `PUT /group/:id/settings`. Save is disabled until the
 * form is dirty + valid; 401/403 → author-only message (web pin).
 */
@Composable
fun GroupSettingsSheet(groupId: Int, onDismiss: () -> Unit) {
    val container = LocalAppContainer.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val scope = rememberCoroutineScope()

    val groups by container.groupStore.groups.collectAsStateWithLifecycle()
    val group = groups.firstOrNull { it.id == groupId }

    if (group == null) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.surface)
                .padding(Space.xl)
                .testTag("group-settings-sheet"),
            verticalArrangement = Arrangement.spacedBy(Space.m),
            horizontalAlignment = Alignment.Start,
        ) {
            Text("★ GROUP SETTINGS", style = type.kicker, color = Palette.orange)
            Text("This group is no longer available.", style = type.bodyRegular, color = colors.textSecondary)
            BettyButton(
                text = "Close",
                onClick = onDismiss,
                variant = social.betty.designsystem.components.BettyButtonVariant.OUTLINE,
            )
        }
        return
    }

    // Initial values (snapshot for dirty-checking).
    val initialWelcome = group.welcomeMessage.orEmpty()
    val initialDescription = group.description.orEmpty()
    val initialWin = group.correctTeamPoints.toString()
    val initialExact = group.exactResultPoints.toString()
    val initialPeek = group.allowSneakPeek
    val initialBoostCount = group.boostCount.toString()
    val initialBoostMultiplier = group.boostMultiplier.toString()

    var welcome by remember(groupId) { mutableStateOf(initialWelcome) }
    var description by remember(groupId) { mutableStateOf(initialDescription) }
    var winPoints by remember(groupId) { mutableStateOf(initialWin) }
    var exactPoints by remember(groupId) { mutableStateOf(initialExact) }
    var peek by remember(groupId) { mutableStateOf(initialPeek) }
    var boostCount by remember(groupId) { mutableStateOf(initialBoostCount) }
    var boostMultiplier by remember(groupId) { mutableStateOf(initialBoostMultiplier) }
    var isSaving by remember { mutableStateOf(false) }

    val isDirty = welcome != initialWelcome ||
        description != initialDescription ||
        winPoints != initialWin ||
        exactPoints != initialExact ||
        peek != initialPeek ||
        boostCount != initialBoostCount ||
        boostMultiplier != initialBoostMultiplier
    val parsedBoostCount = boostCount.toIntOrNull()
    val parsedBoostMultiplier = boostMultiplier.toIntOrNull()
    val isValid = winPoints.toIntOrNull() != null && exactPoints.toIntOrNull() != null &&
        description.length <= MAX_DESCRIPTION &&
        // Spec §1.1: boost_count ≥ 0, boost_multiplier ≥ 1.
        parsedBoostCount != null && parsedBoostCount >= 0 &&
        parsedBoostMultiplier != null && parsedBoostMultiplier >= 1
    val canSave = isDirty && isValid && !isSaving

    fun save() {
        val win = winPoints.toIntOrNull() ?: return
        val exact = exactPoints.toIntOrNull() ?: return
        val bc = parsedBoostCount ?: return
        val bm = parsedBoostMultiplier ?: return
        if (isSaving) return
        isSaving = true
        scope.launch {
            try {
                container.groupStore.updateSettings(
                    id = groupId,
                    welcomeMessage = welcome.ifBlank { null },
                    description = description.ifBlank { null },
                    correctTeamPoints = win,
                    exactResultPoints = exact,
                    allowSneakPeek = peek,
                    boostCount = bc,
                    boostMultiplier = bm,
                )
                container.notify.success("Settings saved.")
                isSaving = false
                onDismiss()
            } catch (e: ApiError.Status) {
                isSaving = false
                if (e.code == 401 || e.code == 403) {
                    container.notify.error("Only the group author can edit these settings.")
                } else {
                    container.notify.error("Something went wrong while saving. Please try again.")
                }
            } catch (e: ApiError) {
                isSaving = false
                container.notify.error("Something went wrong while saving. Please try again.")
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.surface)
            .heightIn(max = 620.dp)
            .verticalScroll(rememberScrollState())
            .padding(Space.l)
            .testTag("group-settings-sheet"),
        verticalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        Text("★ GROUP SETTINGS", style = type.kicker, color = Palette.orange)
        Text("EDIT GROUP.", style = type.title1, color = colors.textPrimary)
        Text(
            text = "Tune the welcome and the house rules. Only you, as the group author, can see this.",
            style = type.bodyRegular,
            color = colors.textSecondary,
        )

        SettingsField(label = "Welcome message") {
            BettyTextArea(
                value = welcome,
                onValueChange = { welcome = it },
                placeholder = "The smack-talk starts here…",
                tag = "group-settings-welcome",
            )
        }

        SettingsField(label = "Description") {
            BettyTextArea(
                value = description,
                onValueChange = { if (it.length <= MAX_DESCRIPTION) description = it },
                placeholder = "Shown on the public board. Pitch your group in a sentence or two…",
                tag = "group-settings-description",
            )
            Text(
                text = "${description.length} / $MAX_DESCRIPTION",
                style = type.micro,
                color = colors.textMuted,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(Space.s), modifier = Modifier.fillMaxWidth()) {
            SettingsField(label = "Winning team pts", modifier = Modifier.weight(1f)) {
                BettyNumberField(
                    value = winPoints,
                    onValueChange = { winPoints = it.filter { c -> c.isDigit() } },
                    placeholder = "2",
                    tag = "group-settings-win-points",
                )
            }
            SettingsField(label = "Exact score pts", modifier = Modifier.weight(1f)) {
                BettyNumberField(
                    value = exactPoints,
                    onValueChange = { exactPoints = it.filter { c -> c.isDigit() } },
                    placeholder = "4",
                    tag = "group-settings-exact-points",
                )
            }
        }

        // Boosters (spec §3.1). Count ≥ 0, multiplier ≥ 1. Multiplier disabled when count = 0.
        Row(horizontalArrangement = Arrangement.spacedBy(Space.s), modifier = Modifier.fillMaxWidth()) {
            SettingsField(label = "Boosters per user", modifier = Modifier.weight(1f)) {
                BettyNumberField(
                    value = boostCount,
                    onValueChange = { boostCount = it.filter { c -> c.isDigit() } },
                    placeholder = "0",
                    tag = "group-settings-boost-count",
                )
            }
            SettingsField(label = "Booster multiplier", modifier = Modifier.weight(1f)) {
                val countEnabled = (parsedBoostCount ?: 0) > 0
                BettyNumberField(
                    value = boostMultiplier,
                    onValueChange = { boostMultiplier = it.filter { c -> c.isDigit() } },
                    placeholder = "2",
                    tag = "group-settings-boost-multiplier",
                    enabled = countEnabled,
                )
            }
        }
        Text(
            text = "Members can apply a booster to multiply a single bet's points. Set count to 0 to disable.",
            style = type.bodyRegular.copy(fontSize = type.caption.fontSize),
            color = colors.textSecondary,
            modifier = Modifier.testTag("group-settings-boost-help"),
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Allow sneak peek", style = type.subhead, color = colors.textPrimary)
                Text(
                    text = "Members can see each other's bets before the game starts.",
                    style = type.bodyRegular.copy(fontSize = type.caption.fontSize),
                    color = colors.textSecondary,
                )
            }
            Switch(
                checked = peek,
                onCheckedChange = { peek = it },
                colors = SwitchDefaults.colors(checkedTrackColor = Palette.orange),
                modifier = Modifier.testTag("group-settings-sneak-peek"),
            )
        }

        BettyButton(
            text = if (isSaving) "Saving…" else "Save changes",
            onClick = { save() },
            enabled = canSave,
            loading = isSaving,
            block = true,
            modifier = Modifier.testTag("group-settings-save"),
        )
    }
}

@Composable
private fun SettingsField(label: String, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label.uppercase(), style = BettyTheme.type.kicker, color = BettyTheme.colors.textSecondary)
        content()
    }
}

@Composable
private fun BettyTextArea(value: String, onValueChange: (String) -> Unit, placeholder: String, tag: String) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.overlay06)
            .border(1.dp, colors.overlay10, Radius.sharp)
            .padding(Space.s),
    ) {
        if (value.isEmpty()) {
            Text(placeholder, style = type.bodyRegular, color = colors.textMuted)
        }
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = type.bodyRegular.copy(color = colors.textPrimary),
            cursorBrush = SolidColor(Palette.orange),
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 48.dp)
                .testTag(tag),
        )
    }
}

@Composable
private fun BettyNumberField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    tag: String,
    enabled: Boolean = true,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(if (enabled) colors.overlay06 else colors.overlay04)
            .border(1.dp, colors.overlay10, Radius.sharp)
            .padding(Space.s),
    ) {
        if (value.isEmpty()) {
            Text(placeholder, style = type.body, color = colors.textMuted)
        }
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            enabled = enabled,
            textStyle = type.body.copy(
                color = if (enabled) colors.textPrimary else colors.textMuted,
            ),
            cursorBrush = SolidColor(Palette.orange),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier
                .fillMaxWidth()
                .testTag(tag),
        )
    }
}
