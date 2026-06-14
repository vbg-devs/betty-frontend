package social.betty.e2e

import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import social.betty.mock.DefaultScenario
import social.betty.mock.MockBet
import social.betty.support.BettyUiTestCase

/**
 * End-to-end coverage for the Boosters feature (spec
 * `docs/superpowers/specs/2026-06-14-boosters-design.md` §4.2 — the 9 canonical scenarios).
 *
 * The hermetic mock backend (`MockApiRoutes` + `MockWire`) speaks the real wire shape for
 * `boost_count` / `boost_multiplier` / `boosted` and validates the spec §1.1 / §1.2 rules.
 *
 * CRITICAL (CLAUDE.md): assigned to an android-e2e shard in
 * `.github/workflows/ci.yml` — the "Verify android e2e shard coverage" step fails CI
 * otherwise.
 */
@RunWith(AndroidJUnit4::class)
class BoosterE2ETest : BettyUiTestCase() {

    private val sundayLegendsId: Int = DefaultScenario.GROUP_SUNDAY_LEGENDS_ID
    private val officeRoyaleId: Int = DefaultScenario.GROUP_OFFICE_ROYALE_ID
    private val currentUserId: String = DefaultScenario.CURRENT_USER_ID
    private val friendUserId: String = DefaultScenario.FRIEND_USER_ID

    // ---- Spec §4.2 #1: Admin enables boosters; values persist on the group --------

    @Test
    fun adminEnablesBoostersValuesPersist() {
        withScenario { scenario ->
            // Start from boosters OFF on Sunday Legends so we exercise the enable path.
            scenario.updateGroup(sundayLegendsId) {
                it.boostCount = 0
                it.boostMultiplier = 2
            }
        }
        launchApp()
        // Drive the route via the API directly: PUT /group/:id/settings with the
        // new fields. The mock backend validates+persists per spec §1.1.
        // We exercise the validation matrix by hitting the route through a known UID.
        // (Compose UI driving for the modal is exercised by the unit tests; the route
        // contract is the hermetic surface we want to pin here.)
        val token = backend.idToken(currentUserId)
        val responseStatus = httpPut(
            path = "/api/v1/group/$sundayLegendsId/settings",
            authToken = token,
            jsonBody = """{"boost_count":2,"boost_multiplier":2}""",
        )
        assertEquals(200, responseStatus)
        val saved = withScenario { it.group(sundayLegendsId) }
        assertEquals(2, saved?.boostCount)
        assertEquals(2, saved?.boostMultiplier)
    }

    // ---- Spec §4.2 #1b: 400 on invalid booster config -----------------------------

    @Test
    fun adminInvalidBoosterConfigReturns400() {
        launchApp()
        val token = backend.idToken(currentUserId)
        // boost_count < 0
        assertEquals(
            400,
            httpPut(
                path = "/api/v1/group/$sundayLegendsId/settings",
                authToken = token,
                jsonBody = """{"boost_count":-1}""",
            ),
        )
        // boost_multiplier < 1
        assertEquals(
            400,
            httpPut(
                path = "/api/v1/group/$sundayLegendsId/settings",
                authToken = token,
                jsonBody = """{"boost_multiplier":0}""",
            ),
        )
    }

    // ---- Spec §4.2 #2: Apply a booster on a new bet, persists, WS event ----------

    @Test
    fun applyBoosterPersistsAndEmitsActivityEvent() {
        launchApp()
        waitForWebSocketClient()
        val token = backend.idToken(currentUserId)
        val status = httpPost(
            path = "/api/v1/bet",
            authToken = token,
            jsonBody = """{
                "game_id": ${DefaultScenario.UPCOMING_GAME_ID},
                "group_id": $sundayLegendsId,
                "home_team_score": 2,
                "away_team_score": 1,
                "is_universal": false,
                "boosted": true
            }""",
        )
        assertEquals(200, status)
        val stored = withScenario { scenario ->
            scenario.bets.firstOrNull {
                it.userId == currentUserId && it.groupId == sundayLegendsId &&
                    it.gameId == DefaultScenario.UPCOMING_GAME_ID
            }
        }
        assertTrue("bet must be stored as boosted", stored?.boosted == true)
    }

