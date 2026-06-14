package social.betty.core.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import social.betty.core.net.BettyJson

/** Pins the wire-contract quirks from docs/mobile/api-contract.md against the Kotlin models. */
class WireDecodingTest {

    @Test
    fun `user ignores the always-null PushTokens and maps snake_case`() {
        val json = """
            {"id":"uid-1","email":"a@b.c","name":"Ada","image_url":null,
             "firebase_image_url":"https://x/p.png","country":"SE","is_admin":true,
             "created_at":"2026-06-07T12:34:56Z","updated_at":"2026-06-07T12:34:56Z","PushTokens":null}
        """.trimIndent()
        val user = BettyJson.decodeFromString<UserProfile>(json)
        assertEquals("uid-1", user.id)
        assertEquals("Ada", user.name)
        assertTrue(user.isAdmin)
        assertEquals("SE", user.country)
        assertNull(user.imageUrl)
        assertEquals("https://x/p.png", user.firebaseImageUrl)
    }

    @Test
    fun `group coerces null members to empty and derives isPublic from public_at`() {
        val privateGroup = BettyJson.decodeFromString<Group>(
            """{"id":1,"name":"G","tournament_id":7,"invite_code":"abc","is_public":false,
                "public_at":null,"members":null}""",
        )
        assertTrue(privateGroup.members.isEmpty())
        assertFalse(privateGroup.isPublic)

        val publicGroup = BettyJson.decodeFromString<Group>(
            """{"id":2,"name":"G2","tournament_id":7,"invite_code":"abc","is_public":false,
                "public_at":"2026-06-01T00:00:00Z","members":[
                  {"user_id":"u1","name":"One","score":5,"access_level":0}]}""",
        )
        assertTrue("public_at present => public", publicGroup.isPublic)
        assertEquals("u1", publicGroup.members.first().userId)
        assertEquals(0, publicGroup.members.first().accessLevel)
    }

    @Test
    fun `group defaults booster fields to 0 and 2 when missing on the wire`() {
        // Pre-feature backend won't return boost_count / boost_multiplier — must still decode.
        val group = BettyJson.decodeFromString<Group>(
            """{"id":1,"name":"G","tournament_id":7,"invite_code":"abc","is_public":false,
                "public_at":null,"members":null}""",
        )
        assertEquals(0, group.boostCount)
        assertEquals(2, group.boostMultiplier)
    }

    @Test
    fun `group decodes booster fields when present`() {
        val group = BettyJson.decodeFromString<Group>(
            """{"id":1,"name":"G","tournament_id":7,"invite_code":"abc","is_public":false,
                "public_at":null,"boost_count":3,"boost_multiplier":5,"members":null}""",
        )
        assertEquals(3, group.boostCount)
        assertEquals(5, group.boostMultiplier)
    }

    @Test
    fun `public group item decodes booster fields and defaults when missing`() {
        val withFields = BettyJson.decodeFromString<PublicGroupItem>(
            """{"id":1,"name":"P","tournament_id":7,"boost_count":2,"boost_multiplier":4}""",
        )
        assertEquals(2, withFields.boostCount)
        assertEquals(4, withFields.boostMultiplier)

        val missing = BettyJson.decodeFromString<PublicGroupItem>(
            """{"id":1,"name":"P","tournament_id":7}""",
        )
        assertEquals(0, missing.boostCount)
        assertEquals(2, missing.boostMultiplier)
    }

    @Test
    fun `tournament detail keeps flat pools and games - status is nullable`() {
        val t = BettyJson.decodeFromString<Tournament>(
            """{"id":1,"name":"T","start_date":"2026-06-01T00:00:00Z","end_date":"2026-06-30T00:00:00Z",
                "pools":[{"id":1,"tournament_id":1,"name":"A"}],
                "games":[
                  {"id":10,"pool_id":1,"home_team_id":1,"away_team_id":2,"home_team_score":2,
                   "away_team_score":1,"start_date":"2026-06-02T18:00:00Z","status":1},
                  {"id":11,"pool_id":1,"home_team_id":3,"away_team_id":4,"home_team_score":0,
                   "away_team_score":0,"start_date":"2026-06-03T18:00:00Z","status":null}]}""",
        )
        assertEquals(1, t.pools.size)
        assertEquals(2, t.games.size)
        assertTrue(t.games[0].isFinished)
        assertFalse(t.games[1].isFinished)
        assertNull(t.games[1].status)
    }

    @Test
    fun `bet user_points is nullable until evaluated`() {
        val bet = BettyJson.decodeFromString<Bet>(
            """{"id":0,"user_id":"me","game_id":10,"group_id":1,"user_points":null,
                "home_team_score":2,"away_team_score":1,"is_universal":false,"processed_at":null}""",
        )
        assertNull(bet.userPoints)
        assertFalse(bet.isProcessed)
        assertEquals("me", bet.userId)
        // Missing boosted on a pre-feature response defaults to false.
        assertFalse(bet.boosted)
    }

    @Test
    fun `bet decodes boosted flag when present`() {
        val bet = BettyJson.decodeFromString<Bet>(
            """{"id":7,"user_id":"me","game_id":10,"group_id":1,"user_points":4,
                "home_team_score":2,"away_team_score":1,"is_universal":false,
                "boosted":true,"processed_at":null}""",
        )
        assertTrue(bet.boosted)
        assertEquals(4, bet.userPoints)
    }

    @Test
    fun `message reactions decode as empty when null (POST echo) and as list when present`() {
        val created = BettyJson.decodeFromString<GroupMessage>(
            """{"id":1,"group_id":1,"user_id":"me","body":"gg","image_url":null,
                "created_at":"2026-06-07T12:00:00Z","reactions":null}""",
        )
        assertTrue(created.reactions.isEmpty())

        val fetched = BettyJson.decodeFromString<GroupMessage>(
            """{"id":2,"group_id":1,"user_id":"me","body":"yo",
                "created_at":"2026-06-07T12:00:00Z","reactions":[
                  {"user_id":"u2","emoji_id":"fire","created_at":"2026-06-07T12:01:00Z"}]}""",
        )
        assertEquals("fire", fetched.reactions.first().emojiId)
    }

    @Test
    fun `public group list coerces missing items to empty`() {
        val empty = BettyJson.decodeFromString<PublicGroupListResponse>("""{"items":null,"next_cursor":""}""")
        assertTrue(empty.items.isEmpty())
        assertEquals("", empty.nextCursor)
    }
}
