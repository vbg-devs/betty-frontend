package social.betty.mock

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import kotlin.random.Random

/**
 * Every `/api/v1` route, with the production wire quirks preserved (api-contract.md): POST /bet
 * answers 200 with an id-0 echo (423 once started), /groupbyid 500s for unknown/non-member,
 * /join/:code does 404/409/403, PUT /user/me applies only name+country, 204s have no body,
 * several 200s are the literal `null`, ...
 */
private val ALLOWED_IMAGE_TYPES = listOf("image/jpeg", "image/png", "image/webp", "image/gif")

fun BettyMockBackend.registerApiRoutes() {
    registerMiscAndUserRoutes()
    registerGroupRoutes()
    registerBetRoutes()
    registerTournamentRoutes()
    registerReferenceRoutes()
    registerMessageBoardRoutes()
    registerAnnouncementRoutes()
    registerUploadCatchAll()
}

// --- JSON read helpers (distinguish absent vs explicit null) -------------------

/** Returns the Int at [key], or null when absent / null / not an int. */
private fun JSONObject.optIntOrNull(key: String): Int? =
    if (!has(key) || isNull(key)) null else (opt(key) as? Number)?.toInt()

/** Returns the String at [key], or null when absent / null / not a string. */
private fun JSONObject.optStringOrNull(key: String): String? =
    if (!has(key) || isNull(key)) null else opt(key) as? String

/** Returns the Boolean at [key], or [default] when absent / null / not a boolean. */
private fun JSONObject.optBoolOr(key: String, default: Boolean): Boolean =
    if (!has(key) || isNull(key)) default else (opt(key) as? Boolean) ?: default

private fun jsonOf(vararg pairs: Pair<String, Any?>): JSONObject {
    val json = JSONObject()
    for ((k, v) in pairs) json.put(k, v ?: JSONObject.NULL)
    return json
}

// --- Misc + users --------------------------------------------------------------

private fun BettyMockBackend.registerMiscAndUserRoutes() {
    api("GET", "/ping") { _, _, uid, _ ->
        MockHttpResponse.json(
            JSONObject().apply {
                put("iss", "https://securetoken.google.com/betty-f676d")
                put("aud", "betty-f676d")
                put("exp", Instant.now().plusSeconds(3600).epochSecond)
                put("iat", Instant.now().epochSecond)
                put("sub", uid)
                put("uid", uid)
                put("firebase", JSONObject(mapOf("sign_in_provider" to "password")))
            },
        )
    }

    // Stubbed server-side — ALWAYS an empty array.
    api("GET", "/activitystream") { _, _, _, _ -> MockHttpResponse.json(JSONArray()) }

    api("POST", "/user") { request, _, uid, scenario ->
        val user = scenario.user(uid) ?: return@api MockHttpResponse.empty(500)
        if (user.hasProfile) return@api MockHttpResponse.empty(500) // duplicate create → 500
        val body = request.bodyJson ?: JSONObject()
        body.optStringOrNull("name")?.takeIf { it.isNotEmpty() }?.let { user.name = it }
        body.optStringOrNull("email")?.takeIf { it.isNotEmpty() }?.let { user.email = it }
        if (user.name.isEmpty() || user.email.isEmpty()) {
            return@api MockHttpResponse.empty(500) // handler panics when field AND claim are missing
        }
        body.optStringOrNull("image_url")?.takeIf { it.isNotEmpty() }?.let {
            user.imageUrl = it
            user.firebaseImageUrl = it
        }
        user.hasProfile = true
        // 201 echo with ZERO timestamps — clients must re-GET /user/me.
        MockHttpResponse.json(MockWire.user(user, zeroTimestamps = true), status = 201)
    }

    api("GET", "/user/me") { _, _, uid, scenario ->
        val user = scenario.user(uid)
        if (user == null || !user.hasProfile) MockHttpResponse.empty(404)
        else MockHttpResponse.json(MockWire.user(user))
    }

    api("PUT", "/user/me") { request, _, uid, scenario ->
        val user = scenario.user(uid)
        if (user == null || !user.hasProfile) return@api MockHttpResponse.empty(500)
        val body = request.bodyJson ?: JSONObject()
        scenario.updateUser(uid) {
            // ONLY name and country are applied; an omitted name clears to "".
            it.name = body.optStringOrNull("name") ?: ""
            it.country = body.optStringOrNull("country") // null/absent → nil clears
        }
        MockHttpResponse.json(MockWire.user(scenario.user(uid)!!))
    }

    api("DELETE", "/user/me") { _, _, uid, scenario ->
        scenario.updateUser(uid) {
            it.name = "Deleted User"
            it.email = ""
            it.imageUrl = null
            it.hasProfile = false
        }
        MockHttpResponse.nullBody()
    }

    api("POST", "/user/me/add_push_token") { request, _, _, _ ->
        val token = request.bodyJson?.optStringOrNull("token") ?: ""
        if (token.isEmpty()) MockHttpResponse.empty(400) else MockHttpResponse.empty(200)
    }

    api("POST", "/user/me/profile-image/upload-url") { request, _, uid, _ ->
        presign(request, key = "users/$uid/profile/mock-${Random.nextInt(1000, 10000)}")
    }

    api("PUT", "/user/me/profile-image") { request, _, uid, scenario ->
        val url = request.bodyJson?.optStringOrNull("image_url")
        if (url == null || !url.startsWith(publicAssetBase)) return@api MockHttpResponse.empty(400)
        scenario.updateUser(uid) { it.imageUrl = url }
        MockHttpResponse.json(jsonOf("image_url" to url))
    }

    api("DELETE", "/user/me/profile-image") { _, _, uid, scenario ->
        scenario.updateUser(uid) { it.imageUrl = it.firebaseImageUrl }
        MockHttpResponse.json(jsonOf("image_url" to MockWire.orNull(scenario.user(uid)?.imageUrl)))
    }

    api("GET", "/user/:id/groups") { _, params, _, scenario ->
        val id = params["id"]
        val user = id?.let { scenario.user(it) }
        if (user == null || !user.hasProfile) return@api MockHttpResponse.empty(404)
        val placements = JSONArray()
        for (group in scenario.groups) {
            val member = group.member(id) ?: continue
            if (member.status != MembershipStatus.ACTIVE) continue
            placements.put(MockWire.placement(group, member, scenario))
        }
        MockHttpResponse.json(jsonOf("user" to MockWire.user(user), "groups" to placements))
    }
}

