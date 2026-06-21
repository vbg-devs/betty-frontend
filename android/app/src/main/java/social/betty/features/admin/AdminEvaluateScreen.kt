package social.betty.features.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import social.betty.core.model.Game
import social.betty.core.model.Tournament
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.SurfaceCard
import social.betty.designsystem.components.TeamLogo
import social.betty.navigation.LocalAppContainer
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// ─── Entry point ─────────────────────────────────────────────────────────────

@Composable
fun AdminEvaluateScreen() {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()

    val user by container.userStore.user.collectAsStateWithLifecycle()
    val isAdmin = user?.isAdmin == true

    // Local VM state — not retained across process death, mirrors iOS model.
    var selectedTournamentId by rememberSaveable { mutableStateOf<Int?>(null) }
    var details by remember { mutableStateOf<Tournament?>(null) }
    var isLoadingDetails by remember { mutableStateOf(false) }
    var loadFailed by remember { mutableStateOf(false) }
    var isSubmitting by remember { mutableStateOf(false) }

    // Game selected for the score sheet.
    var evaluatingGame by remember { mutableStateOf<Game?>(null) }

    // Load tournament list on entry if it hasn't been loaded yet.
    val tournaments by container.tournamentStore.tournaments.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) {
        if (tournaments.isEmpty()) {
            try { container.tournamentStore.load() } catch (_: Exception) {}
        }
    }

    val running = container.tournamentStore.running()

    fun selectTournament(tournament: Tournament) {
        if (selectedTournamentId == tournament.id) return
        selectedTournamentId = tournament.id
        details = null
        loadFailed = false
        isLoadingDetails = true
        scope.launch {
            try {
                val loaded = container.tournamentStore.loadDetails(tournament.id, force = false)
                if (selectedTournamentId == tournament.id) details = loaded
            } catch (_: Exception) {
                if (selectedTournamentId == tournament.id) loadFailed = true
            } finally {
                isLoadingDetails = false
            }
        }
    }

    fun reloadDetails() {
        val id = selectedTournamentId ?: return
        loadFailed = false
        isLoadingDetails = true
        scope.launch {
            try {
                val loaded = container.tournamentStore.loadDetails(id, force = true)
                details = loaded
            } catch (_: Exception) {
                loadFailed = true
            } finally {
                isLoadingDetails = false
            }
        }
    }

    BettyScaffold(modifier = Modifier.testTag("admin-screen")) {
        if (isAdmin) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(Space.m),
                verticalArrangement = Arrangement.spacedBy(Space.xl),
            ) {
                AdminHero()
                TournamentSection(
                    running = running,
                    selectedTournamentId = selectedTournamentId,
                    onSelect = ::selectTournament,
                )
                if (selectedTournamentId != null) {
                    GamesSection(
                        tournamentName = details?.name
                            ?: tournaments.firstOrNull { it.id == selectedTournamentId }?.name
                            ?: "",
                        isLoading = isLoadingDetails,
                        loadFailed = loadFailed,
                        pendingGames = pendingGames(details),
                        onRetry = ::reloadDetails,
                        onSelectGame = { evaluatingGame = it },
                    )
                }
            }
        } else {
            // Non-admin restricted card.
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(Space.m)
                    .testTag("admin-not-admin"),
            ) {
                SurfaceCard {
                    Column(
                        modifier = Modifier.padding(Space.xxl),
                        verticalArrangement = Arrangement.spacedBy(Space.s),
                    ) {
                        KickerText(text = "★ RESTRICTED", color = Palette.orange)
                        Text(
                            text = "YOU ARE NOT ADMIN.",
                            style = BettyTheme.type.displayL,
                            color = BettyTheme.colors.textPrimary,
                        )
                        Text(
                            text = "This page is for tournament admins only.",
                            style = BettyTheme.type.bodyRegular,
                            color = BettyTheme.colors.textBody,
                        )
                    }
                }
            }
        }
    }

    // Score sheet shown as a local overlay dialog when a game is tapped.
    evaluatingGame?.let { game ->
        EvaluateGameDialog(
            game = game,
            isSubmitting = isSubmitting,
            onDismiss = { evaluatingGame = null },
            onEvaluate = { homeScore, awayScore ->
                isSubmitting = true
                scope.launch {
                    try {
                        container.api.evaluateGame(game.id, homeScore, awayScore)
                        evaluatingGame = null
                        container.notify.success("Game evaluated!")
                        // Refetch tournament detail so the evaluated game disappears.
                        selectedTournamentId?.let { id ->
                            try {
                                details = container.tournamentStore.loadDetails(id, force = true)
                            } catch (_: Exception) {}
                        }
                    } catch (e: Exception) {
                        val msg = when {
                            e is social.betty.core.net.ApiError.Status && e.code == 410 ->
                                "This game was already evaluated."
                            e is social.betty.core.net.ApiError.Status && e.serverMessage != null ->
                                e.serverMessage
                            else -> "Could not evaluate the game. Please try again."
                        }
                        container.notify.error(msg ?: "Could not evaluate the game. Please try again.")
                    } finally {
                        isSubmitting = false
                    }
                }
            },
        )
    }
}

