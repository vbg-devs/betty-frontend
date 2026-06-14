package social.betty.features.groupdetail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.launch
import social.betty.core.model.Bet
import social.betty.core.model.Game
import social.betty.core.model.Team
import social.betty.core.net.ApiError
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.HiddenScore
import social.betty.designsystem.components.SplitProgressBar
import social.betty.designsystem.components.TeamLogo
import social.betty.navigation.LocalAppContainer
import java.time.Instant

/**
 * Web `BetModal`: "Your bet" / "Placed bets" tabs, numeric steppers prefilled from the
 * existing bet, the pinned universal-edit submit rule, kickoff lock (input tab removed +
 * placed bets forced), sneak-peek score hiding, and 423 "betting closed".
 */
@Composable
fun BetSheet(gameId: Int, groupId: Int, onDismiss: () -> Unit) {
    val container = LocalAppContainer.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val scope = rememberCoroutineScope()
    val now = remember { Instant.now() }

    val groups by container.groupStore.groups.collectAsStateWithLifecycle()
    val group = groups.firstOrNull { it.id == groupId }
    val myId = container.userStore.id
    val peek = group?.allowSneakPeek ?: false

    val tournamentDetails by container.tournamentStore.details.collectAsStateWithLifecycle()
    val detail = group?.let { tournamentDetails[it.tournamentId] }
    val game: Game? = detail?.games?.firstOrNull { it.id == gameId }

    val teams by container.teamStore.teams.collectAsStateWithLifecycle()
    fun teamBy(id: Int): Team? = teams.firstOrNull { it.id == id }
    val homeTeam = game?.let { teamBy(it.homeTeamId) }
    val awayTeam = game?.let { teamBy(it.awayTeamId) }

    var gameBets by remember { mutableStateOf<List<Bet>>(emptyList()) }
    // All bets in the group (used for the booster-cap calculation — spec §1.6 sums the
    // user's bets where boosted == true across the WHOLE group, not just this game).
    var groupBets by remember { mutableStateOf<List<Bet>>(emptyList()) }
    val myBet = gameBets.firstOrNull { it.userId == myId }

    var homeScore by remember { mutableStateOf("") }
    var awayScore by remember { mutableStateOf("") }
    var placeInAllGroups by remember { mutableStateOf(true) } // default ON (web pin)
    var boosted by remember { mutableStateOf(false) }
    var selectedTab by remember { mutableStateOf(0) } // 0 = Your bet, 1 = Placed bets
    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var prefilledForBetId by remember { mutableStateOf<Int?>(null) }

    val lockInput = GroupBetLogic.lockInput(game?.startDate, now)
    val showScores = GroupBetLogic.showScores(game?.startDate, peek, now)
    val canSave = GroupBetLogic.canSave(game?.startDate, homeScore, awayScore, now)
    val currentTab = if (lockInput) 1 else selectedTab

    suspend fun reloadGameBets() {
        runCatching { container.api.getBetsByGame(gameId, groupId) }
            .onSuccess { gameBets = it }
    }

    suspend fun reloadGroupBets() {
        runCatching { container.api.getBetsByGroup(groupId) }
            .onSuccess { groupBets = it }
    }

    // Load game detail + bets once.
    LaunchedEffect(gameId, groupId) {
        if (game == null && group != null) {
            runCatching { container.tournamentStore.loadDetails(group.tournamentId) }
        }
        if (teams.isEmpty()) runCatching { container.teamStore.load() }
        reloadGameBets()
        reloadGroupBets()
    }

    // Reactive prefill from my existing bet (value-equality so polling doesn't clobber edits).
    LaunchedEffect(myBet?.id, myBet?.homeTeamScore, myBet?.awayTeamScore, myBet?.boosted) {
        val bet = myBet ?: return@LaunchedEffect
        if (prefilledForBetId != bet.id) {
            homeScore = bet.homeTeamScore.toString()
            awayScore = bet.awayTeamScore.toString()
            boosted = bet.boosted
            prefilledForBetId = bet.id
        }
    }

    // Booster derivations (spec §1.6, §3.3). Reads the GROUP's current config + the LIVE
    // toggle state so "X of N remaining" updates as the user flips the switch.
    val boostersEnabled = (group?.boostCount ?: 0) > 0
    val boostMultiplierValue = group?.boostMultiplier ?: 2
    // Count user's other boosted bets in this group (excluding current bet — no-op-write rule).
    val boostersUsedExcludingCurrent = if (myId != null && group != null) {
        groupBets.count { b ->
            b.userId == myId && b.groupId == groupId && b.boosted &&
                (myBet == null || b.id != myBet.id)
        }
    } else {
        0
    }
    val boostCap = group?.boostCount ?: 0
    // Reflects LIVE toggle state (matches web's Task 2 fix): freed slot shows immediately.
    val effectiveUsed = boostersUsedExcludingCurrent + if (boosted) 1 else 0
    val remainingBoosters = maxOf(0, boostCap - effectiveUsed)
    val myBetIsBoosted = myBet?.boosted == true
    val boosterDisabled = boostersEnabled && !myBetIsBoosted &&
        (boostCap - boostersUsedExcludingCurrent) <= 0
    val boosterHelpText: String = when {
        !boostersEnabled -> ""
        boosterDisabled -> "No boosters remaining in this group"
        boosted -> "This bet's points will be ×$boostMultiplierValue"
        else -> "${boostMultiplierValue}× multiplier — $remainingBoosters of $boostCap remaining"
    }

    fun submit() {
        val home = homeScore.toIntOrNull() ?: return
        val away = awayScore.toIntOrNull() ?: return
        if (isSaving) return
        val route = GroupBetLogic.submitRoute(myBet, placeInAllGroups)
        // Spec §2.6 invariant: when boosters are disabled in the group (`boost_count == 0`)
        // but the existing bet still has `boosted: true`, preserve it. Equivalent to web's
        // `boostersEnabled ? boosted : (existing?.boosted ?? false)`.
        val outgoingBoosted = if (boostersEnabled) boosted else (myBet?.boosted ?: false)
        isSaving = true
        errorMessage = null
        scope.launch {
            try {
                when (route) {
                    is GroupBetLogic.SubmitRoute.Update ->
                        container.betStore.update(route.betId, home, away, outgoingBoosted)
                    is GroupBetLogic.SubmitRoute.Place ->
                        container.betStore.place(gameId, groupId, home, away, route.isUniversal, outgoingBoosted)
                }
                reloadGameBets()
                reloadGroupBets()
                isSaving = false
                onDismiss()
            } catch (e: ApiError.Status) {
                isSaving = false
                errorMessage = if (e.code == 423) {
                    "Betting is closed — this game has already started."
                } else {
                    "Your bet could not be placed, please try again."
                }
            } catch (e: ApiError) {
                isSaving = false
                errorMessage = "Your bet could not be placed, please try again."
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.surface)
            .testTag("bet-sheet"),
    ) {
        // Header.
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = Space.l, start = Space.xl, end = Space.xl, bottom = Space.xs),
            verticalArrangement = Arrangement.spacedBy(Space.xs),
        ) {
            Text("★ PLACE YOUR BET", style = type.kicker, color = Palette.orange)
            Text(
                text = "${(homeTeam?.name ?: "").uppercase()} vs ${(awayTeam?.name ?: "").uppercase()}",
                style = type.title2,
                color = colors.textPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (game != null) {
                Spacer(Modifier.height(Space.xs))
                BetDistributionHeader(bets = gameBets, game = game, homeTeam = homeTeam, awayTeam = awayTeam)
            }
        }

        // Tabs — "Your bet" is REMOVED after kickoff (web pin), not just disabled.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = Space.xl, end = Space.xl, top = Space.s),
            horizontalArrangement = Arrangement.spacedBy(Space.l),
            verticalAlignment = Alignment.Bottom,
        ) {
            if (!lockInput) {
                BetTab(
                    title = "YOUR BET",
                    selected = currentTab == 0,
                    onClick = { selectedTab = 0 },
                    tag = "bet-tab-yours",
                )
            }
            BetTab(
                title = "PLACED BETS",
                selected = currentTab == 1,
                onClick = { selectedTab = 1 },
                tag = "bet-tab-placed",
            )
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 460.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            if (currentTab == 0 && !lockInput) {
                YourBetTab(
                    homeScore = homeScore,
                    awayScore = awayScore,
                    onHome = { homeScore = it },
                    onAway = { awayScore = it },
                    errorMessage = errorMessage,
                    boostersEnabled = boostersEnabled,
                    boosted = boosted,
                    onBoostedChange = { boosted = it },
                    boosterDisabled = boosterDisabled,
                    boosterHelpText = boosterHelpText,
                    showUniversalCaveat = placeInAllGroups && boosted,
                )
            } else {
                PlacedBetsTab(
                    bets = gameBets,
                    myId = myId,
                    showScores = showScores,
                    group = group,
                )
            }
        }

        // Footer (only on the "Your bet" tab).
        if (currentTab == 0 && !lockInput) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Space.xl, vertical = Space.m),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clickable { placeInAllGroups = !placeInAllGroups }
                        .testTag("bet-all-groups"),
                ) {
                    Checkbox(
                        checked = placeInAllGroups,
                        onCheckedChange = { placeInAllGroups = it },
                        colors = CheckboxDefaults.colors(checkedColor = Palette.orange),
                    )
                    Text(
                        text = "Place this bet in all my groups",
                        style = type.bodyRegular,
                        color = colors.textSecondary,
                    )
                }
                BettyButton(
                    text = if (myBet != null) "Update bet" else "Place bet",
                    onClick = { submit() },
                    enabled = canSave,
                    loading = isSaving,
                    block = true,
                    modifier = Modifier.testTag("bet-save"),
                )
            }
        }
    }
}