// --- Groups --------------------------------------------------------------------

private fun BettyMockBackend.registerGroupRoutes() {
    api("POST", "/group") { request, _, uid, scenario ->
        val body = request.bodyJson ?: JSONObject()
        // Gin binding: name + tournament_id required, points required NON-ZERO.
        val name = body.optStringOrNull("name")
        val tournamentId = body.optIntOrNull("tournament_id")
        val correct = body.optIntOrNull("correct_team_points")
        val exact = body.optIntOrNull("exact_result_points")
        if (name.isNullOrEmpty() || tournamentId == null || tournamentId == 0 ||
            correct == null || correct == 0 || exact == null || exact == 0
        ) {
            return@api MockHttpResponse.empty(400)
        }
        body.optStringOrNull("description")?.let { if (it.length > 1000) return@api MockHttpResponse.empty(400) }
        val id = scenario.nextGroupId
        scenario.nextGroupId += 1
        scenario.groups.add(
            MockGroup(
                id = id, name = name, tournamentId = tournamentId,
                inviteCode = "NEW$id",
                welcomeMessage = body.optStringOrNull("welcome_message"),
                description = body.optStringOrNull("description"),
                correctTeamPoints = correct, exactResultPoints = exact,
                allowSneakPeek = body.optBoolOr("allow_sneak_peek", false),
                groupPlayDeadline = MockWire.parseTime(if (body.has("group_play_deadline") && !body.isNull("group_play_deadline")) body.opt("group_play_deadline") else null),
                mode = body.optIntOrNull("mode") ?: 0,
                publicAt = if (body.optBoolOr("is_public", false)) Instant.now() else null,
                members = mutableListOf(MockMember(userId = uid, accessLevel = 0)),
            ),
        )
        MockHttpResponse.json(jsonOf("group_id" to id), status = 201)
    }

    api("POST", "/join/:code") { _, params, uid, scenario ->
        val group = scenario.groupByCode(params["code"] ?: "") ?: return@api MockHttpResponse.empty(404)
        val member = group.member(uid)
        if (member != null) {
            when (member.status) {
                MembershipStatus.BLOCKED -> return@api MockHttpResponse.empty(403)
                MembershipStatus.ACTIVE -> return@api MockHttpResponse.empty(409)
                MembershipStatus.LEFT -> scenario.updateMember(group.id, uid) { it.status = MembershipStatus.ACTIVE }
            }
        } else {
            scenario.updateGroup(group.id) { it.members.add(MockMember(userId = uid, accessLevel = 2)) }
        }
        val who = scenario.user(uid)?.name ?: "Someone"
        pushEvent(
            "group_joined",
            JSONObject().apply {
                put("group", JSONObject().apply { put("id", group.id); put("name", group.name) })
                put("who", who)
            },
        )
        MockHttpResponse.json(jsonOf("group_id" to group.id))
    }

    api("GET", "/groupbyid/:id") { _, params, uid, scenario ->
        // Production quirk: 500 (not 404) for unknown group / non-member.
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) }
        if (group == null || !group.isActiveMember(uid)) MockHttpResponse.empty(500)
        else MockHttpResponse.json(MockWire.group(group, scenario))
    }

    api("GET", "/groups") { _, _, uid, scenario ->
        val groups = JSONArray()
        scenario.groups.filter { it.isActiveMember(uid) }.forEach { groups.put(MockWire.group(it, scenario)) }
        MockHttpResponse.json(groups)
    }

    api("GET", "/group/:code") { _, params, _, scenario ->
        val group = scenario.groupByCode(params["code"] ?: "") ?: return@api MockHttpResponse.empty(404)
        MockHttpResponse.json(MockWire.groupPeek(group, scenario))
    }

    api("PUT", "/group/:id/code") { _, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(500)
        if (!group.isAuthor(uid)) return@api MockHttpResponse.empty(401)
        val fresh = "RC${Random.nextInt(100_000, 1_000_000)}"
        scenario.updateGroup(id) { it.inviteCode = fresh }
        MockHttpResponse.json(jsonOf("code" to fresh))
    }

    api("PUT", "/group/:id/nickname") { request, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) }
        if (group == null || !group.isActiveMember(uid)) return@api MockHttpResponse.empty(404) // no active membership
        val raw = request.bodyJson?.optStringOrNull("nickname") // null/absent → nil clears
        applyNickname(groupId = id, uid = uid, raw = raw, scenario = scenario)
    }

    api("PUT", "/group/:id/visibility") { request, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(404)
        if (!group.isAuthor(uid)) return@api MockHttpResponse.empty(401)
        val isPublic = request.bodyJson?.optBoolOr("is_public", false) ?: false
        val publicAt: Instant? = if (isPublic) (group.publicAt ?: Instant.now()) else null
        scenario.updateGroup(id) { it.publicAt = publicAt }
        pushEvent(
            "group_visibility_changed",
            JSONObject().apply {
                put("group_id", id)
                put("public_at", MockWire.time(publicAt))
            },
        )
        MockHttpResponse.json(jsonOf("public_at" to MockWire.time(publicAt)))
    }

    api("PUT", "/group/:id/settings") { request, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        if (id == null || scenario.group(id) == null) return@api MockHttpResponse.empty(404)
        if (!scenario.group(id)!!.isAuthor(uid)) return@api MockHttpResponse.empty(401)
        val body = request.bodyJson ?: JSONObject()
        body.optStringOrNull("description")?.let { if (it.length > 1000) return@api MockHttpResponse.empty(400) }
        // Partial update: only PRESENT keys are written; explicit null clears the two nullable ones.
        scenario.updateGroup(id) { group ->
            if (body.has("welcome_message")) group.welcomeMessage = body.optStringOrNull("welcome_message")
            if (body.has("description")) group.description = body.optStringOrNull("description")
            body.optIntOrNull("correct_team_points")?.let { if (it >= 0) group.correctTeamPoints = it }
            body.optIntOrNull("exact_result_points")?.let { if (it >= 0) group.exactResultPoints = it }
            if (body.has("allow_sneak_peek") && !body.isNull("allow_sneak_peek")) {
                (body.opt("allow_sneak_peek") as? Boolean)?.let { group.allowSneakPeek = it }
            }
            group.updatedAt = Instant.now()
        }
        MockHttpResponse.json(MockWire.group(scenario.group(id)!!, scenario))
    }

    api("POST", "/group/:id/join") { _, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) }
        if (group == null || group.publicAt == null) return@api MockHttpResponse.empty(404) // missing OR private
        val member = group.member(uid)
        if (member != null) {
            when (member.status) {
                MembershipStatus.BLOCKED -> return@api MockHttpResponse.empty(403)
                MembershipStatus.ACTIVE -> return@api MockHttpResponse.empty(409)
                MembershipStatus.LEFT -> scenario.updateMember(id, uid) { it.status = MembershipStatus.ACTIVE }
            }
        } else {
            scenario.updateGroup(id) { it.members.add(MockMember(userId = uid, accessLevel = 2)) }
        }
        val who = scenario.user(uid)?.name ?: "Someone"
        pushEvent(
            "group_joined",
            JSONObject().apply {
                put("group", JSONObject().apply { put("id", group.id); put("name", group.name) })
                put("who", who)
            },
        )
        MockHttpResponse.json(jsonOf("group_id" to id))
    }

    api("GET", "/groups/public") { request, _, uid, scenario ->
        val q = request.query["q"]?.lowercase() ?: ""
        val tournamentId = request.query["tournament_id"]?.toIntOrNull()
        val items = JSONArray()
        scenario.groups
            .filter { it.publicAt != null }
            .filter { q.isEmpty() || it.name.lowercase().contains(q) }
            .filter { tournamentId == null || it.tournamentId == tournamentId }
            .forEach { items.put(MockWire.publicGroupItem(it, callerId = uid, scenario = scenario)) }
        MockHttpResponse.json(jsonOf("items" to items, "next_cursor" to "")) // empty = no more pages
    }

    api("POST", "/groupbyid/:id/disable-peak") { _, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(500)
        if (!group.isAuthor(uid)) return@api MockHttpResponse.empty(401)
        scenario.updateGroup(id) { it.allowSneakPeek = false }
        MockHttpResponse.empty(200)
    }

    api("DELETE", "/group/:id/leave") { _, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) }
        if (group == null || group.members.isEmpty()) return@api MockHttpResponse.empty(400)
        scenario.updateMember(id, uid) { it.status = MembershipStatus.LEFT }
        MockHttpResponse.nullBody()
    }

    api("DELETE", "/group/:id/block/:userid") { _, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(400)
        // Production quirk: a non-author gets 500, not 401.
        if (!group.isAuthor(uid)) return@api MockHttpResponse.empty(500)
        scenario.updateMember(id, params["userid"] ?: "") { it.status = MembershipStatus.BLOCKED }
        MockHttpResponse.nullBody()
    }

    api("POST", "/group/:id/header-image/upload-url") { request, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(400)
        if (!group.isAuthor(uid)) return@api MockHttpResponse.empty(401)
        presign(request, key = "groups/$id/header/mock-${Random.nextInt(1000, 10000)}")
    }

    api("PUT", "/group/:id/header-image") { request, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(400)
        if (!group.isAuthor(uid)) return@api MockHttpResponse.empty(401)
        val url = request.bodyJson?.optStringOrNull("header_image_url")
        if (url == null || !url.startsWith(publicAssetBase)) return@api MockHttpResponse.empty(400)
        scenario.updateGroup(id) { it.headerImageUrl = url }
        MockHttpResponse.json(jsonOf("header_image_url" to url))
    }

    api("DELETE", "/group/:id/header-image") { _, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val group = id?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(400)
        if (!group.isAuthor(uid)) return@api MockHttpResponse.empty(401)
        scenario.updateGroup(id) { it.headerImageUrl = null }
        MockHttpResponse.empty(200)
    }
}