// ─── Derived helpers ─────────────────────────────────────────────────────────

/** Un-evaluated games (status != 1) sorted by kickoff, mirroring AdminEvaluateModel. */
private fun pendingGames(details: Tournament?): List<Game> =
    (details?.games ?: emptyList())
        .filter { it.status != 1 }
        .sortedBy { it.startDate ?: Instant.MAX }

// ─── Sub-composables ─────────────────────────────────────────────────────────

@Composable
private fun AdminHero() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        KickerText(text = "★ ADMIN", color = Palette.orange)
        Text(
            text = "EVALUATE GAMES.",
            style = type.displayL,
            color = colors.textPrimary,
        )
        Text(
            text = "Pick an ongoing tournament, choose a game that has kicked off, and post the final score. Betty distributes the points.",
            style = type.bodyRegular,
            color = colors.textBody,
        )
    }
}

@Composable
private fun TournamentSection(
    running: List<Tournament>,
    selectedTournamentId: Int?,
    onSelect: (Tournament) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        KickerText(text = "● ONGOING", color = Palette.orange)
        Text(
            text = "PICK A TOURNAMENT.",
            style = type.title1,
            color = colors.textPrimary,
        )
        if (running.isEmpty()) {
            InsetPanel {
                Column(verticalArrangement = Arrangement.spacedBy(Space.xxs)) {
                    KickerText(text = "○ NOTHING RUNNING", color = colors.textMuted)
                    Text(
                        text = "No ongoing tournaments right now. There is nothing to evaluate.",
                        style = type.bodyRegular,
                        color = colors.textBody,
                    )
                }
            }
        } else {
            running.forEach { tournament ->
                TournamentCard(
                    tournament = tournament,
                    isSelected = selectedTournamentId == tournament.id,
                    onSelect = { onSelect(tournament) },
                )
            }
        }
    }
}

@Composable
private fun TournamentCard(
    tournament: Tournament,
    isSelected: Boolean,
    onSelect: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.surface)
            .then(
                if (isSelected) Modifier.border(1.dp, Palette.orange, Radius.sharp)
                else Modifier
            )
            .clickable(onClick = onSelect)
            .padding(Space.s)
            .testTag("admin-tournament"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        if (tournament.imageUrl != null) {
            AsyncImage(
                model = tournament.imageUrl,
                contentDescription = null,
                modifier = Modifier
                    .size(width = 76.dp, height = 44.dp)
                    .clip(Radius.sharp),
            )
        }
        Text(
            text = tournament.name,
            style = type.headline,
            color = colors.textPrimary,
            modifier = Modifier.weight(1f),
            maxLines = 2,
        )
        KickerText(
            text = if (isSelected) "● SELECTED" else "SELECT →",
            color = if (isSelected) Palette.orange else colors.textMuted,
        )
    }
}

