package social.betty.core.net

import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import social.betty.core.model.Bet
import social.betty.core.model.Country
import social.betty.core.model.FeatureRequest
import social.betty.core.model.Group
import social.betty.core.model.GroupIdResponse
import social.betty.core.model.GroupMember
import social.betty.core.model.GroupPeek
import social.betty.core.model.GroupMessage
import social.betty.core.model.HeaderImageUrlResponse
import social.betty.core.model.ImageUrlResponse
import social.betty.core.model.NicknameResponse
import social.betty.core.model.PresignedUpload
import social.betty.core.model.PublicAtResponse
import social.betty.core.model.PublicGroupListResponse
import social.betty.core.model.Team
import social.betty.core.model.Tournament
import social.betty.core.model.UserGroupsResponse
import social.betty.core.model.UserProfile
import java.time.Instant

/**
 * Typed Betty REST surface (api-contract.md §3). Every method throws [ApiError.Status] on a
 * non-2xx response (feature code branches on the documented status codes) and
 * [ApiError.Decoding]/[ApiError.Network]/[ApiError.NotAuthenticated] otherwise.
 */
class BettyApi(val client: ApiClient) {

    private inline fun <reified T> decode(resp: ApiResponse): T {
        if (!resp.isSuccess) throw client.statusError(resp)
        return try {
            client.json.decodeFromString<T>(resp.bodyString)
        } catch (e: Exception) {
            throw ApiError.Decoding(e)
        }
    }

    private fun ensureSuccess(resp: ApiResponse) {
        if (!resp.isSuccess) throw client.statusError(resp)
    }

    // ---- Users ---------------------------------------------------------------

    /** 404 ⇒ authenticated but no profile yet (trigger onboarding). */
    suspend fun getUserMe(): UserProfile = decode(client.execute("GET", "/user/me"))

    suspend fun createUser(email: String, name: String, imageUrl: String?): UserProfile {
        val body = buildJsonObject {
            put("email", email)
            put("name", name)
            if (imageUrl != null) put("image_url", imageUrl)
        }
        return decode(client.execute("POST", "/user", jsonBody = body.toString()))
    }

    suspend fun updateUserMe(name: String, country: String?): UserProfile {
        val body = buildJsonObject {
            put("name", name)
            put("country", country)
        }
        return decode(client.execute("PUT", "/user/me", jsonBody = body.toString()))
    }

    suspend fun deleteUserMe() = ensureSuccess(client.execute("DELETE", "/user/me"))

    suspend fun addPushToken(token: String) {
        val body = buildJsonObject { put("token", token) }
        ensureSuccess(client.execute("POST", "/user/me/add_push_token", jsonBody = body.toString()))
    }

    suspend fun getCountries(): List<Country> = decode(client.execute("GET", "/countries"))

    suspend fun profileImageUploadUrl(contentType: String, contentLength: Long): PresignedUpload {
        val body = buildJsonObject {
            put("content_type", contentType)
            put("content_length", contentLength)
        }
        return decode(client.execute("POST", "/user/me/profile-image/upload-url", jsonBody = body.toString()))
    }

    suspend fun commitProfileImage(imageUrl: String): String? {
        val body = buildJsonObject { put("image_url", imageUrl) }
        return decode<ImageUrlResponse>(client.execute("PUT", "/user/me/profile-image", jsonBody = body.toString())).imageUrl
    }

    suspend fun deleteProfileImage(): String? =
        decode<ImageUrlResponse>(client.execute("DELETE", "/user/me/profile-image")).imageUrl

    // ---- Groups --------------------------------------------------------------

    suspend fun getGroups(): List<Group> = decode(client.execute("GET", "/groups"))

    suspend fun getGroupById(id: Int): Group = decode(client.execute("GET", "/groupbyid/$id"))

    suspend fun getUserGroups(uid: String): UserGroupsResponse =
        decode(client.execute("GET", "/user/$uid/groups"))

    suspend fun createGroup(
        name: String,
        tournamentId: Int,
        correctTeamPoints: Int,
        exactResultPoints: Int,
        allowSneakPeek: Boolean,
        groupPlayDeadline: Instant?,
        welcomeMessage: String?,
        description: String?,
        isPublic: Boolean,
    ): Int {
        val body = buildJsonObject {
            put("name", name)
            put("tournament_id", tournamentId)
            put("correct_team_points", correctTeamPoints)
            put("exact_result_points", exactResultPoints)
            put("allow_sneak_peek", allowSneakPeek)
            put("group_play_deadline", groupPlayDeadline?.toString())
            put("welcome_message", welcomeMessage)
            put("description", description)
            put("is_public", isPublic)
            put("mode", 0)
        }
        return decode<GroupIdResponse>(client.execute("POST", "/group", jsonBody = body.toString())).groupId
    }

    suspend fun joinByCode(code: String): Int =
        decode<GroupIdResponse>(client.execute("POST", "/join/$code", jsonBody = "{}")).groupId

    suspend fun getGroupByCode(code: String): GroupPeek =
        decode(client.execute("GET", "/group/$code"))

    suspend fun joinPublicGroup(id: Int): Int =
        decode<GroupIdResponse>(client.execute("POST", "/group/$id/join", jsonBody = "{}")).groupId

    suspend fun listPublicGroups(
        cursor: String?,
        q: String?,
        tournamentId: Int?,
        limit: Int?,
    ): PublicGroupListResponse {
        val query = buildMap<String, String?> {
            if (!cursor.isNullOrEmpty()) put("cursor", cursor)
            if (!q.isNullOrEmpty()) put("q", q)
            if (tournamentId != null) put("tournament_id", tournamentId.toString())
            if (limit != null) put("limit", limit.toString())
        }
        return decode(client.execute("GET", "/groups/public", query = query))
    }

