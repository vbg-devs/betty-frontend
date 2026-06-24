package social.betty.mock

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.format.DateTimeFormatter

/**
 * Serializes scenario entities to the EXACT Betty wire format (api-contract.md): snake_case
 * keys, RFC 3339 UTC times, Go zero time `0001-01-01T00:00:00Z`, the `PushTokens: null` quirk,
 * `is_public` always false on reads, `mode` vs `bet_mode` naming, flat sibling `pools[]`/`games[]`,
 * nullable `Game.status`. JSON key order is irrelevant — the client decodes with kotlinx.serialization.
 */
object MockWire {
    const val ZERO_TIME = "0001-01-01T00:00:00Z"

    /** RFC 3339 UTC, e.g. `2026-06-07T12:34:56Z` (the client parses with `Instant.parse`). */
    fun time(date: Instant): String = DateTimeFormatter.ISO_INSTANT.format(date)

    /** RFC 3339 time or [JSONObject.NULL] for a missing date. */
    fun time(date: Instant?): Any = date?.let { time(it) } ?: JSONObject.NULL

    /** A value or [JSONObject.NULL] for null (org.json drops keys whose value is a raw null). */
    fun orNull(value: Any?): Any = value ?: JSONObject.NULL

    fun parseTime(raw: Any?): Instant? {
        val string = raw as? String ?: return null
        if (string.isBlank()) return null
        return runCatching { Instant.parse(string) }.getOrNull()
            ?: runCatching { java.time.OffsetDateTime.parse(string).toInstant() }.getOrNull()
    }

    /** Builds a [JSONObject], coercing Kotlin `null` values to [JSONObject.NULL]. */
    private fun obj(vararg pairs: Pair<String, Any?>): JSONObject {
        val json = JSONObject()
        for ((key, value) in pairs) {
            json.put(key, value ?: JSONObject.NULL)
        }
        return json
    }

    private fun <T> array(items: List<T>, transform: (T) -> Any): JSONArray {
        val arr = JSONArray()
        for (item in items) arr.put(transform(item))
        return arr
    }

    // --- Users ----------------------------------------------------------------

    fun user(u: MockUser, zeroTimestamps: Boolean = false): JSONObject = obj(
        "id" to u.id,
        "email" to u.email,
        "name" to u.name,
        "image_url" to orNull(u.imageUrl),
        "firebase_image_url" to orNull(u.firebaseImageUrl),
        "country" to orNull(u.country),
        "created_at" to if (zeroTimestamps) ZERO_TIME else time(u.createdAt),
        "updated_at" to if (zeroTimestamps) ZERO_TIME else time(u.createdAt),
        "is_admin" to if (zeroTimestamps) false else u.isAdmin,
        "PushTokens" to JSONObject.NULL,
    )

    // --- Groups ---------------------------------------------------------------

    fun member(m: MockMember, scenario: MockScenario): JSONObject {
        val user = scenario.user(m.userId)
        return obj(
            "user_id" to m.userId,
            "name" to orNull(user?.name),
            "nickname" to orNull(m.nickname),
            "image_url" to orNull(user?.imageUrl),
            "score" to m.score,
            "normalized_score" to m.normalizedScore,
            "access_level" to m.accessLevel,
        )
    }

    fun group(g: MockGroup, scenario: MockScenario): JSONObject {
        val tournament = scenario.tournament(g.tournamentId)
        return obj(
            "id" to g.id,
            "name" to g.name,
            "tournament_id" to g.tournamentId,
            "tournament_name" to (tournament?.name ?: ""),
            "tournament_image_url" to orNull(tournament?.imageUrl),
            "header_image_url" to orNull(g.headerImageUrl),
            "invite_code" to g.inviteCode,
            "invite_url" to "https://betty.social/dashboard/groups/join/${g.inviteCode}",
            "welcome_message" to orNull(g.welcomeMessage),
            "description" to orNull(g.description),
            "correct_team_points" to g.correctTeamPoints,
            "exact_result_points" to g.exactResultPoints,
            "allow_sneak_peek" to g.allowSneakPeek,
            "group_play_deadline" to time(g.groupPlayDeadline),
            "mode" to g.mode,
            "boost_count" to g.boostCount,
            "boost_multiplier" to g.boostMultiplier,
            "is_public" to false, // db:"-" — ALWAYS false on reads; derive from public_at
            "public_at" to time(g.publicAt),
            "created_at" to time(g.createdAt),
            "updated_at" to time(g.updatedAt),
            "members" to array(g.members.filter { it.status == MembershipStatus.ACTIVE }) { member(it, scenario) },
        )
    }