@Composable
private fun GamesSection(
    tournamentName: String,
    isLoading: Boolean,
    loadFailed: Boolean,
    pendingGames: List<Game>,
    onRetry: () -> Unit,
    onSelectGame: (Game) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        KickerText(text = "● UPCOMING & PLAYED", color = Palette.orange)
        if (tournamentName.isNotEmpty()) {
            Text(
                text = tournamentName.uppercase(),
                style = type.title1,
                color = colors.textPrimary,
            )
        }
        when {
            isLoading -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    CircularProgressIndicator(
                        color = Palette.orange,
                        modifier = Modifier.padding(Space.xxl),
                    )
                }
            }
            loadFailed -> {
                InsetPanel(accent = Palette.alertRed) {
                    Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                        Text(
                            text = "Could not load this tournament's games.",
                            style = type.bodyRegular,
                            color = colors.textBody,
                        )
                        Spacer(Modifier.height(Space.xs))
                        BettyButton(
                            text = "TRY AGAIN",
                            onClick = onRetry,
                            variant = BettyButtonVariant.OUTLINE,
                        )
                    }
                }
            }
            pendingGames.isEmpty() -> {
                InsetPanel {
                    Column(verticalArrangement = Arrangement.spacedBy(Space.xxs)) {
                        KickerText(text = "○ NO GAMES TO EVALUATE", color = colors.textMuted)
                        Text(
                            text = "Every game in this tournament has already been evaluated.",
                            style = type.bodyRegular,
                            color = colors.textBody,
                        )
                    }
                }
            }
            else -> {
                pendingGames.forEach { game ->
                    GameRow(
                        game = game,
                        onTap = { onSelectGame(game) },
                    )
                }
            }
        }
    }
}

@Composable
private fun GameRow(
    game: Game,
    onTap: () -> Unit,
) {
    val container = LocalAppContainer.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    val homeTeam = container.teamStore.byId(game.homeTeamId)
    val awayTeam = container.teamStore.byId(game.awayTeamId)
    val hasStarted = game.startDate?.isBefore(Instant.now()) == true

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.surface)
            .clickable(onClick = onTap)
            .padding(Space.s)
            .testTag("admin-game"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        TeamLogo(
            url = homeTeam?.imageUrl,
            name = homeTeam?.name,
            size = 36.dp,
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "${homeTeam?.name ?: "?"} vs ${awayTeam?.name ?: "?"}",
                style = type.headline,
                color = colors.textPrimary,
                maxLines = 2,
            )
            val kickoffLabel = game.startDate?.let {
                val fmt = DateTimeFormatter.ofPattern("d MMM, HH:mm").withZone(ZoneId.systemDefault())
                fmt.format(it)
            } ?: ""
            if (kickoffLabel.isNotEmpty()) {
                Text(
                    text = kickoffLabel,
                    style = type.caption,
                    color = colors.textMuted,
                )
            }
        }
        TeamLogo(
            url = awayTeam?.imageUrl,
            name = awayTeam?.name,
            size = 36.dp,
        )
        KickerText(
            text = if (hasStarted) "EVALUATE →" else "NOT STARTED",
            color = if (hasStarted) Palette.orange else colors.textMuted,
        )
    }
}

// ─── Score sheet dialog ───────────────────────────────────────────────────────

