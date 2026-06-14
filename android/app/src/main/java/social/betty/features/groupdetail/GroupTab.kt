package social.betty.features.groupdetail

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.text.BasicTextField
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import android.content.Intent
import kotlinx.coroutines.launch
import social.betty.app.AppConfig
import social.betty.core.logic.RankedMember
import social.betty.core.model.Bet
import social.betty.core.model.Game
import social.betty.core.model.Group
import social.betty.core.model.GroupMessage
import social.betty.core.model.MessageReaction
import social.betty.core.model.Team
import social.betty.core.net.ApiError
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.Avatar
import social.betty.designsystem.components.AvatarSize
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.navigation.LocalAppContainer
import java.time.Instant

/**
 * The Group tab content emitted into the screen's [LazyColumn]: welcome/description,
 * ended-podium or running NeedAction strip, MemeBoard chat, and the stacked sidebar cards
 * (TOP 3, INVITE LINK, YOUR NICKNAME, GROUP ROSTER, VISIBILITY, HOUSE RULES, Leave).
 */
fun LazyListScope.groupTab(
    group: Group,
    tournamentEnded: Boolean,
    ranked: List<RankedMember>,
    allGames: List<Game>,
    bets: List<Bet>,
    messages: List<GroupMessage>,
    myId: String?,
    isAuthor: Boolean,
    teamBy: (Int) -> Team?,
    now: Instant,
    onSeeLeaderboard: () -> Unit,
    onOpenBet: (Int) -> Unit,
    onOpenHistory: (String) -> Unit,
    onOpenSettings: () -> Unit,
) {
    item(key = "welcome") { WelcomeCard(group) }

    if (tournamentEnded) {
        item(key = "podium") { PodiumCard(group, ranked, myId, onSeeLeaderboard, onOpenHistory) }
    } else {
        item(key = "need-action") {
            NeedActionStrip(allGames, bets, myId, teamBy, now, onOpenBet)
        }
        item(key = "top3") {
            SideCard("★ TOP 3") {
                GroupTopThree(group.members) { onOpenHistory(it.userId) }
            }
        }
        item(key = "invite") { InviteCard(group) }
    }

    item(key = "chat") {
        ChatCard(group, messages, myId)
    }

    if (!tournamentEnded) {
        item(key = "nickname") { NicknameCard(group, myId) }
    }
    item(key = "roster") { RosterCard(group, ranked, onSeeLeaderboard, onOpenHistory) }
    if (!tournamentEnded) {
        item(key = "visibility") { VisibilityCard(group) }
    }
    item(key = "house-rules") { HouseRulesCard(group, isAuthor, onOpenSettings) }
    item(key = "leave") { LeaveButton(group) }
}

@Composable
private fun WelcomeCard(group: Group) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val welcome = group.welcomeMessage
    val description = group.description
    if (!welcome.isNullOrEmpty()) {
        AccentPanel(accent = Palette.orange) {
            Text("★ WELCOME", style = type.kicker, color = Palette.orange)
            Text(welcome, style = type.title3.copy(fontSize = type.title3.fontSize), color = colors.textPrimary)
            if (!description.isNullOrEmpty()) {
                Text(description, style = type.body, color = colors.textSecondary)
            }
        }
    } else if (!description.isNullOrEmpty()) {
        AccentPanel(accent = colors.overlay10) {
            Text("★ ABOUT THIS GROUP", style = type.kicker, color = colors.textSecondary)
            Text(description, style = type.body, color = colors.textSecondary)
        }
    }
}

@Composable
private fun PodiumCard(
    group: Group,
    ranked: List<RankedMember>,
    myId: String?,
    onSeeLeaderboard: () -> Unit,
    onOpenHistory: (String) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val youWon = social.betty.core.logic.Ranking.youWon(ranked, myId)
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("★ FINAL PODIUM", style = type.kicker, color = Palette.orange)
                Text(
                    text = if (youWon) "YOU TOOK IT." else "CHAMPION CROWNED.",
                    style = type.title2,
                    color = colors.textPrimary,
                )
            }
            GroupPodium(group.members) { onOpenHistory(it.userId) }
            BettyButton(
                text = "See full leaderboard →",
                onClick = onSeeLeaderboard,
                variant = BettyButtonVariant.GHOST,
            )
        }
    }
}