private fun applyNickname(groupId: Int, uid: String, raw: String?, scenario: MockScenario): MockHttpResponse {
    val trimmed = raw?.trim() ?: ""
    if (trimmed.length > 120) {
        return MockHttpResponse.json(jsonOf("error" to "nickname too long"), status = 400)
    }
    val value: String? = trimmed.ifEmpty { null }
    scenario.updateMember(groupId, uid) { it.nickname = value }
    return MockHttpResponse.json(jsonOf("nickname" to MockWire.orNull(value)))
}

// --- Bets ----------------------------------------------------------------------

private fun BettyMockBackend.registerBetRoutes() {
    api("GET", "/bets/bygroup/:group") { _, params, _, scenario ->
        val groupId = params["group"]?.toIntOrNull() ?: return@api MockHttpResponse.empty(500)
        // ALL members' bets for ALL games in the group.
        val arr = JSONArray()
        scenario.bets.filter { it.groupId == groupId }.forEach { arr.put(MockWire.bet(it)) }
        MockHttpResponse.json(arr)
    }

    api("GET", "/bets/bygame/:game/:group") { _, params, uid, scenario ->
        val gameId = params["game"]?.toIntOrNull() ?: return@api MockHttpResponse.empty(500)
        val groupId = params["group"]?.toIntOrNull() ?: return@api MockHttpResponse.empty(500)
        // The CALLER's own bets only.
        val arr = JSONArray()
        scenario.bets
            .filter { it.userId == uid && it.gameId == gameId && it.groupId == groupId }
            .forEach { arr.put(MockWire.bet(it)) }
        MockHttpResponse.json(arr)
    }

    api("POST", "/bet") { request, _, uid, scenario ->
        val body = request.bodyJson ?: JSONObject()
        val gameId = body.optIntOrNull("game_id") ?: return@api MockHttpResponse.empty(400)
        val groupId = body.optIntOrNull("group_id") ?: 0
        val home = body.optIntOrNull("home_team_score") ?: 0
        val away = body.optIntOrNull("away_team_score") ?: 0
        val isUniversal = body.optBoolOr("is_universal", false)
        val game = scenario.game(gameId) ?: return@api MockHttpResponse.empty(500) // unknown game → 500
        if (!game.startDate.isAfter(Instant.now())) return@api MockHttpResponse.empty(423) // already started
        if (isUniversal) {
            // Upsert into EVERY group of the caller in the game's tournament.
            scenario.groups
                .filter { it.tournamentId == game.tournamentId && it.isActiveMember(uid) }
                .forEach { scenario.upsertBet(uid, gameId, it.id, home, away) }
        } else {
            val group = scenario.group(groupId)
            if (group == null || !group.isActiveMember(uid)) return@api MockHttpResponse.empty(401)
            scenario.upsertBet(uid, gameId, groupId, home, away)
        }
        val echo = MockWire.betEcho(uid, gameId, groupId, home, away, isUniversal)
        pushEvent("bet_placed", echo)
        // 200 (NOT 201) — echo with id 0 and zero timestamps.
        MockHttpResponse.json(echo)
    }

    api("PUT", "/bet/:id") { request, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val bet = id?.let { betId -> scenario.bets.firstOrNull { it.id == betId } }
            ?: return@api MockHttpResponse.empty(404)
        if (bet.userId != uid) return@api MockHttpResponse.empty(401) // someone else's bet
        val game = scenario.game(bet.gameId)
        if (game != null && !game.startDate.isAfter(Instant.now())) return@api MockHttpResponse.empty(423)
        if (bet.processedAt != null) return@api MockHttpResponse.empty(500) // already evaluated
        val body = request.bodyJson ?: JSONObject()
        bet.homeTeamScore = body.optIntOrNull("home_team_score") ?: bet.homeTeamScore
        bet.awayTeamScore = body.optIntOrNull("away_team_score") ?: bet.awayTeamScore
        bet.updatedAt = Instant.now()
        pushEvent("bet_updated", MockWire.bet(bet))
        MockHttpResponse.json(MockWire.bet(bet)) // the DB row, real id/timestamps
    }
}