@Composable
private fun EvaluateGameDialog(
    game: Game,
    isSubmitting: Boolean,
    onDismiss: () -> Unit,
    onEvaluate: (home: Int, away: Int) -> Unit,
) {
    val container = LocalAppContainer.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    val homeTeam = container.teamStore.byId(game.homeTeamId)
    val awayTeam = container.teamStore.byId(game.awayTeamId)

    var homeScore by rememberSaveable { mutableStateOf("") }
    var awayScore by rememberSaveable { mutableStateOf("") }
    var showConfirm by remember { mutableStateOf(false) }

    val hasStarted = game.startDate?.isBefore(Instant.now()) == true

    val canSave = hasStarted &&
        game.status != 1 &&
        homeScore.toIntOrNull() != null &&
        awayScore.toIntOrNull() != null

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = {
            Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                KickerText(text = "★ EVALUATE GAME", color = Palette.orange)
                Text(
                    text = "POST THE SCORE.",
                    style = type.title1,
                    color = colors.textPrimary,
                )
                Text(
                    text = "${homeTeam?.name ?: "?"} vs ${awayTeam?.name ?: "?"}",
                    style = type.kicker,
                    color = colors.textSecondary,
                )
            }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Space.s),
                    verticalAlignment = Alignment.Bottom,
                ) {
                    ScoreInput(
                        label = "HOME",
                        value = homeScore,
                        onValueChange = { homeScore = it.filter { c -> c.isDigit() } },
                        testTag = "admin-home-score",
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = "–",
                        style = type.title1,
                        color = colors.textSecondary,
                        modifier = Modifier.padding(bottom = Space.s),
                    )
                    ScoreInput(
                        label = "AWAY",
                        value = awayScore,
                        onValueChange = { awayScore = it.filter { c -> c.isDigit() } },
                        testTag = "admin-away-score",
                        modifier = Modifier.weight(1f),
                    )
                }
                if (!hasStarted) {
                    Text(
                        text = "This game has not kicked off yet — the score can only be posted after the start.",
                        style = type.subhead,
                        color = colors.textMuted,
                    )
                }
            }
        },
        confirmButton = {
            BettyButton(
                text = if (isSubmitting) "EVALUATING…" else "EVALUATE GAME",
                onClick = { if (canSave) showConfirm = true },
                variant = BettyButtonVariant.PRIMARY,
                enabled = canSave && !isSubmitting,
                loading = isSubmitting,
                block = true,
                modifier = Modifier.testTag("admin-save"),
            )
        },
        dismissButton = {
            BettyButton(
                text = "CANCEL",
                onClick = onDismiss,
                variant = BettyButtonVariant.GHOST,
            )
        },
    )

    if (showConfirm) {
        val question = "Report that ${homeTeam?.name ?: "?"} - ${awayTeam?.name ?: "?"} " +
            "ended $homeScore - $awayScore? Make sure the score is correct"
        AlertDialog(
            onDismissRequest = { showConfirm = false },
            containerColor = colors.surface,
            title = {
                Text(
                    text = question,
                    style = type.headline,
                    color = colors.textPrimary,
                )
            },
            text = null,
            confirmButton = {
                BettyButton(
                    text = "EVALUATE GAME",
                    onClick = {
                        showConfirm = false
                        val home = homeScore.toIntOrNull() ?: return@BettyButton
                        val away = awayScore.toIntOrNull() ?: return@BettyButton
                        onEvaluate(home, away)
                    },
                    variant = BettyButtonVariant.PRIMARY,
                )
            },
            dismissButton = {
                BettyButton(
                    text = "CANCEL",
                    onClick = { showConfirm = false },
                    variant = BettyButtonVariant.GHOST,
                )
            },
        )
    }
}

@Composable
private fun ScoreInput(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    testTag: String,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        KickerText(text = label, color = colors.textSecondary)
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            textStyle = type.score.copy(
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight(900),
                fontSize = 48.sp,
                textAlign = TextAlign.Center,
                color = colors.textPrimary,
            ),
            placeholder = {
                Text(
                    text = "0",
                    style = type.score.copy(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight(900),
                        fontSize = 48.sp,
                        textAlign = TextAlign.Center,
                        color = colors.textMuted,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = colors.overlay06,
                unfocusedContainerColor = colors.overlay06,
                focusedBorderColor = Palette.orange,
                unfocusedBorderColor = colors.overlay10,
                disabledBorderColor = colors.overlay10,
            ),
            shape = Radius.sharp,
            modifier = Modifier
                .fillMaxWidth()
                .testTag(testTag),
        )
    }
}
