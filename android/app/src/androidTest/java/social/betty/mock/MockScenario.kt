package social.betty.mock

import java.time.Instant

// Programmatic fixture state for the mock backend. The wire shapes these entities
// serialize to live in MockWire.kt and follow docs/mobile/api-contract.md exactly
// (string Firebase-UID user ids, nullable Game.status, flat pools[]/games[], ...).

enum class MembershipStatus { ACTIVE, LEFT, BLOCKED }

data class MockUser(
    var id: String,
    var email: String,
    var name: String,
    /** Only used by the mock identity endpoints (signInWithPassword). */
    var password: String? = null,
    var imageUrl: String? = null,
    var firebaseImageUrl: String? = null,
    var country: String? = null,
    var isAdmin: Boolean = false,
    /** `GET /user/me` 404s (onboarding gate) until the profile row exists. */
    var hasProfile: Boolean = true,
    var createdAt: Instant = Instant.now(),
)

data class MockMember(
    var userId: String,
    var nickname: String? = null,
    var score: Int = 0,
    var normalizedScore: Double = 0.0,
    /** 0 author, 1 admin, 2 participant. */
    var accessLevel: Int = 2,
    var status: MembershipStatus = MembershipStatus.ACTIVE,
)

data class MockGroup(
    var id: Int,
    var name: String,
    var tournamentId: Int,
    var inviteCode: String,
    var headerImageUrl: String? = null,
    var welcomeMessage: String? = null,
    var description: String? = null,
    var correctTeamPoints: Int = 1,
    var exactResultPoints: Int = 3,
    var allowSneakPeek: Boolean = true,
    var groupPlayDeadline: Instant? = null,
    var mode: Int = 0,
    /** Booster cap per user — 0 = boosters disabled (Boosters spec §1.1). Default 0. */
    var boostCount: Int = 0,
    /** Booster multiplier — ignored when [boostCount] == 0. Default 2. */
    var boostMultiplier: Int = 2,
    var publicAt: Instant? = null,
    var createdAt: Instant = Instant.now(),
    var updatedAt: Instant = Instant.now(),
    var members: MutableList<MockMember> = mutableListOf(),
) {
    fun member(userId: String): MockMember? = members.firstOrNull { it.userId == userId }

    fun isActiveMember(userId: String): Boolean = member(userId)?.status == MembershipStatus.ACTIVE

    fun isAuthor(userId: String): Boolean =
        member(userId)?.let { it.accessLevel == 0 && it.status == MembershipStatus.ACTIVE } ?: false
}

data class MockPool(
    var id: Int,
    var tournamentId: Int,
    var name: String,
)

data class MockGame(
    var id: Int,
    var tournamentId: Int,
    var poolId: Int,
    var homeTeamId: Int,
    var awayTeamId: Int,
    var homeTeamScore: Int = 0,
    var awayTeamScore: Int = 0,
    var startDate: Instant,
    var updatedAt: Instant? = null,
    /** null = not final, 1 = finished (matches the nullable wire int). */
    var status: Int? = null,
)

data class MockTournament(
    var id: Int,
    var name: String,
    var imageUrl: String? = null,
    var startDate: Instant,
    var endDate: Instant,
    var categoryId: Int = 1,
    var pools: MutableList<MockPool> = mutableListOf(),
    var games: MutableList<MockGame> = mutableListOf(),
) {
    fun hasEnded(now: Instant = Instant.now()): Boolean = !endDate.isAfter(now)
}

data class MockTeam(
    var id: Int,
    var tournamentId: Int,
    var name: String,
    var imageUrl: String? = null,
    var isPlaceholder: Boolean = false,
)

data class MockBet(
    var id: Int,
    var userId: String,
    var gameId: Int,
    var groupId: Int,
    var userPoints: Int? = null,
    var homeTeamScore: Int,
    var awayTeamScore: Int,
    /** Booster flag (Boosters spec §1.2). Defaults to false. */
    var boosted: Boolean = false,
    var processedAt: Instant? = null,
    var createdAt: Instant = Instant.now(),
    var updatedAt: Instant = Instant.now(),
)

data class MockReaction(
    var userId: String,
    var emojiId: String,
    var createdAt: Instant = Instant.now(),
)

data class MockMessage(
    var id: Int,
    var groupId: Int,
    var userId: String,
    var body: String? = null,
    var imageUrl: String? = null,
    var createdAt: Instant = Instant.now(),
    var reactions: MutableList<MockReaction> = mutableListOf(),
    var deleted: Boolean = false,
)