@Composable
private fun NeedActionStrip(
    allGames: List<Game>,
    bets: List<Bet>,
    myId: String?,
    teamBy: (Int) -> Team?,
    now: Instant,
    onOpenBet: (Int) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val display = NeedAction.display(allGames, bets, myId, now)
    val (accent, header, headerColor, games) = when (display) {
        is NeedAction.Display.Urgent -> NeedActionView(
            Palette.yellow,
            "Make sure to bet on these games before it's too late!",
            Palette.yellow,
            display.games,
        )
        is NeedAction.Display.Today -> NeedActionView(
            colors.overlay10,
            "Todays games",
            colors.textMuted,
            display.games,
        )
        NeedAction.Display.Hidden -> return
    }

    AccentPanel(accent = accent) {
        Text(
            text = "★ ${header.uppercase()}",
            style = type.kicker,
            color = headerColor,
        )
        games.forEach { game ->
            val ownBet = firstOwnBet(bets, game.id, myId)
            GroupGameCard(
                game = game,
                homeTeam = teamBy(game.homeTeamId),
                awayTeam = teamBy(game.awayTeamId),
                betted = ownBet != null,
                placedHome = ownBet?.homeTeamScore ?: 0,
                placedAway = ownBet?.awayTeamScore ?: 0,
                awardedPoints = GroupGameCardLogic.awardedPoints(game, bets, myId),
                awardedBoosted = GroupGameCardLogic.awardedBoosted(game, bets, myId),
                betCount = betCount(bets, game.id),
                onTap = { onOpenBet(game.id) },
                now = now,
            )
        }
    }
}

private data class NeedActionView(
    val accent: Color,
    val header: String,
    val headerColor: Color,
    val games: List<Game>,
)

@Composable
private fun InviteCard(group: Group) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    var copied by remember { mutableStateOf(false) }
    val link = AppConfig.INVITE_LINK_PREFIX + group.inviteCode

    SideCard("★ INVITE LINK") {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.xs)) {
            Text(
                text = link,
                style = type.caption,
                color = colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .weight(1f)
                    .clip(Radius.sharp)
                    .background(colors.overlay06)
                    .padding(Space.s),
            )
            BettyButton(
                text = if (copied) "Copied ✓" else "Copy →",
                onClick = {
                    clipboard.setText(AnnotatedString(link))
                    copied = true
                },
                modifier = Modifier.testTag("group-invite-copy"),
            )
            Text(
                text = "⤴",
                style = type.title3,
                color = Palette.orange,
                modifier = Modifier
                    .clickable {
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            this.type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, link)
                        }
                        context.startActivity(Intent.createChooser(intent, "Share invite"))
                    }
                    .padding(Space.xs)
                    .testTag("group-invite-share"),
            )
        }
    }
}

@Composable
private fun NicknameCard(group: Group, myId: String?) {
    val container = LocalAppContainer.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val scope = rememberCoroutineScope()
    val initial = group.members.firstOrNull { it.userId == myId }?.nickname.orEmpty()
    var draft by remember(group.id) { mutableStateOf(initial) }
    var isSaving by remember { mutableStateOf(false) }

    SideCard("★ YOUR NICKNAME") {
        Text(
            text = "How your name shows in this group. Leave empty to use your real name.",
            style = type.bodyRegular.copy(fontSize = type.caption.fontSize),
            color = colors.textSecondary,
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.xs)) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(Radius.sharp)
                    .background(colors.overlay06)
                    .padding(Space.s),
            ) {
                if (draft.isEmpty()) {
                    Text("Your nickname", style = type.body, color = colors.textMuted)
                }
                BasicTextField(
                    value = draft,
                    onValueChange = { if (it.length <= 120) draft = it },
                    singleLine = true,
                    textStyle = type.body.copy(color = colors.textPrimary),
                    cursorBrush = SolidColor(Palette.orange),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("group-nickname-field"),
                )
            }
            BettyButton(
                text = if (isSaving) "Saving…" else "Save",
                onClick = onClick@{
                    if (isSaving) return@onClick
                    val trimmed = draft.trim()
                    isSaving = true
                    scope.launch {
                        try {
                            container.groupStore.setNickname(group.id, trimmed.ifEmpty { null })
                            container.notify.success(if (trimmed.isEmpty()) "Nickname cleared." else "Nickname updated.")
                        } catch (e: ApiError) {
                            container.notify.error("Could not update nickname. Please try again.")
                        }
                        isSaving = false
                    }
                },
                enabled = !isSaving,
                loading = isSaving,
                modifier = Modifier.testTag("group-nickname-save"),
            )
        }
    }
}