    /** `GET /user/:id/groups` row — 1-based standard competition ranking by score. */
    fun placement(g: MockGroup, m: MockMember, scenario: MockScenario): JSONObject {
        val active = g.members.filter { it.status == MembershipStatus.ACTIVE }
        val rank = 1 + active.count { it.score > m.score }
        val tournament = scenario.tournament(g.tournamentId)
        return obj(
            "id" to g.id,
            "name" to g.name,
            "tournament_id" to g.tournamentId,
            "tournament_name" to (tournament?.name ?: ""),
            "tournament_image_url" to orNull(tournament?.imageUrl),
            "header_image_url" to orNull(g.headerImageUrl),
            "bet_mode" to g.mode, // named bet_mode HERE, mode on Group
            "public_at" to time(g.publicAt),
            "created_at" to time(g.createdAt),
            "score" to m.score,
            "normalized_score" to m.normalizedScore,
            "placement" to rank,
            "member_count" to active.size,
        )
    }

    fun publicGroupItem(g: MockGroup, callerId: String, scenario: MockScenario): JSONObject {
        val tournament = scenario.tournament(g.tournamentId)
        return obj(
            "id" to g.id,
            "name" to g.name,
            "description" to orNull(g.description),
            "tournament_id" to g.tournamentId,
            "tournament_name" to (tournament?.name ?: ""),
            "tournament_image_url" to orNull(tournament?.imageUrl),
            "header_image_url" to orNull(g.headerImageUrl),
            "correct_team_points" to g.correctTeamPoints,
            "exact_result_points" to g.exactResultPoints,
            "allow_sneak_peek" to g.allowSneakPeek,
            "bet_mode" to g.mode,
            "boost_count" to g.boostCount,
            "boost_multiplier" to g.boostMultiplier,
            "group_play_deadline" to time(g.groupPlayDeadline),
            "public_at" to time(g.publicAt ?: Instant.now()),
            "created_at" to time(g.createdAt),
            "member_count" to g.members.count { it.status == MembershipStatus.ACTIVE },
            "is_member" to g.isActiveMember(callerId),
        )
    }

    fun groupPeek(g: MockGroup, scenario: MockScenario): JSONObject {
        val tournament = scenario.tournament(g.tournamentId)
        return obj(
            "id" to g.id,
            "name" to g.name,
            "description" to orNull(g.description),
            "tournament_id" to g.tournamentId,
            "tournament_name" to (tournament?.name ?: ""),
            "tournament_image_url" to orNull(tournament?.imageUrl),
            "header_image_url" to orNull(g.headerImageUrl),
            "invite_code" to g.inviteCode,
        )
    }

    // --- Bets -----------------------------------------------------------------

    fun bet(b: MockBet): JSONObject = obj(
        "id" to b.id,
        "user_id" to b.userId,
        "game_id" to b.gameId,
        "group_id" to b.groupId,
        "user_points" to orNull(b.userPoints),
        "home_team_score" to b.homeTeamScore,
        "away_team_score" to b.awayTeamScore,
        "is_universal" to false, // request-only flag — never stored
        "boosted" to b.boosted,
        "processed_at" to time(b.processedAt),
        "created_at" to time(b.createdAt),
        "updated_at" to time(b.updatedAt),
    )

    /** The `POST /bet` 200 body: a request echo with `id: 0` and zero timestamps. */
    fun betEcho(
        userId: String,
        gameId: Int,
        groupId: Int,
        home: Int,
        away: Int,
        isUniversal: Boolean,
        boosted: Boolean = false,
    ): JSONObject = obj(
        "id" to 0,
        "user_id" to userId,
        "game_id" to gameId,
        "group_id" to groupId,
        "user_points" to JSONObject.NULL,
        "home_team_score" to home,
        "away_team_score" to away,
        "is_universal" to isUniversal,
        "boosted" to boosted,
        "processed_at" to JSONObject.NULL,
        "created_at" to ZERO_TIME,
        "updated_at" to ZERO_TIME,
    )

    // --- Tournaments ----------------------------------------------------------

    fun pool(p: MockPool): JSONObject = obj(
        "id" to p.id,
        "tournament_id" to p.tournamentId,
        "name" to p.name,
    )