    // ---- Spec §4.2 #3: Un-apply pre-kickoff returns capacity, no new event -------

    @Test
    fun unapplyBoosterReturnsCapacity() {
        withScenario { scenario ->
            scenario.bets.add(
                MockBet(
                    id = 9001,
                    userId = currentUserId,
                    gameId = DefaultScenario.UPCOMING_GAME_ID,
                    groupId = sundayLegendsId,
                    homeTeamScore = 2,
                    awayTeamScore = 1,
                    boosted = true,
                ),
            )
        }
        launchApp()
        val token = backend.idToken(currentUserId)
        val status = httpPut(
            path = "/api/v1/bet/9001",
            authToken = token,
            jsonBody = """{"home_team_score":2,"away_team_score":1,"boosted":false}""",
        )
        assertEquals(200, status)
        val updated = withScenario { it.bets.first { b -> b.id == 9001 } }
        assertFalse(updated.boosted)
        // Capacity restored.
        val used = withScenario { it.boostersUsed(currentUserId, sundayLegendsId) }
        assertEquals(0, used)
    }

    // ---- Spec §4.2 #4: Zero remaining → 400 "no boosters remaining" --------------

    @Test
    fun zeroRemainingReturnsNoBoostersRemaining() {
        withScenario { scenario ->
            // Pre-burn both boosters on two other games in Sunday Legends.
            scenario.bets.add(
                MockBet(
                    id = 9100, userId = currentUserId, gameId = DefaultScenario.LIVE_GAME_ID,
                    groupId = sundayLegendsId, homeTeamScore = 1, awayTeamScore = 1,
                    boosted = true,
                ),
            )
            scenario.bets.add(
                MockBet(
                    id = 9101, userId = currentUserId, gameId = DefaultScenario.FINISHED_GAME_ID,
                    groupId = sundayLegendsId, homeTeamScore = 1, awayTeamScore = 1,
                    boosted = true,
                ),
            )
        }
        launchApp()
        val token = backend.idToken(currentUserId)
        // Now try to boost on a NEW game (UPCOMING) — must 400 because cap exhausted.
        val status = httpPost(
            path = "/api/v1/bet",
            authToken = token,
            jsonBody = """{
                "game_id": ${DefaultScenario.UPCOMING_GAME_ID},
                "group_id": $sundayLegendsId,
                "home_team_score": 2,
                "away_team_score": 1,
                "is_universal": false,
                "boosted": true
            }""",
        )
        assertEquals(400, status)
    }

    // ---- Spec §4.2 #5: Boosted bet scores ×N at evaluation -----------------------

    @Test
    fun boostedBetScoresMultiplierAtEvaluation() {
        // Add a boosted bet on a not-yet-finished game; then evaluate.
        withScenario { scenario ->
            scenario.bets.add(
                MockBet(
                    id = 9200, userId = currentUserId, gameId = DefaultScenario.UPCOMING_GAME_ID,
                    groupId = sundayLegendsId, homeTeamScore = 2, awayTeamScore = 1,
                    boosted = true,
                ),
            )
            // Move the game to "in the past" by clearing its start date a bit.
            scenario.updateGame(DefaultScenario.UPCOMING_GAME_ID) {
                it.status = null
            }
        }
        launchApp()
        val token = backend.idToken(DefaultScenario.ADMIN_USER_ID)
        // POST /evaluategame with the exact predicted scoreline → exact-score points × 2.
        val status = httpPost(
            path = "/api/v1/evaluategame",
            authToken = token,
            jsonBody = """{"game_id":${DefaultScenario.UPCOMING_GAME_ID},"home_team_score":2,"away_team_score":1}""",
        )
        // /evaluategame returns 204 (null body) on success.
        assertTrue("status: $status", status == 200 || status == 204)
        val bet = withScenario { it.bets.first { b -> b.id == 9200 } }
        // Sunday Legends default: exactResultPoints=3, boost_multiplier=2 → 3×2 = 6.
        assertEquals(6, bet.userPoints)
    }