@Composable
private fun BetTab(title: String, selected: Boolean, onClick: () -> Unit, tag: String) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clickable { onClick() }
            .testTag(tag),
    ) {
        Text(
            text = title,
            style = type.caption,
            color = if (selected) colors.textPrimary else colors.textMuted,
            modifier = Modifier.padding(vertical = 14.dp),
        )
        Box(
            modifier = Modifier
                .height(3.dp)
                .width(if (selected) 48.dp else 0.dp)
                .background(Palette.orange),
        )
    }
}

@Composable
private fun YourBetTab(
    homeScore: String,
    awayScore: String,
    onHome: (String) -> Unit,
    onAway: (String) -> Unit,
    errorMessage: String?,
    boostersEnabled: Boolean,
    boosted: Boolean,
    onBoostedChange: (Boolean) -> Unit,
    boosterDisabled: Boolean,
    boosterHelpText: String,
    showUniversalCaveat: Boolean,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(Space.xl),
        verticalArrangement = Arrangement.spacedBy(Space.l),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            ScoreStepper(
                label = "HOME",
                value = homeScore,
                onValue = onHome,
                tag = "bet-home-stepper",
                modifier = Modifier.weight(1f),
            )
            Text(
                text = "–",
                style = type.title1.copy(fontSize = 36.sp),
                color = colors.textMuted,
                modifier = Modifier.padding(bottom = 18.dp),
            )
            ScoreStepper(
                label = "AWAY",
                value = awayScore,
                onValue = onAway,
                tag = "bet-away-stepper",
                modifier = Modifier.weight(1f),
            )
        }
        // Booster row (spec §3.3). Hidden entirely when boost_count == 0.
        if (boostersEnabled) {
            BoosterRow(
                boosted = boosted,
                onBoostedChange = onBoostedChange,
                disabled = boosterDisabled,
                helpText = boosterHelpText,
                showUniversalCaveat = showUniversalCaveat,
            )
        }
        if (errorMessage != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(IntrinsicSize.Min)
                    .clip(Radius.sharp)
                    .background(colors.surfaceDeep)
                    .testTag("bet-error"),
            ) {
                Box(Modifier.width(3.dp).fillMaxHeight().background(Palette.alertRed))
                Text(
                    text = errorMessage,
                    style = type.body,
                    color = colors.textPrimary,
                    modifier = Modifier.padding(Space.m),
                )
            }
        }
    }
}