    fun game(g: MockGame): JSONObject = obj(
        "id" to g.id,
        "tournament_id" to g.tournamentId,
        "pool_id" to g.poolId,
        "home_team_id" to g.homeTeamId,
        "away_team_id" to g.awayTeamId,
        "home_team_score" to g.homeTeamScore, // non-null ints, always present
        "away_team_score" to g.awayTeamScore,
        "start_date" to time(g.startDate),
        "updated_at" to time(g.updatedAt),
        "status" to orNull(g.status), // int|null
    )

    /**
     * `details: false` → list shape (`pools`/`games` are null);
     * `details: true` → FLAT sibling `pools[]` + `games[]` (games by start_date).
     */
    fun tournament(t: MockTournament, details: Boolean): JSONObject = obj(
        "id" to t.id,
        "name" to t.name,
        "image_url" to orNull(t.imageUrl),
        "start_date" to time(t.startDate),
        "end_date" to time(t.endDate),
        "category_id" to t.categoryId,
        "pools" to if (details) array(t.pools) { pool(it) } else JSONObject.NULL,
        "games" to if (details) {
            array(t.games.sortedBy { it.startDate }) { game(it) }
        } else {
            JSONObject.NULL
        },
    )

    // --- Reference data -------------------------------------------------------

    fun team(t: MockTeam): JSONObject = obj(
        "id" to t.id,
        "tournament_id" to t.tournamentId,
        "image_url" to orNull(t.imageUrl),
        "name" to t.name,
        "is_placeholder" to t.isPlaceholder,
    )

    fun category(c: MockCategory): JSONObject = obj("id" to c.id, "name" to c.name)

    fun country(c: MockCountry): JSONObject = obj(
        "code" to c.code,
        "name" to c.name,
        "flag_emoji" to orNull(c.flagEmoji),
    )

    fun arena(a: MockArena): JSONObject = obj(
        "id" to a.id,
        "name" to a.name,
        "country" to a.country,
        "city" to a.city,
        "capacity" to a.capacity,
        "image_url" to a.imageUrl,
    )

    // --- Message board --------------------------------------------------------

    fun reaction(r: MockReaction): JSONObject = obj(
        "user_id" to r.userId,
        "emoji_id" to r.emojiId,
        "created_at" to time(r.createdAt),
    )

    /** `reactions` is `[]` on GET but the literal `null` in the POST 201 echo. */
    fun message(m: MockMessage, nullReactions: Boolean = false): JSONObject = obj(
        "id" to m.id,
        "group_id" to m.groupId,
        "user_id" to m.userId,
        "image_url" to orNull(m.imageUrl),
        "body" to orNull(m.body),
        "created_at" to time(m.createdAt),
        "reactions" to if (nullReactions) JSONObject.NULL else array(m.reactions) { reaction(it) },
    )

    // --- Announcements --------------------------------------------------------

    fun announcement(a: MockAnnouncement): JSONObject {
        val json = obj(
            "id" to a.id,
            "user_id" to a.userId,
            "title" to a.title,
            "body" to a.body,
            "category" to a.category,
            "created_at" to time(a.createdAt),
        )
        if (a.cta != null) json.put("cta", a.cta) // omitempty
        return json
    }

    // --- Presigned uploads ----------------------------------------------------

    fun presignedUpload(key: String, httpBase: String, contentType: String, contentLength: Int): JSONObject {
        val headers = JSONObject()
        headers.put("Content-Length", JSONArray(listOf(contentLength.toString())))
        headers.put("Content-Type", JSONArray(listOf(contentType)))
        return obj(
            "key" to key,
            "upload_url" to "$httpBase/_upload/$key",
            "method" to "PUT",
            // Go http.Header — map of string → ARRAY of strings.
            "headers" to headers,
            "public_url" to "$httpBase/_public/$key",
            "expires_at" to time(Instant.now().plusSeconds(300)),
        )
    }

    // --- Firebase identity ----------------------------------------------------

    fun firebaseError(message: String): MockHttpResponse {
        val error = JSONObject()
        error.put("code", 400)
        error.put("message", message)
        error.put(
            "errors",
            JSONArray(
                listOf(
                    JSONObject(mapOf("message" to message, "domain" to "global", "reason" to "invalid")),
                ),
            ),
        )
        val root = JSONObject()
        root.put("error", error)
        return MockHttpResponse.json(root, status = 400)
    }
}