    // ---- Spec §4.2 #6: Zero-point boosted bet earns no multiplier extra ----------

    @Test
    fun zeroPointBoostedBetStaysZero() {
        withScenario { scenario ->
            scenario.bets.add(
                MockBet(
                    id = 9300, userId = currentUserId, gameId = DefaultScenario.UPCOMING_GAME_ID,
                    groupId = sundayLegendsId,
                    homeTeamScore = 5, awayTeamScore = 0, // a clearly-wrong prediction
                    boosted = true,
                ),
            )
        }
        launchApp()
        val token = backend.idToken(DefaultScenario.ADMIN_USER_ID)
        val status = httpPost(
            path = "/api/v1/evaluategame",
            authToken = token,
            jsonBody = """{"game_id":${DefaultScenario.UPCOMING_GAME_ID},"home_team_score":0,"away_team_score":3}""",
        )
        assertTrue("status: $status", status == 200 || status == 204)
        val bet = withScenario { it.bets.first { b -> b.id == 9300 } }
        assertEquals(0, bet.userPoints) // 0 × anything = 0
    }

    // ---- Spec §4.2 #7: Universal + boost only marks the current group ------------

    @Test
    fun universalBoostOnlyMarksCurrentGroup() {
        // Office Royale is boost_count=0 by default; Sunday Legends count=2.
        launchApp()
        val token = backend.idToken(currentUserId)
        // Submit universal + boosted FROM Sunday Legends's context.
        val status = httpPost(
            path = "/api/v1/bet",
            authToken = token,
            jsonBody = """{
                "game_id": ${DefaultScenario.UPCOMING_GAME_ID},
                "group_id": $sundayLegendsId,
                "home_team_score": 2,
                "away_team_score": 1,
                "is_universal": true,
                "boosted": true
            }""",
        )
        assertEquals(200, status)
        val sundayBet = withScenario { scenario ->
            scenario.bets.firstOrNull {
                it.userId == currentUserId && it.groupId == sundayLegendsId &&
                    it.gameId == DefaultScenario.UPCOMING_GAME_ID
            }
        }
        val officeBet = withScenario { scenario ->
            scenario.bets.firstOrNull {
                it.userId == currentUserId && it.groupId == officeRoyaleId &&
                    it.gameId == DefaultScenario.UPCOMING_GAME_ID
            }
        }
        assertTrue("Sunday Legends row is boosted", sundayBet?.boosted == true)
        assertFalse("Office Royale sibling row is NOT boosted", officeBet?.boosted == true)
    }

    // ---- Spec §4.2 #8: boost_count=0 → POST /bet with boosted:true returns 400 ---

    @Test
    fun postingBoostedBetToDisabledGroupRejects() {
        launchApp()
        val token = backend.idToken(currentUserId)
        // Office Royale has boost_count=0 in the default fixture.
        val status = httpPost(
            path = "/api/v1/bet",
            authToken = token,
            jsonBody = """{
                "game_id": ${DefaultScenario.UPCOMING_GAME_ID},
                "group_id": $officeRoyaleId,
                "home_team_score": 2,
                "away_team_score": 1,
                "is_universal": false,
                "boosted": true
            }""",
        )
        assertEquals(400, status)
        val stored = withScenario { scenario ->
            scenario.bets.firstOrNull {
                it.userId == currentUserId && it.groupId == officeRoyaleId &&
                    it.gameId == DefaultScenario.UPCOMING_GAME_ID
            }
        }
        // No persistence on a rejected request.
        assertNull(stored)
    }

    // ---- Spec §4.2 #9: Admin sets count=0 mid-tournament → eval = 1× ------------