/**
 * Booster row (spec §3.3). Rocket + label + switch row, optional helper text underneath,
 * universal-bet caveat shown only when both universal AND boosted toggles are on.
 */
@Composable
private fun BoosterRow(
    boosted: Boolean,
    onBoostedChange: (Boolean) -> Unit,
    disabled: Boolean,
    helpText: String,
    showUniversalCaveat: Boolean,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.overlay06)
            .border(1.dp, colors.overlay10, Radius.sharp)
            .padding(Space.s)
            .testTag("bet-booster-row"),
        verticalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("🚀", style = type.body, modifier = Modifier.padding(end = Space.xs))
            Text(
                text = "Apply booster",
                style = type.subhead,
                color = colors.textPrimary,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = boosted,
                onCheckedChange = onBoostedChange,
                enabled = !disabled,
                colors = SwitchDefaults.colors(checkedTrackColor = Palette.orange),
                modifier = Modifier.testTag("bet-booster-toggle"),
            )
        }
        if (helpText.isNotEmpty()) {
            Text(
                text = helpText,
                style = type.bodyRegular.copy(fontSize = type.caption.fontSize),
                color = colors.textSecondary,
                modifier = Modifier.testTag("bet-booster-help"),
            )
        }
        if (showUniversalCaveat) {
            Text(
                text = "Booster applies to this group only — the bet's copies in your other groups aren't boosted.",
                style = type.bodyRegular.copy(fontSize = type.caption.fontSize),
                color = Palette.orange,
                modifier = Modifier.testTag("bet-booster-universal-caveat"),
            )
        }
    }
}