data class MockAnnouncement(
    var id: Int,
    var userId: String,
    var title: String,
    var body: String,
    var category: String,
    var cta: String? = null,
    var createdAt: Instant = Instant.now(),
)

data class MockCategory(
    var id: Int,
    var name: String,
)

data class MockCountry(
    var code: String,
    var name: String,
    var flagEmoji: String? = null,
)

data class MockArena(
    var id: Int,
    var name: String,
    var country: String,
    var city: String,
    var capacity: Int,
    var imageUrl: String,
)

/**
 * The whole mock-backend state. Routes resolve from it, mutations (POST /bet, join, message,
 * ...) write back into it, so subsequent GETs reflect every change. Mutated only inside the
 * backend's scenario lock.
 */
class MockScenario {
    val users: MutableList<MockUser> = mutableListOf()
    val groups: MutableList<MockGroup> = mutableListOf()
    val tournaments: MutableList<MockTournament> = mutableListOf()
    val teams: MutableList<MockTeam> = mutableListOf()
    val bets: MutableList<MockBet> = mutableListOf()
    val messages: MutableList<MockMessage> = mutableListOf()
    val announcements: MutableList<MockAnnouncement> = mutableListOf()
    val categories: MutableList<MockCategory> = mutableListOf()
    val countries: MutableList<MockCountry> = mutableListOf()
    val arenas: MutableList<MockArena> = mutableListOf()

    /** `accounts:signInWithIdp` signs in this user (defaults to the first user). */
    var idpUserId: String? = null

    /** When true, signInWithIdp answers `needConfirmation: true` (no tokens). */
    var idpNeedsConfirmation: Boolean = false

    var nextGroupId: Int = 1000
    var nextBetId: Int = 1000
    var nextMessageId: Int = 1000
    var nextAnnouncementId: Int = 1000
    var nextFeatureRequestId: Int = 1000
    var nextSignupNumber: Int = 1

    // --- Lookups --------------------------------------------------------------

    fun user(id: String): MockUser? = users.firstOrNull { it.id == id }

    fun userByEmail(email: String): MockUser? = users.firstOrNull { it.email.equals(email, ignoreCase = true) }

    fun group(id: Int): MockGroup? = groups.firstOrNull { it.id == id }

    fun groupByCode(code: String): MockGroup? = groups.firstOrNull { it.inviteCode == code }

    fun tournament(id: Int): MockTournament? = tournaments.firstOrNull { it.id == id }

    fun game(id: Int): MockGame? {
        for (tournament in tournaments) {
            tournament.games.firstOrNull { it.id == id }?.let { return it }
        }
        return null
    }

    // --- Mutations ------------------------------------------------------------

    fun updateUser(id: String, change: (MockUser) -> Unit) {
        users.firstOrNull { it.id == id }?.let(change)
    }

    fun updateGroup(id: Int, change: (MockGroup) -> Unit) {
        groups.firstOrNull { it.id == id }?.let(change)
    }

    fun updateGame(id: Int, change: (MockGame) -> Unit) {
        for (tournament in tournaments) {
            tournament.games.firstOrNull { it.id == id }?.let { change(it); return }
        }
    }

    fun updateMember(groupId: Int, userId: String, change: (MockMember) -> Unit) {
        group(groupId)?.member(userId)?.let(change)
    }

    /**
     * Upserts a bet (the DB unique key is user+game+group). The `boosted` flag is written
     * verbatim; the route layer is responsible for spec §1.2 validation (boosters off,
     * capacity) before calling here.
     */
    fun upsertBet(
        userId: String,
        gameId: Int,
        groupId: Int,
        home: Int,
        away: Int,
        boosted: Boolean = false,
    ): MockBet {
        val existing = bets.firstOrNull { it.userId == userId && it.gameId == gameId && it.groupId == groupId }
        if (existing != null) {
            existing.homeTeamScore = home
            existing.awayTeamScore = away
            existing.boosted = boosted
            existing.updatedAt = Instant.now()
            return existing
        }
        val bet = MockBet(
            id = nextBetId,
            userId = userId,
            gameId = gameId,
            groupId = groupId,
            userPoints = null,
            homeTeamScore = home,
            awayTeamScore = away,
            boosted = boosted,
        )
        nextBetId += 1
        bets.add(bet)
        return bet
    }