// --- Tournaments & games -------------------------------------------------------

private fun BettyMockBackend.registerTournamentRoutes() {
    api("GET", "/tournaments") { _, _, _, scenario ->
        if (scenario.tournaments.isEmpty()) return@api MockHttpResponse.empty(404) // empty table
        // pools/games are NULL in the list shape.
        val arr = JSONArray()
        scenario.tournaments.forEach { arr.put(MockWire.tournament(it, details = false)) }
        MockHttpResponse.json(arr)
    }

    api("GET", "/tournament/:id") { _, params, _, scenario ->
        val id = params["id"]?.toIntOrNull() ?: return@api MockHttpResponse.empty(500)
        if (id < 0) return@api MockHttpResponse.empty(400)
        // 404 when unknown OR already ended (end_date <= NOW()).
        val tournament = scenario.tournament(id)
        if (tournament == null || tournament.hasEnded()) return@api MockHttpResponse.empty(404)
        MockHttpResponse.json(MockWire.tournament(tournament, details = true))
    }

    api("GET", "/tournament/:id/leaderboard") { request, params, _, scenario ->
        val id = params["id"]?.toIntOrNull() ?: return@api MockHttpResponse.empty(400)
        if (id < 0) return@api MockHttpResponse.empty(400)
        val limit = maxOf(10, request.query["limit"]?.toIntOrNull() ?: 10)
        // Best normalized_score per user across the tournament's groups.
        val best = LinkedHashMap<String, Double>()
        for (group in scenario.groups.filter { it.tournamentId == id }) {
            for (member in group.members.filter { it.status == MembershipStatus.ACTIVE }) {
                best[member.userId] = maxOf(best[member.userId] ?: 0.0, member.normalizedScore)
            }
        }
        val rows = JSONArray()
        best.entries.sortedByDescending { it.value }.take(limit).forEach { (userId, score) ->
            val user = scenario.user(userId)
            rows.put(
                jsonOf(
                    "user_id" to userId,
                    "name" to MockWire.orNull(user?.name),
                    "nickname" to JSONObject.NULL, // not selected by the leaderboard SQL
                    "image_url" to MockWire.orNull(user?.imageUrl),
                    "score" to 0, // always 0 here
                    "normalized_score" to score,
                    "access_level" to 0, // always 0 here
                ),
            )
        }
        MockHttpResponse.json(rows)
    }

    api("GET", "/game/:id") { _, params, _, scenario ->
        val id = params["id"]?.toIntOrNull() ?: return@api MockHttpResponse.empty(500)
        if (id < 0) return@api MockHttpResponse.empty(400)
        val game = scenario.game(id) ?: return@api MockHttpResponse.empty(404)
        MockHttpResponse.json(MockWire.game(game))
    }

    api("PUT", "/game/:id") { request, params, _, scenario ->
        val id = params["id"]?.toIntOrNull() ?: return@api MockHttpResponse.empty(500)
        if (scenario.game(id) == null) return@api MockHttpResponse.empty(404)
        val body = request.bodyJson ?: JSONObject()
        // binding:"required" — a 0 (or missing) score is rejected with 400.
        val home = body.optIntOrNull("home_team_score")
        val away = body.optIntOrNull("away_team_score")
        if (home == null || home == 0 || away == null || away == 0) return@api MockHttpResponse.empty(400)
        scenario.updateGame(id) {
            it.homeTeamScore = home
            it.awayTeamScore = away
            it.updatedAt = Instant.now()
        }
        MockHttpResponse.nullBody()
    }

    api("POST", "/evaluategame") { request, _, _, scenario ->
        val body = request.bodyJson ?: JSONObject()
        val gameId = body.optIntOrNull("game_id")
        if (gameId == null || gameId <= 0) return@api MockHttpResponse.empty(400)
        val game = scenario.game(gameId) ?: return@api MockHttpResponse.empty(500)
        if (game.status == 1) return@api MockHttpResponse.empty(410) // already processed → Gone
        val home = body.optIntOrNull("home_team_score") ?: 0
        val away = body.optIntOrNull("away_team_score") ?: 0
        scenario.updateGame(gameId) {
            it.homeTeamScore = home
            it.awayTeamScore = away
            it.status = 1
            it.updatedAt = Instant.now()
        }
        val exactUserIds = ArrayList<String>()
        for (bet in scenario.bets.filter { it.gameId == gameId }) {
            val group = scenario.group(bet.groupId)
            val exact = bet.homeTeamScore == home && bet.awayTeamScore == away
            val correctSide = (bet.homeTeamScore > bet.awayTeamScore) == (home > away) &&
                (bet.homeTeamScore == bet.awayTeamScore) == (home == away)
            val points = when {
                exact -> group?.exactResultPoints ?: 3
                correctSide -> group?.correctTeamPoints ?: 1
                else -> 0
            }
            bet.userPoints = points
            bet.processedAt = Instant.now()
            scenario.updateMember(bet.groupId, bet.userId) {
                it.score += points
                it.normalizedScore += points.toDouble()
            }
            if (exact) exactUserIds.add(bet.userId)
        }
        pushEvent(
            "evaluate_game",
            JSONObject().apply {
                put("game_id", gameId)
                put("home_team_score", home)
                put("away_team_score", away)
            },
        )
        if (exactUserIds.isNotEmpty()) {
            pushEvent(
                "user_exact_score",
                JSONObject().apply {
                    put("game_id", gameId)
                    put("user_ids", JSONArray(exactUserIds))
                },
            )
        }
        MockHttpResponse.nullBody()
    }

    api("PUT", "/rollbackgame/:gameid") { _, params, uid, scenario ->
        if (scenario.user(uid)?.isAdmin != true) return@api MockHttpResponse.empty(401) // properly enforced
        val gameId = params["gameid"]?.toIntOrNull()
        if (gameId == null || scenario.game(gameId) == null) return@api MockHttpResponse.empty(500)
        scenario.updateGame(gameId) { it.status = null }
        for (bet in scenario.bets.filter { it.gameId == gameId }) {
            bet.userPoints = null
            bet.processedAt = null
        }
        MockHttpResponse.nullBody()
    }
}