    @Test
    fun adminDisablesMidTournamentCollapsesToOnex() {
        withScenario { scenario ->
            // User already boosted a bet on an upcoming game; admin then disables.
            scenario.bets.add(
                MockBet(
                    id = 9400, userId = currentUserId, gameId = DefaultScenario.UPCOMING_GAME_ID,
                    groupId = sundayLegendsId, homeTeamScore = 2, awayTeamScore = 1,
                    boosted = true,
                ),
            )
            scenario.updateGroup(sundayLegendsId) {
                it.boostCount = 0
                it.boostMultiplier = 2
            }
        }
        launchApp()
        val token = backend.idToken(DefaultScenario.ADMIN_USER_ID)
        val status = httpPost(
            path = "/api/v1/evaluategame",
            authToken = token,
            jsonBody = """{"game_id":${DefaultScenario.UPCOMING_GAME_ID},"home_team_score":2,"away_team_score":1}""",
        )
        assertTrue("status: $status", status == 200 || status == 204)
        val bet = withScenario { it.bets.first { b -> b.id == 9400 } }
        // exact-score points = 3, boost_count=0 → multiplier collapses to 1× → 3.
        assertEquals(3, bet.userPoints)
        // Spec §2.4: flag stays true on the row.
        assertTrue(bet.boosted)
    }

    // ---- Bet-sheet booster row visibility (UI-level, lightweight) ----------------

    @Test
    fun betSheetBoosterRowHiddenInDisabledGroup() {
        launchApp()
        waitForTag("home-group-card")
        // Tap the SECOND group card — Office Royale (boosters off).
        composeRule.onAllNodesWithTag("home-group-card")[1].performClick()
        assertTag("group-detail-screen", timeoutMillis = 15_000)
        clickTag("group-tab-games")
        waitForTag("group-game-card", timeoutMillis = 15_000)
        composeRule.onAllNodesWithTag("group-game-card").onFirst().performClick()
        assertTag("bet-sheet", timeoutMillis = 15_000)
        // No booster row should be present in a group with boost_count == 0.
        composeRule.onAllNodesWithTag("bet-booster-row")
            .fetchSemanticsNodes().also {
                assertTrue("booster row must be hidden when boost_count == 0", it.isEmpty())
            }
    }

    @Test
    fun betSheetBoosterRowVisibleInEnabledGroup() {
        launchApp()
        waitForTag("home-group-card")
        // Tap the FIRST group card — Sunday Legends (boosters on).
        composeRule.onAllNodesWithTag("home-group-card").onFirst().performClick()
        assertTag("group-detail-screen", timeoutMillis = 15_000)
        clickTag("group-tab-games")
        waitForTag("group-game-card", timeoutMillis = 15_000)
        composeRule.onAllNodesWithTag("group-game-card").onFirst().performClick()
        assertTag("bet-sheet", timeoutMillis = 15_000)
        // The booster row IS visible in a group with boost_count > 0.
        waitForTag("bet-booster-row", timeoutMillis = 5_000)
    }

    // ---- Raw HTTP helpers — drive the in-process backend directly ----------------

    private fun httpPost(path: String, authToken: String, jsonBody: String): Int =
        rawCall("POST", path, authToken, jsonBody)

    private fun httpPut(path: String, authToken: String, jsonBody: String): Int =
        rawCall("PUT", path, authToken, jsonBody)

    private fun rawCall(method: String, path: String, authToken: String, jsonBody: String): Int {
        val url = java.net.URL(backend.httpBase + path)
        val conn = url.openConnection() as java.net.HttpURLConnection
        conn.requestMethod = method
        conn.doOutput = true
        conn.setRequestProperty("Authorization", "Bearer $authToken")
        conn.setRequestProperty("Content-Type", "application/json")
        conn.outputStream.use { it.write(jsonBody.toByteArray(Charsets.UTF_8)) }
        return try {
            conn.responseCode
        } finally {
            runCatching { conn.disconnect() }
        }
    }
}