    /**
     * Spec §1.6 helper — count the user's already-boosted bets in [groupId] *excluding*
     * [excludingBetId] (so a no-op true→true write never trips the cap).
     */
    fun boostersUsed(userId: String, groupId: Int, excludingBetId: Int? = null): Int =
        bets.count { bet ->
            bet.userId == userId && bet.groupId == groupId && bet.boosted &&
                (excludingBetId == null || bet.id != excludingBetId)
        }
}

/**
 * Fluent builder for custom fixtures. Most suites start from [DefaultScenario.build] and tweak
 * via `backend.withScenario { ... }`; the builder is for from-scratch states.
 */
class ScenarioBuilder {
    val scenario = MockScenario()

    fun addUser(
        id: String,
        email: String,
        name: String,
        password: String? = null,
        imageUrl: String? = null,
        country: String? = null,
        isAdmin: Boolean = false,
        hasProfile: Boolean = true,
    ): ScenarioBuilder = apply {
        scenario.users.add(
            MockUser(
                id = id,
                email = email,
                name = name,
                password = password,
                imageUrl = imageUrl,
                firebaseImageUrl = imageUrl,
                country = country,
                isAdmin = isAdmin,
                hasProfile = hasProfile,
            ),
        )
    }

    fun addTournament(tournament: MockTournament): ScenarioBuilder = apply {
        scenario.tournaments.add(tournament)
    }

    fun addTeam(id: Int, tournamentId: Int, name: String, imageUrl: String? = null): ScenarioBuilder = apply {
        scenario.teams.add(MockTeam(id = id, tournamentId = tournamentId, name = name, imageUrl = imageUrl))
    }

    fun addGroup(group: MockGroup): ScenarioBuilder = apply { scenario.groups.add(group) }

    fun addBet(bet: MockBet): ScenarioBuilder = apply { scenario.bets.add(bet) }

    fun addMessage(message: MockMessage): ScenarioBuilder = apply { scenario.messages.add(message) }

    fun addAnnouncement(announcement: MockAnnouncement): ScenarioBuilder = apply {
        scenario.announcements.add(announcement)
    }

    fun addCategory(id: Int, name: String): ScenarioBuilder = apply {
        scenario.categories.add(MockCategory(id = id, name = name))
    }

    fun addCountry(code: String, name: String, flagEmoji: String? = null): ScenarioBuilder = apply {
        scenario.countries.add(MockCountry(code = code, name = name, flagEmoji = flagEmoji))
    }

    fun addArena(arena: MockArena): ScenarioBuilder = apply { scenario.arenas.add(arena) }

    fun build(): MockScenario = scenario
}

/**
 * The fixture every suite starts from: one signed-in user with two running groups in a live
 * tournament (upcoming + live + finished games, bets, chat with reactions), one wrapped group
 * in an ended tournament, one joinable public group, reference data, and an announcement.
 * Stable IDs/names — assert on them freely.
 */
object DefaultScenario {
    /** The seeded-auth user every non-auth test launches as. */
    const val CURRENT_USER_ID = "uid-alex"
    const val CURRENT_USER_EMAIL = "alex@betty.test"
    const val CURRENT_USER_PASSWORD = "secret123"
    const val CURRENT_USER_NAME = "Alex Tester"

    const val FRIEND_USER_ID = "uid-casey"
    const val RIVAL_USER_ID = "uid-robin"
    const val ADMIN_USER_ID = "uid-admin"

    const val RUNNING_TOURNAMENT_ID = 1
    const val ENDED_TOURNAMENT_ID = 2

    const val GROUP_SUNDAY_LEGENDS_ID = 1 // current user is AUTHOR
    const val GROUP_OFFICE_ROYALE_ID = 2 // current user is participant
    const val GROUP_WRAPPED_ID = 3 // ended tournament
    const val GROUP_PUBLIC_ID = 4 // public, current user NOT a member

    const val UPCOMING_GAME_ID = 11 // kicks off in 2 h — bettable
    const val LIVE_GAME_ID = 12 // kicked off 45 min ago — locked (423)
    const val FINISHED_GAME_ID = 13 // status 1, evaluated

    private const val DAY = 86_400L