@Composable
private fun RosterCard(
    group: Group,
    ranked: List<RankedMember>,
    onSeeLeaderboard: () -> Unit,
    onOpenHistory: (String) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val limit = 6
    val visible = ranked.take(limit)
    SideCard("★ GROUP ROSTER") {
        Text(
            text = "${group.members.size} ${if (group.members.size == 1) "FRIEND" else "FRIENDS"}. ONE CHAMPION.",
            style = type.title3,
            color = colors.textPrimary,
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.fillMaxWidth()) {
            visible.forEach { entry ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenHistory(entry.userId) }
                        .padding(vertical = 8.dp, horizontal = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Space.s),
                ) {
                    Text(
                        text = "#${entry.place}",
                        style = type.subhead,
                        color = colors.textSecondary,
                        modifier = Modifier.width(32.dp),
                    )
                    Avatar(url = entry.member.imageUrl, name = entry.member.displayName(), size = AvatarSize.small)
                    Text(
                        text = entry.member.displayName(),
                        style = type.subhead,
                        color = colors.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    Text("${entry.member.score}p", style = type.subhead, color = colors.textSecondary)
                }
            }
        }
        if (ranked.size > limit) {
            BettyButton(
                text = "See all ${ranked.size} →",
                onClick = onSeeLeaderboard,
                variant = BettyButtonVariant.GHOST,
            )
        }
    }
}

@Composable
private fun VisibilityCard(group: Group) {
    val container = LocalAppContainer.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val scope = rememberCoroutineScope()
    var isSaving by remember { mutableStateOf(false) }

    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("★ VISIBILITY", style = type.kicker, color = Palette.orange)
                Spacer(Modifier.weight(1f))
                Text(
                    text = if (group.isPublic) "● PUBLIC" else "○ PRIVATE",
                    style = type.kicker,
                    color = if (group.isPublic) colors.accentPositive else colors.textMuted,
                )
            }
            Text(
                text = if (group.isPublic) {
                    "Anyone can find this group on the public board and bet here."
                } else {
                    "Only people with the invite link can bet here."
                },
                style = type.bodyRegular.copy(fontSize = type.caption.fontSize),
                color = colors.textSecondary,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Public group",
                    style = type.subhead,
                    color = colors.textPrimary,
                    modifier = Modifier.weight(1f),
                )
                Switch(
                    checked = group.isPublic,
                    enabled = !isSaving,
                    onCheckedChange = onCheckedChange@{ wantPublic ->
                        if (isSaving) return@onCheckedChange
                        isSaving = true
                        scope.launch {
                            try {
                                container.groupStore.setVisibility(group.id, wantPublic)
                            } catch (e: ApiError.Status) {
                                if (e.code == 401 || e.code == 403) {
                                    container.notify.error("Only the group author can change visibility.")
                                } else {
                                    container.notify.error("Could not update visibility. Please try again.")
                                }
                            } catch (e: ApiError) {
                                container.notify.error("Could not update visibility. Please try again.")
                            }
                            isSaving = false
                        }
                    },
                    colors = SwitchDefaults.colors(checkedTrackColor = Palette.orange),
                    modifier = Modifier.testTag("group-visibility-toggle"),
                )
            }
        }
    }
}

@Composable
private fun HouseRulesCard(group: Group, isAuthor: Boolean, onOpenSettings: () -> Unit) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("★ HOUSE RULES", style = type.kicker, color = Palette.orange)
                Spacer(Modifier.weight(1f))
                if (isAuthor) {
                    Text(
                        text = "EDIT →",
                        style = type.kicker,
                        color = Palette.orange,
                        modifier = Modifier
                            .clickable { onOpenSettings() }
                            .testTag("group-settings-edit"),
                    )
                }
            }
            RuleRow("Winning team", "${group.correctTeamPoints} pts", colors.textPrimary)
            Divider()
            RuleRow("Exact score", "${group.exactResultPoints} pts", colors.textPrimary)
            Divider()
            RuleRow(
                "Sneak peek",
                if (group.allowSneakPeek) "Allowed" else "Closed",
                if (group.allowSneakPeek) colors.accentPositive else Palette.orange,
            )
        }
    }
}

@Composable
private fun RuleRow(label: String, value: String, valueColor: Color) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = type.bodyRegular, color = colors.textSecondary, modifier = Modifier.weight(1f))
        Text(value, style = type.subhead, color = valueColor)
    }
}

@Composable
private fun Divider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(BettyTheme.colors.overlay06),
    )
}