@Composable
private fun ScoreStepper(
    label: String,
    value: String,
    onValue: (String) -> Unit,
    tag: String,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    fun step(delta: Int) {
        val current = value.toIntOrNull() ?: 0
        onValue((current + delta).coerceAtLeast(0).toString())
    }

    Column(
        modifier = modifier.testTag(tag),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(label, style = type.kicker, color = colors.textSecondary)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(Radius.sharp)
                .background(colors.overlay06)
                .border(1.dp, colors.overlay10, Radius.sharp)
                .padding(vertical = 18.dp, horizontal = 8.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (value.isEmpty()) {
                Text("0", style = type.scoreXL, color = colors.textMuted)
            }
            BasicTextField(
                value = value,
                onValueChange = { input -> onValue(input.filter { it.isDigit() }) },
                singleLine = true,
                textStyle = type.scoreXL.copy(color = colors.textPrimary, textAlign = TextAlign.Center),
                cursorBrush = SolidColor(Palette.orange),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("$tag-field"),
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Space.xs), modifier = Modifier.fillMaxWidth()) {
            StepButton("−", { step(-1) }, "$tag-minus", Modifier.weight(1f))
            StepButton("+", { step(1) }, "$tag-plus", Modifier.weight(1f))
        }
    }
}

@Composable
private fun StepButton(symbol: String, onClick: () -> Unit, tag: String, modifier: Modifier = Modifier) {
    val colors = BettyTheme.colors
    Box(
        modifier = modifier
            .clip(Radius.sharp)
            .background(colors.overlay08)
            .clickable { onClick() }
            .padding(vertical = 10.dp)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Text(symbol, style = BettyTheme.type.title3, color = colors.textPrimary)
    }
}