// --- Reference data ------------------------------------------------------------

private fun BettyMockBackend.registerReferenceRoutes() {
    api("GET", "/teams") { _, _, _, scenario ->
        if (scenario.teams.isEmpty()) return@api MockHttpResponse.empty(404)
        val arr = JSONArray()
        scenario.teams.forEach { arr.put(MockWire.team(it)) }
        MockHttpResponse.json(arr)
    }
    api("GET", "/categories") { _, _, _, scenario ->
        if (scenario.categories.isEmpty()) return@api MockHttpResponse.empty(404)
        val arr = JSONArray()
        scenario.categories.forEach { arr.put(MockWire.category(it)) }
        MockHttpResponse.json(arr)
    }
    api("GET", "/arenas") { _, _, _, scenario ->
        val arr = JSONArray()
        scenario.arenas.forEach { arr.put(MockWire.arena(it)) }
        MockHttpResponse.json(arr)
    }
    api("GET", "/arenas/:country") { _, params, _, scenario ->
        val arr = JSONArray()
        scenario.arenas.filter { it.country == params["country"] }.forEach { arr.put(MockWire.arena(it)) }
        MockHttpResponse.json(arr)
    }
    api("GET", "/countries") { _, _, _, scenario ->
        val arr = JSONArray()
        scenario.countries.forEach { arr.put(MockWire.country(it)) }
        MockHttpResponse.json(arr)
    }
}