    fun build(now: Instant = Instant.now()): MockScenario {
        val builder = ScenarioBuilder()

        builder
            .addUser(
                id = CURRENT_USER_ID, email = CURRENT_USER_EMAIL, name = CURRENT_USER_NAME,
                password = CURRENT_USER_PASSWORD, country = "SE",
            )
            .addUser(
                id = FRIEND_USER_ID, email = "casey@betty.test", name = "Casey Friend",
                password = "secret123", country = "GB",
            )
            .addUser(
                id = RIVAL_USER_ID, email = "robin@betty.test", name = "Robin Rival",
                password = "secret123",
            )
            .addUser(
                id = ADMIN_USER_ID, email = "admin@betty.test", name = "Betty Admin",
                password = "admin-secret", isAdmin = true,
            )

        builder.addTournament(
            MockTournament(
                id = RUNNING_TOURNAMENT_ID, name = "Euro Cup 2026", imageUrl = null,
                startDate = now.minusSeconds(7 * DAY),
                endDate = now.plusSeconds(21 * DAY),
                categoryId = 1,
                pools = mutableListOf(
                    MockPool(id = 1, tournamentId = RUNNING_TOURNAMENT_ID, name = "Group A"),
                    MockPool(id = 2, tournamentId = RUNNING_TOURNAMENT_ID, name = "Group B"),
                ),
                games = mutableListOf(
                    MockGame(
                        id = UPCOMING_GAME_ID, tournamentId = RUNNING_TOURNAMENT_ID, poolId = 1,
                        homeTeamId = 101, awayTeamId = 102,
                        startDate = now.plusSeconds(2 * 3600), status = null,
                    ),
                    MockGame(
                        id = LIVE_GAME_ID, tournamentId = RUNNING_TOURNAMENT_ID, poolId = 1,
                        homeTeamId = 103, awayTeamId = 104, homeTeamScore = 1,
                        startDate = now.minusSeconds(45 * 60),
                        updatedAt = now.minusSeconds(5 * 60), status = null,
                    ),
                    MockGame(
                        id = FINISHED_GAME_ID, tournamentId = RUNNING_TOURNAMENT_ID, poolId = 2,
                        homeTeamId = 101, awayTeamId = 103, homeTeamScore = 2, awayTeamScore = 1,
                        startDate = now.minusSeconds(2 * DAY),
                        updatedAt = now.minusSeconds(2 * DAY - 2 * 3600), status = 1,
                    ),
                ),
            ),
        )
        builder.addTournament(
            MockTournament(
                id = ENDED_TOURNAMENT_ID, name = "Legacy League",
                startDate = now.minusSeconds(60 * DAY),
                endDate = now.minusSeconds(10 * DAY),
                categoryId = 1,
            ),
        )

        builder
            .addTeam(id = 101, tournamentId = RUNNING_TOURNAMENT_ID, name = "Sweden")
            .addTeam(id = 102, tournamentId = RUNNING_TOURNAMENT_ID, name = "England")
            .addTeam(id = 103, tournamentId = RUNNING_TOURNAMENT_ID, name = "Spain")
            .addTeam(id = 104, tournamentId = RUNNING_TOURNAMENT_ID, name = "France")

        builder.addGroup(
            MockGroup(
                id = GROUP_SUNDAY_LEGENDS_ID, name = "Sunday Legends",
                tournamentId = RUNNING_TOURNAMENT_ID, inviteCode = "SUNLEG",
                welcomeMessage = "Bring your A-game.", description = "The original crew.",
                // Boosters ON: count=2, multiplier=2 (Boosters spec §4.1 default fixture).
                boostCount = 2, boostMultiplier = 2,
                createdAt = now.minusSeconds(6 * DAY),
                members = mutableListOf(
                    MockMember(userId = CURRENT_USER_ID, score = 5, normalizedScore = 5.0, accessLevel = 0),
                    MockMember(userId = FRIEND_USER_ID, score = 3, normalizedScore = 3.0, accessLevel = 2),
                    MockMember(userId = RIVAL_USER_ID, nickname = "The Oracle", score = 7, normalizedScore = 7.0, accessLevel = 2),
                ),
            ),
        )
        builder.addGroup(
            MockGroup(
                id = GROUP_OFFICE_ROYALE_ID, name = "Office Royale",
                tournamentId = RUNNING_TOURNAMENT_ID, inviteCode = "OFFICE",
                correctTeamPoints = 2, exactResultPoints = 5,
                // Boosters OFF: count=0 (Boosters spec §4.1).
                boostCount = 0, boostMultiplier = 2,
                createdAt = now.minusSeconds(5 * DAY),
                members = mutableListOf(
                    MockMember(userId = FRIEND_USER_ID, score = 4, normalizedScore = 4.0, accessLevel = 0),
                    MockMember(userId = CURRENT_USER_ID, score = 2, normalizedScore = 2.0, accessLevel = 2),
                ),
            ),
        )
        builder.addGroup(
            MockGroup(
                id = GROUP_WRAPPED_ID, name = "Wrapped Winners",
                tournamentId = ENDED_TOURNAMENT_ID, inviteCode = "WRAPPD",
                createdAt = now.minusSeconds(50 * DAY),
                members = mutableListOf(
                    MockMember(userId = CURRENT_USER_ID, score = 9, normalizedScore = 9.0, accessLevel = 0),
                    MockMember(userId = FRIEND_USER_ID, score = 6, normalizedScore = 6.0, accessLevel = 2),
                ),
            ),
        )
        builder.addGroup(
            MockGroup(
                id = GROUP_PUBLIC_ID, name = "Open Arena",
                tournamentId = RUNNING_TOURNAMENT_ID, inviteCode = "OPENAR",
                description = "Anyone can join.",
                publicAt = now.minusSeconds(3 * DAY),
                createdAt = now.minusSeconds(4 * DAY),
                members = mutableListOf(
                    MockMember(userId = FRIEND_USER_ID, score = 1, normalizedScore = 1.0, accessLevel = 0),
                    MockMember(userId = RIVAL_USER_ID, score = 0, normalizedScore = 0.0, accessLevel = 2),
                ),
            ),
        )

        // Finished game: evaluated bets. Live game: locked, unprocessed bet.
        // Upcoming game: deliberately un-bet → drives the home "need action" section.
        builder
            .addBet(
                MockBet(
                    id = 1, userId = CURRENT_USER_ID, gameId = FINISHED_GAME_ID,
                    groupId = GROUP_SUNDAY_LEGENDS_ID, userPoints = 3,
                    homeTeamScore = 2, awayTeamScore = 1,
                    processedAt = now.minusSeconds(2 * DAY - 3 * 3600),
                    createdAt = now.minusSeconds(3 * DAY),
                ),
            )
            .addBet(
                MockBet(
                    id = 2, userId = FRIEND_USER_ID, gameId = FINISHED_GAME_ID,
                    groupId = GROUP_SUNDAY_LEGENDS_ID, userPoints = 0,
                    homeTeamScore = 0, awayTeamScore = 2,
                    processedAt = now.minusSeconds(2 * DAY - 3 * 3600),
                    createdAt = now.minusSeconds(3 * DAY),
                ),
            )
            .addBet(
                MockBet(
                    id = 3, userId = CURRENT_USER_ID, gameId = LIVE_GAME_ID,
                    groupId = GROUP_SUNDAY_LEGENDS_ID, userPoints = null,
                    homeTeamScore = 2, awayTeamScore = 0,
                    createdAt = now.minusSeconds(DAY),
                ),
            )

        builder
            .addMessage(
                MockMessage(
                    id = 1, groupId = GROUP_SUNDAY_LEGENDS_ID, userId = FRIEND_USER_ID,
                    body = "Bring on the weekend!",
                    createdAt = now.minusSeconds(7200),
                    reactions = mutableListOf(MockReaction(userId = CURRENT_USER_ID, emojiId = "+1")),
                ),
            )
            .addMessage(
                MockMessage(
                    id = 2, groupId = GROUP_SUNDAY_LEGENDS_ID, userId = CURRENT_USER_ID,
                    body = "Legends till I die.",
                    createdAt = now.minusSeconds(3600),
                ),
            )

        builder.addAnnouncement(
            MockAnnouncement(
                id = 1, userId = ADMIN_USER_ID, title = "Welcome to Betty",
                body = "Place your first bet before kickoff!", category = "info",
                createdAt = now.minusSeconds(DAY),
            ),
        )

        builder
            .addCategory(id = 1, name = "Football")
            .addCountry(code = "SE", name = "Sweden", flagEmoji = "🇸🇪")
            .addCountry(code = "GB", name = "United Kingdom", flagEmoji = "🇬🇧")
            .addCountry(code = "FR", name = "France", flagEmoji = "🇫🇷")
            .addArena(
                MockArena(
                    id = 1, name = "Strawberry Arena", country = "SE",
                    city = "Stockholm", capacity = 50_000, imageUrl = "",
                ),
            )

        return builder.build()
    }
}