@Composable
private fun PlacedBetsTab(
    bets: List<Bet>,
    myId: String?,
    showScores: Boolean,
    group: social.betty.core.model.Group?,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val ordered = GroupBetLogic.orderedBets(bets)
    val membersById = group?.members?.associateBy { it.userId } ?: emptyMap()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp, horizontal = Space.s),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        if (ordered.isEmpty()) {
            Text(
                text = "★ NO BETS YET",
                style = type.kicker,
                color = colors.textMuted,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = Space.xl),
                textAlign = TextAlign.Center,
            )
        }
        ordered.forEach { bet ->
            val isYou = myId != null && bet.userId == myId
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(IntrinsicSize.Min)
                    .clip(Radius.sharp)
                    .background(if (isYou) Palette.orangeTint12 else Color.Transparent),
            ) {
                if (isYou) {
                    Box(Modifier.width(3.dp).fillMaxHeight().background(Palette.orange))
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 12.dp, horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = membersById[bet.userId]?.displayName() ?: "",
                        style = type.subhead,
                        color = colors.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    Spacer(Modifier.weight(1f))
                    if (showScores) {
                        Text(
                            text = "${bet.homeTeamScore} – ${bet.awayTeamScore}",
                            style = type.subhead,
                            color = colors.textPrimary,
                        )
                        if (bet.isProcessed) {
                            val points = bet.userPoints ?: 0
                            Spacer(Modifier.width(10.dp))
                            Text(
                                text = if (points > 0) "+${points}P" else "0P",
                                style = type.kicker,
                                color = when {
                                    points == 3 -> colors.accentPositive
                                    points == 1 -> Palette.yellow
                                    else -> colors.textSecondary
                                },
                            )
                            // Post-evaluation rocket — only when the bet earned > 0 points
                            // (spec §2.5 suppression).
                            if (bet.boosted && points > 0) {
                                Spacer(Modifier.width(4.dp))
                                Text(
                                    text = "🚀",
                                    style = type.bodyRegular.copy(fontSize = type.caption.fontSize),
                                    modifier = Modifier.testTag("bet-row-rocket"),
                                )
                            }
                        } else if (bet.boosted) {
                            // Pre-kickoff standalone rocket next to the score, no point value yet.
                            Spacer(Modifier.width(6.dp))
                            Text(
                                text = "🚀",
                                style = type.bodyRegular.copy(fontSize = type.caption.fontSize),
                                modifier = Modifier.testTag("bet-row-rocket"),
                            )
                        }
                    } else {
                        HiddenScore()
                    }
                }
            }
        }
    }
}

/**
 * Web `BetHistory.vue`: home/tie/away distribution bar (largest-remainder percentages)
 * over the two team logos around "VS"; finished games show the final score.
 */
@Composable
private fun BetDistributionHeader(bets: List<Bet>, game: Game, homeTeam: Team?, awayTeam: Team?) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val (home, tie, away) = GroupBetLogic.distribution(bets)

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text("$tie% TIE", style = type.caption, color = colors.textSecondary)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.xs)) {
                Text("$home%", style = type.caption, color = colors.textSecondary)
                SplitProgressBar(
                    leftFraction = home.toFloat(),
                    drawFraction = tie.toFloat(),
                    rightFraction = away.toFloat(),
                    modifier = Modifier.weight(1f),
                )
                Text("$away%", style = type.caption, color = colors.textSecondary)
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            BetTeamColumn(homeTeam, Modifier.weight(1f))
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(top = Space.s),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text("VS", style = type.kicker, color = colors.textMuted)
                if (game.isFinished) {
                    Text("FINISHED", style = type.micro, color = colors.textMuted)
                    Text(
                        text = "${game.homeTeamScore} - ${game.awayTeamScore}",
                        style = type.score.copy(fontSize = 18.sp),
                        color = colors.textPrimary,
                    )
                }
            }
            BetTeamColumn(awayTeam, Modifier.weight(1f))
        }
    }
}

@Composable
private fun BetTeamColumn(team: Team?, modifier: Modifier = Modifier) {
    val colors = BettyTheme.colors
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        TeamLogo(url = team?.imageUrl, name = team?.name, size = 56.dp)
        Text(
            text = (team?.name ?: "").uppercase(),
            style = BettyTheme.type.caption,
            color = colors.textPrimary,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