// --- Message board -------------------------------------------------------------

private fun BettyMockBackend.registerMessageBoardRoutes() {
    api("GET", "/messageboard/:groupid") { request, params, uid, scenario ->
        val groupId = params["groupid"]?.toIntOrNull()
        val group = groupId?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(400)
        // ANY membership status counts here (the check ignores status).
        if (group.member(uid) == null) return@api MockHttpResponse.empty(403)
        val amount = request.query["amount"]?.toIntOrNull() ?: 50
        val page = request.query["offset"]?.toIntOrNull() ?: 0 // PAGE INDEX
        val all = scenario.messages
            .filter { it.groupId == groupId && !it.deleted }
            .sortedByDescending { it.createdAt } // newest first
        val start = page * amount
        if (start >= all.size || amount <= 0) return@api MockHttpResponse.json(JSONArray())
        val slice = all.subList(start, minOf(start + amount, all.size))
        val arr = JSONArray()
        slice.forEach { arr.put(MockWire.message(it)) }
        MockHttpResponse.json(arr)
    }

    api("POST", "/messageboard") { request, _, uid, scenario ->
        val body = request.bodyJson ?: JSONObject()
        val groupId = body.optIntOrNull("group_id")
        val group = groupId?.let { scenario.group(it) } ?: return@api MockHttpResponse.empty(400)
        if (group.member(uid) == null) return@api MockHttpResponse.empty(403)
        val text = body.optStringOrNull("body")
        val imageUrl = body.optStringOrNull("image_url")
        if (text == null && imageUrl == null) return@api MockHttpResponse.empty(400)
        val message = MockMessage(id = scenario.nextMessageId, groupId = groupId, userId = uid, body = text, imageUrl = imageUrl)
        scenario.nextMessageId += 1
        scenario.messages.add(message)
        // 201, with "reactions": null (not attached on create).
        MockHttpResponse.json(MockWire.message(message, nullReactions = true), status = 201)
    }

    api("DELETE", "/messageboard/:id") { _, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val message = id?.let { mid -> scenario.messages.firstOrNull { it.id == mid } }
        if (message == null || message.userId != uid || message.deleted) return@api MockHttpResponse.empty(404)
        message.deleted = true
        MockHttpResponse.empty(204)
    }

    api("PUT", "/messageboard/:id/reaction") { request, params, uid, scenario ->
        val emoji = request.bodyJson?.optStringOrNull("emoji_id") ?: ""
        if (emoji.isEmpty() || emoji.length > 64) {
            return@api MockHttpResponse.json(jsonOf("error" to "emoji_id required, max 64 chars"), status = 400)
        }
        val id = params["id"]?.toIntOrNull()
        val message = id?.let { mid -> scenario.messages.firstOrNull { it.id == mid && !it.deleted } }
            ?: return@api MockHttpResponse.empty(404)
        if (scenario.group(message.groupId)?.member(uid) == null) return@api MockHttpResponse.empty(403)
        // One reaction per user per message (server-enforced upsert).
        message.reactions.removeAll { it.userId == uid }
        message.reactions.add(MockReaction(userId = uid, emojiId = emoji))
        MockHttpResponse.empty(204)
    }

    api("DELETE", "/messageboard/:id/reaction") { _, params, uid, scenario ->
        val id = params["id"]?.toIntOrNull()
        val message = id?.let { mid -> scenario.messages.firstOrNull { it.id == mid && !it.deleted } }
            ?: return@api MockHttpResponse.empty(404)
        if (scenario.group(message.groupId)?.member(uid) == null) return@api MockHttpResponse.empty(403)
        message.reactions.removeAll { it.userId == uid } // idempotent
        MockHttpResponse.empty(204)
    }
}