@Composable
private fun ChatCard(group: Group, messages: List<GroupMessage>, myId: String?) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    val giphy = remember { GiphyClient() }

    // Local chat state mirrors the polled list and supports optimistic mutations.
    var local by remember(group.id) { mutableStateOf(messages) }
    var adopted by remember(group.id) { mutableStateOf(false) }
    // Adopt fresh polled lists (the polled list is the source of truth; reactions reconcile
    // on the next poll). Sync via effect so we never write state during composition.
    androidx.compose.runtime.LaunchedEffect(messages) {
        if (local.map { it.id } != messages.map { it.id }) local = messages
        if (messages.isNotEmpty()) adopted = true
    }

    MemeBoard(
        messages = local,
        members = group.members,
        currentUserId = myId,
        isLoaded = adopted || local.isNotEmpty(),
        onSendText = { text ->
            runCatching { container.api.postMessage(group.id, text, null) }
                .onSuccess { created -> local = listOf(created) + local }
                .isSuccess
        },
        onSendGif = { url ->
            runCatching { container.api.postMessage(group.id, null, url) }
                .onSuccess { created -> local = listOf(created) + local }
                .isSuccess
        },
        onSearchGifs = { query -> runCatching { giphy.search(query, 10) }.getOrDefault(emptyList()) },
        onToggleReaction = onToggleReaction@{ message, emoji ->
            val uid = myId ?: return@onToggleReaction
            val action = ReactionLogic.toggleAction(emoji, message.reactions, uid) ?: return@onToggleReaction
            val snapshot = local
            // Optimistic local update.
            local = local.map { m ->
                if (m.id != message.id) return@map m
                val withoutMine = m.reactions.filterNot { it.userId == uid }
                val updated = when (action) {
                    is ReactionLogic.ToggleAction.Remove -> withoutMine
                    is ReactionLogic.ToggleAction.Set -> withoutMine + MessageReaction(uid, action.emojiId, Instant.now())
                }
                m.copy(reactions = updated)
            }
            val result = when (action) {
                is ReactionLogic.ToggleAction.Remove -> runCatching { container.api.deleteReaction(message.id) }
                is ReactionLogic.ToggleAction.Set -> runCatching { container.api.putReaction(message.id, action.emojiId) }
            }
            if (result.isFailure) local = snapshot // rollback
        },
        onDeleteMessage = { id ->
            runCatching { container.api.deleteMessage(id) }
            // 404 = already gone: drop locally regardless.
            local = local.filterNot { it.id == id }
        },
    )
}

@Composable
private fun LeaveButton(group: Group) {
    val container = LocalAppContainer.current
    val nav = social.betty.navigation.LocalNavigator.current
    val scope = rememberCoroutineScope()
    var confirming by remember { mutableStateOf(false) }
    var isLeaving by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        if (confirming) {
            Text(
                text = "Are you sure you want to leave ${group.name}?",
                style = BettyTheme.type.bodyRegular,
                color = BettyTheme.colors.textSecondary,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(Space.s)) {
                BettyButton(
                    text = "Leave",
                    onClick = onClick@{
                        if (isLeaving) return@onClick
                        isLeaving = true
                        scope.launch {
                            try {
                                container.groupStore.leave(group.id)
                                nav.pop()
                            } catch (e: ApiError) {
                                container.notify.error("Could not leave group. Please try again.")
                                isLeaving = false
                                confirming = false
                            }
                        }
                    },
                    variant = BettyButtonVariant.DESTRUCTIVE,
                    loading = isLeaving,
                    block = true,
                    modifier = Modifier.weight(1f),
                )
                BettyButton(
                    text = "Cancel",
                    onClick = { confirming = false },
                    variant = BettyButtonVariant.OUTLINE,
                    block = true,
                    modifier = Modifier.weight(1f),
                )
            }
        } else {
            BettyButton(
                text = "Leave group",
                onClick = { confirming = true },
                variant = BettyButtonVariant.DESTRUCTIVE,
                block = true,
                modifier = Modifier.testTag("group-leave"),
            )
        }
    }
}

// MARK: - Card scaffolds

@Composable
private fun Card(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(BettyTheme.colors.surface)
            .padding(Space.l),
    ) {
        content()
    }
}

@Composable
private fun SideCard(kicker: String, content: @Composable () -> Unit) {
    val type = BettyTheme.type
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
            Text(kicker, style = type.kicker, color = Palette.orange)
            content()
        }
    }
}

@Composable
private fun AccentPanel(accent: Color, content: @Composable () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(Radius.sharp)
            .background(BettyTheme.colors.surfaceDeep),
    ) {
        Box(Modifier.width(3.dp).fillMaxHeight().background(accent))
        Column(
            modifier = Modifier.padding(Space.m),
            verticalArrangement = Arrangement.spacedBy(Space.xs),
        ) {
            content()
        }
    }
}