    suspend fun leaveGroup(id: Int) = ensureSuccess(client.execute("DELETE", "/group/$id/leave"))

    suspend fun setVisibility(id: Int, isPublic: Boolean): Instant? {
        val body = buildJsonObject { put("is_public", isPublic) }
        return decode<PublicAtResponse>(client.execute("PUT", "/group/$id/visibility", jsonBody = body.toString())).publicAt
    }

    suspend fun updateGroupSettings(
        id: Int,
        welcomeMessage: String?,
        description: String?,
        correctTeamPoints: Int,
        exactResultPoints: Int,
        allowSneakPeek: Boolean,
    ): Group {
        val body = buildJsonObject {
            put("welcome_message", welcomeMessage)
            put("description", description)
            put("correct_team_points", correctTeamPoints)
            put("exact_result_points", exactResultPoints)
            put("allow_sneak_peek", allowSneakPeek)
        }
        return decode(client.execute("PUT", "/group/$id/settings", jsonBody = body.toString()))
    }

    suspend fun setNickname(id: Int, nickname: String?): String? {
        val body = buildJsonObject {
            if (nickname == null) put("nickname", JsonNull) else put("nickname", nickname)
        }
        return decode<NicknameResponse>(client.execute("PUT", "/group/$id/nickname", jsonBody = body.toString())).nickname
    }

    suspend fun headerImageUploadUrl(id: Int, contentType: String, contentLength: Long): PresignedUpload {
        val body = buildJsonObject {
            put("content_type", contentType)
            put("content_length", contentLength)
        }
        return decode(client.execute("POST", "/group/$id/header-image/upload-url", jsonBody = body.toString()))
    }

    suspend fun commitHeaderImage(id: Int, url: String): String? {
        val body = buildJsonObject { put("header_image_url", url) }
        return decode<HeaderImageUrlResponse>(client.execute("PUT", "/group/$id/header-image", jsonBody = body.toString())).headerImageUrl
    }

    suspend fun deleteHeaderImage(id: Int) = ensureSuccess(client.execute("DELETE", "/group/$id/header-image"))

    // ---- Bets ----------------------------------------------------------------

    suspend fun getBetsByGroup(groupId: Int): List<Bet> = decode(client.execute("GET", "/bets/bygroup/$groupId"))

    /** Dedupe by id — the SQL join fans out rows for users in multiple groups. */
    suspend fun getBetsByGame(gameId: Int, groupId: Int): List<Bet> =
        decode<List<Bet>>(client.execute("GET", "/bets/bygame/$gameId/$groupId")).distinctBy { it.id }

    suspend fun placeBet(gameId: Int, groupId: Int, home: Int, away: Int, isUniversal: Boolean): Bet {
        val body = buildJsonObject {
            put("game_id", gameId)
            put("group_id", groupId)
            put("home_team_score", home)
            put("away_team_score", away)
            put("is_universal", isUniversal)
        }
        return decode(client.execute("POST", "/bet", jsonBody = body.toString()))
    }

    suspend fun updateBet(id: Int, home: Int, away: Int): Bet {
        val body = buildJsonObject {
            put("home_team_score", home)
            put("away_team_score", away)
        }
        return decode(client.execute("PUT", "/bet/$id", jsonBody = body.toString()))
    }

    // ---- Tournaments & games -------------------------------------------------

    suspend fun getTournaments(): List<Tournament> = decode(client.execute("GET", "/tournaments"))

    /** 404 when the tournament doesn't exist OR has already ended. */
    suspend fun getTournament(id: Int): Tournament = decode(client.execute("GET", "/tournament/$id"))

    suspend fun getTournamentLeaderboard(id: Int, limit: Int = 100): List<GroupMember> =
        decode(client.execute("GET", "/tournament/$id/leaderboard", query = mapOf("limit" to limit.toString())))

    suspend fun evaluateGame(gameId: Int, home: Int, away: Int) {
        val body = buildJsonObject {
            put("game_id", gameId)
            put("home_team_score", home)
            put("away_team_score", away)
        }
        ensureSuccess(client.execute("POST", "/evaluategame", jsonBody = body.toString()))
    }

    // ---- Reference -----------------------------------------------------------

    suspend fun getTeams(): List<Team> = decode(client.execute("GET", "/teams"))

    // ---- Message board -------------------------------------------------------

    suspend fun getMessages(groupId: Int, amount: Int = 50, offset: Int = 0): List<GroupMessage> =
        decode(client.execute("GET", "/messageboard/$groupId", query = mapOf("amount" to amount.toString(), "offset" to offset.toString())))

    suspend fun postMessage(groupId: Int, body: String?, imageUrl: String?): GroupMessage {
        val json = buildJsonObject {
            put("group_id", groupId)
            put("body", body)
            put("image_url", imageUrl)
        }
        return decode(client.execute("POST", "/messageboard", jsonBody = json.toString()))
    }

    suspend fun deleteMessage(id: Int) = ensureSuccess(client.execute("DELETE", "/messageboard/$id"))

    suspend fun putReaction(id: Int, emojiId: String) {
        val body = buildJsonObject { put("emoji_id", emojiId) }
        ensureSuccess(client.execute("PUT", "/messageboard/$id/reaction", jsonBody = body.toString()))
    }

    suspend fun deleteReaction(id: Int) = ensureSuccess(client.execute("DELETE", "/messageboard/$id/reaction"))

    // ---- Feature requests ----------------------------------------------------

    suspend fun postFeatureRequest(description: String): FeatureRequest {
        val body = buildJsonObject { put("description", description) }
        return decode(client.execute("POST", "/feature-requests", jsonBody = body.toString()))
    }
}