// --- Announcements & feature requests ------------------------------------------

private fun BettyMockBackend.registerAnnouncementRoutes() {
    api("GET", "/announcements") { _, _, _, scenario ->
        val arr = JSONArray()
        scenario.announcements.sortedByDescending { it.createdAt }.forEach { arr.put(MockWire.announcement(it)) }
        MockHttpResponse.json(arr)
    }

    api("POST", "/announcement") { request, _, uid, scenario ->
        if (scenario.user(uid)?.isAdmin != true) return@api MockHttpResponse.empty(403)
        val body = request.bodyJson ?: JSONObject()
        val title = body.optStringOrNull("title")
        val text = body.optStringOrNull("body")
        val category = body.optStringOrNull("category")
        if (title.isNullOrEmpty() || text.isNullOrEmpty() || category == null ||
            category !in listOf("info", "warning", "excitement", "important", "reminder")
        ) {
            return@api MockHttpResponse.empty(400)
        }
        val announcement = MockAnnouncement(
            id = scenario.nextAnnouncementId, userId = uid,
            title = title, body = text, category = category,
            cta = body.optStringOrNull("cta"),
        )
        scenario.nextAnnouncementId += 1
        scenario.announcements.add(announcement)
        MockHttpResponse.json(MockWire.announcement(announcement), status = 201)
    }

    api("POST", "/feature-requests") { request, _, uid, scenario ->
        val description = request.bodyJson?.optStringOrNull("description") ?: ""
        if (description.length !in 1..5000) return@api MockHttpResponse.empty(400)
        val id = scenario.nextFeatureRequestId
        scenario.nextFeatureRequestId += 1
        MockHttpResponse.json(
            jsonOf(
                "id" to id,
                "user_id" to uid,
                "description" to description,
                "created_at" to MockWire.time(Instant.now()),
            ),
            status = 201,
        )
    }
}

// --- Presigned upload plumbing -------------------------------------------------

/** Shared 415/413/400 validation for both upload-url endpoints. */
private fun BettyMockBackend.presign(request: MockHttpRequest, key: String): MockHttpResponse {
    val body = request.bodyJson ?: JSONObject()
    val contentType = body.optStringOrNull("content_type")
    val contentLength = body.optIntOrNull("content_length")
    if (contentType == null || contentLength == null || contentLength <= 0) return MockHttpResponse.empty(400)
    if (contentType !in ALLOWED_IMAGE_TYPES) return MockHttpResponse.empty(415)
    if (contentLength > (1 shl 20)) return MockHttpResponse.empty(413) // 1 MiB
    val ext = if (contentType == "image/jpeg") "jpg" else contentType.removePrefix("image/")
    return MockHttpResponse.json(
        MockWire.presignedUpload(
            key = "$key.$ext", httpBase = httpBase,
            contentType = contentType, contentLength = contentLength,
        ),
    )
}

/** The raw R2 PUT — outside the API base/bearer, accepts the presigned upload bytes. */
private fun BettyMockBackend.registerUploadCatchAll() {
    http.route("PUT", "/_upload/*") { _, _ -> MockHttpResponse.empty(200) }
    http.route("GET", "/_public/*") { _, _ ->
        MockHttpResponse(status = 200, headers = mapOf("Content-Type" to "image/png"), body = ByteArray(0))
    }
}
