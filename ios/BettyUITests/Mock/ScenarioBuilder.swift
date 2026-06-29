import Foundation

// Programmatic fixture state for the mock backend. The wire shapes these entities
// serialize to live in MockWire.swift and follow docs/mobile/api-contract.md exactly
// (string Firebase-UID user ids, nullable Game.status, flat pools[]/games[], ...).

enum MembershipStatus {
    case active
    case left
    case blocked
}

struct MockUser {
    var id: String
    var email: String
    var name: String
    /// Only used by the mock identity endpoints (signInWithPassword).
    var password: String?
    var imageURL: String?
    var firebaseImageURL: String?
    var country: String?
    var isAdmin = false
    /// `GET /user/me` 404s (onboarding gate) until the profile row exists.
    var hasProfile = true
    var createdAt = Date()
}

struct MockMember {
    var userID: String
    var nickname: String?
    var score = 0
    var normalizedScore = 0.0
    /// 0 author, 1 admin, 2 participant.
    var accessLevel = 2
    var status = MembershipStatus.active
}

struct MockGroup {
    var id: Int
    var name: String
    var tournamentID: Int
    var inviteCode: String
    var headerImageURL: String?
    var welcomeMessage: String?
    var description: String?
    var correctTeamPoints = 1
    var exactResultPoints = 3
    var allowSneakPeek = true
    var groupPlayDeadline: Date?
    var mode = 0
    /// 0 = boosters disabled in this group (default — spec decision log #6).
    var boostCount = 0
    /// Multiplier applied when a bet has `boosted == true`. Default 2.
    var boostMultiplier = 2
    var publicAt: Date?
    var createdAt = Date()
    var updatedAt = Date()
    var members: [MockMember] = []

    func member(_ userID: String) -> MockMember? {
        members.first { $0.userID == userID }
    }

    func isActiveMember(_ userID: String) -> Bool {
        member(userID)?.status == .active
    }

    func isAuthor(_ userID: String) -> Bool {
        member(userID).map { $0.accessLevel == 0 && $0.status == .active } ?? false
    }
}

struct MockPool {
    var id: Int
    var tournamentID: Int
    var name: String
}

struct MockGame {
    var id: Int
    var tournamentID: Int
    var poolID: Int
    var homeTeamID: Int
    var awayTeamID: Int
    var homeTeamScore = 0
    var awayTeamScore = 0
    var startDate: Date
    var updatedAt: Date?
    /// nil = not final, 1 = finished (matches the nullable wire int).
    var status: Int?
}

struct MockTournament {
    var id: Int
    var name: String
    var imageURL: String?
    var startDate: Date
    var endDate: Date
    var categoryID = 1
    var pools: [MockPool] = []
    var games: [MockGame] = []

    func hasEnded(at now: Date = Date()) -> Bool { endDate <= now }
}

struct MockTeam {
    var id: Int
    var tournamentID: Int
    var name: String
    var imageURL: String?
    var isPlaceholder = false
}

struct MockBet {
    var id: Int
    var userID: String
    var gameID: Int
    var groupID: Int
    var userPoints: Int?
    var homeTeamScore: Int
    var awayTeamScore: Int
    /// True iff the user has applied their booster to this row (spec §1.2).
    var boosted = false
    var processedAt: Date?
    var createdAt = Date()
    var updatedAt = Date()
}

struct MockReaction {
    var userID: String
    var emojiID: String
    var createdAt = Date()
}

struct MockMessage {
    var id: Int
    var groupID: Int
    var userID: String
    var body: String?
    var imageURL: String?
    var createdAt = Date()
    var reactions: [MockReaction] = []
    var deleted = false
}

struct MockAnnouncement {
    var id: Int
    var userID: String
    var title: String
    var body: String
    var category: String
    var cta: String?
    var createdAt = Date()
}

struct MockCategory {
    var id: Int
    var name: String
}

struct MockCountry {
    var code: String
    var name: String
    var flagEmoji: String?
}

struct MockArena {
    var id: Int
    var name: String
    var country: String
    var city: String
    var capacity: Int
    var imageURL: String
}

/// A staged FIFA result proposal (admin `/admin/fifa/proposals`), enriched with the
/// betty game's team names + kickoff exactly as the betty-api `ProposalView` wire shape.
struct MockFIFAProposal {
    var id: Int
    var gameID: Int
    var matchID: String
    var homeTeamScore: Int
    var awayTeamScore: Int
    var kind: String = "initial"
    var status: String = "pending"
    var source: String = "proposal"
    var prevHomeScore: Int?
    var prevAwayScore: Int?
    var gameHomeTeam: String
    var gameAwayTeam: String
    var gameStartDate: Date
}

/// A mapped FIFA final betty has not settled and has no pending proposal for, exactly as
/// the betty-api `GET /admin/fifa/unsettled-finals` wire shape.
struct MockFIFAUnsettledFinal {
    var competitionID: String = "285023"
    var gameID: Int
    var matchID: String
    var homeTeam: String
    var awayTeam: String
    var startTime: Date
}

/// The whole mock-backend state. Routes resolve from it, mutations (POST /bet, join,
/// message, ...) write back into it, so subsequent GETs reflect every change.
struct MockScenario {
    var users: [MockUser] = []
    var groups: [MockGroup] = []
    var tournaments: [MockTournament] = []
    var teams: [MockTeam] = []
    var bets: [MockBet] = []
    var messages: [MockMessage] = []
    var announcements: [MockAnnouncement] = []
    var categories: [MockCategory] = []
    var countries: [MockCountry] = []
    var arenas: [MockArena] = []
    var fifaProposals: [MockFIFAProposal] = []
    var fifaUnsettledFinals: [MockFIFAUnsettledFinal] = []

    /// `accounts:signInWithIdp` signs in this user (defaults to the first user).
    var idpUserID: String?
    /// When true, signInWithIdp answers `needConfirmation: true` (no tokens).
    var idpNeedsConfirmation = false

    var nextGroupID = 1000
    var nextBetID = 1000
    var nextMessageID = 1000
    var nextAnnouncementID = 1000
    var nextFeatureRequestID = 1000
    var nextSignupNumber = 1

    // MARK: - Lookups

    func user(_ id: String) -> MockUser? { users.first { $0.id == id } }
    func userByEmail(_ email: String) -> MockUser? {
        users.first { $0.email.caseInsensitiveCompare(email) == .orderedSame }
    }
    func group(_ id: Int) -> MockGroup? { groups.first { $0.id == id } }
    func groupByCode(_ code: String) -> MockGroup? { groups.first { $0.inviteCode == code } }
    func tournament(_ id: Int) -> MockTournament? { tournaments.first { $0.id == id } }
    func game(_ id: Int) -> MockGame? {
        for tournament in tournaments {
            if let game = tournament.games.first(where: { $0.id == id }) { return game }
        }
        return nil
    }
    func fifaProposal(_ id: Int) -> MockFIFAProposal? { fifaProposals.first { $0.id == id } }

    // MARK: - Mutations

    mutating func updateUser(_ id: String, _ change: (inout MockUser) -> Void) {
        guard let index = users.firstIndex(where: { $0.id == id }) else { return }
        change(&users[index])
    }

    mutating func updateGroup(_ id: Int, _ change: (inout MockGroup) -> Void) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        change(&groups[index])
    }

    mutating func updateGame(_ id: Int, _ change: (inout MockGame) -> Void) {
        for tournamentIndex in tournaments.indices {
            if let gameIndex = tournaments[tournamentIndex].games.firstIndex(where: { $0.id == id }) {
                change(&tournaments[tournamentIndex].games[gameIndex])
                return
            }
        }
    }

    mutating func updateFIFAProposal(_ id: Int, _ change: (inout MockFIFAProposal) -> Void) {
        guard let index = fifaProposals.firstIndex(where: { $0.id == id }) else { return }
        change(&fifaProposals[index])
    }

    mutating func updateMember(groupID: Int, userID: String, _ change: (inout MockMember) -> Void) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }),
              let memberIndex = groups[groupIndex].members.firstIndex(where: { $0.userID == userID })
        else { return }
        change(&groups[groupIndex].members[memberIndex])
    }

    /// Upserts a bet (the DB unique key is user+game+group). Returns the stored bet.
    /// `boosted` is written verbatim; the route layer is responsible for spec §1.2
    /// validation (boosters off / capacity) before calling here.
    @discardableResult
    mutating func upsertBet(userID: String, gameID: Int, groupID: Int, home: Int, away: Int,
                            boosted: Bool = false) -> MockBet {
        if let index = bets.firstIndex(where: { $0.userID == userID && $0.gameID == gameID && $0.groupID == groupID }) {
            bets[index].homeTeamScore = home
            bets[index].awayTeamScore = away
            bets[index].boosted = boosted
            bets[index].updatedAt = Date()
            return bets[index]
        }
        let bet = MockBet(id: nextBetID, userID: userID, gameID: gameID, groupID: groupID,
                          userPoints: nil, homeTeamScore: home, awayTeamScore: away, boosted: boosted)
        nextBetID += 1
        bets.append(bet)
        return bet
    }

    /// Spec §1.6 helper — count the user's already-boosted bets in `groupID` *excluding*
    /// `excludingBetID` (so a no-op true→true write never trips the cap).
    func boostersUsed(userID: String, groupID: Int, excludingBetID: Int? = nil) -> Int {
        bets.count { bet in
            bet.userID == userID && bet.groupID == groupID && bet.boosted
                && (excludingBetID == nil || bet.id != excludingBetID!)
        }
    }
}

/// Fluent builder for custom fixtures. Most suites start from `DefaultScenario.build()`
/// and tweak via `backend.withScenario { ... }`; the builder is for from-scratch states.
final class ScenarioBuilder {
    private(set) var scenario = MockScenario()

    @discardableResult
    func addUser(id: String, email: String, name: String, password: String? = nil,
                 imageURL: String? = nil, country: String? = nil,
                 isAdmin: Bool = false, hasProfile: Bool = true) -> ScenarioBuilder {
        scenario.users.append(MockUser(id: id, email: email, name: name, password: password,
                                       imageURL: imageURL, firebaseImageURL: imageURL,
                                       country: country, isAdmin: isAdmin, hasProfile: hasProfile))
        return self
    }

    @discardableResult
    func addTournament(_ tournament: MockTournament) -> ScenarioBuilder {
        scenario.tournaments.append(tournament)
        return self
    }

    @discardableResult
    func addTeam(id: Int, tournamentID: Int, name: String, imageURL: String? = nil) -> ScenarioBuilder {
        scenario.teams.append(MockTeam(id: id, tournamentID: tournamentID, name: name, imageURL: imageURL))
        return self
    }

    @discardableResult
    func addGroup(_ group: MockGroup) -> ScenarioBuilder {
        scenario.groups.append(group)
        return self
    }

    @discardableResult
    func addBet(_ bet: MockBet) -> ScenarioBuilder {
        scenario.bets.append(bet)
        return self
    }

    @discardableResult
    func addMessage(_ message: MockMessage) -> ScenarioBuilder {
        scenario.messages.append(message)
        return self
    }

    @discardableResult
    func addAnnouncement(_ announcement: MockAnnouncement) -> ScenarioBuilder {
        scenario.announcements.append(announcement)
        return self
    }

    @discardableResult
    func addCategory(id: Int, name: String) -> ScenarioBuilder {
        scenario.categories.append(MockCategory(id: id, name: name))
        return self
    }

    @discardableResult
    func addCountry(code: String, name: String, flagEmoji: String? = nil) -> ScenarioBuilder {
        scenario.countries.append(MockCountry(code: code, name: name, flagEmoji: flagEmoji))
        return self
    }

    @discardableResult
    func addArena(_ arena: MockArena) -> ScenarioBuilder {
        scenario.arenas.append(arena)
        return self
    }

    func build() -> MockScenario { scenario }
}

/// The fixture every suite starts from: one signed-in user with two running groups in a
/// live tournament (upcoming + live + finished games, bets, chat with reactions), one
/// wrapped group in an ended tournament, one joinable public group, reference data, and
/// an announcement. Stable IDs/names — assert on them freely.
enum DefaultScenario {
    /// The seeded-auth user every non-auth test launches as.
    static let currentUserID = "uid-alex"
    static let currentUserEmail = "alex@betty.test"
    static let currentUserPassword = "secret123"
    static let currentUserName = "Alex Tester"

    static let friendUserID = "uid-casey"
    static let rivalUserID = "uid-robin"
    static let adminUserID = "uid-admin"

    static let runningTournamentID = 1
    static let endedTournamentID = 2

    static let groupSundayLegendsID = 1      // current user is AUTHOR
    static let groupOfficeRoyaleID = 2       // current user is participant
    static let groupWrappedID = 3            // ended tournament
    static let groupPublicID = 4             // public, current user NOT a member

    static let upcomingGameID = 11           // kicks off in 2 h — bettable
    static let liveGameID = 12               // kicked off 45 min ago — locked (423)
    static let finishedGameID = 13           // status 1, evaluated

    static func build(now: Date = Date()) -> MockScenario {
        let builder = ScenarioBuilder()

        builder
            .addUser(id: currentUserID, email: currentUserEmail, name: currentUserName,
                     password: currentUserPassword, country: "SE")
            .addUser(id: friendUserID, email: "casey@betty.test", name: "Casey Friend",
                     password: "secret123", country: "GB")
            .addUser(id: rivalUserID, email: "robin@betty.test", name: "Robin Rival",
                     password: "secret123")
            .addUser(id: adminUserID, email: "admin@betty.test", name: "Betty Admin",
                     password: "admin-secret", isAdmin: true)

        builder.addTournament(MockTournament(
            id: runningTournamentID, name: "Euro Cup 2026", imageURL: nil,
            startDate: now.addingTimeInterval(-7 * 86_400),
            endDate: now.addingTimeInterval(21 * 86_400),
            categoryID: 1,
            pools: [
                MockPool(id: 1, tournamentID: runningTournamentID, name: "Group A"),
                MockPool(id: 2, tournamentID: runningTournamentID, name: "Group B"),
            ],
            games: [
                MockGame(id: upcomingGameID, tournamentID: runningTournamentID, poolID: 1,
                         homeTeamID: 101, awayTeamID: 102,
                         startDate: now.addingTimeInterval(2 * 3600), status: nil),
                MockGame(id: liveGameID, tournamentID: runningTournamentID, poolID: 1,
                         homeTeamID: 103, awayTeamID: 104, homeTeamScore: 1,
                         startDate: now.addingTimeInterval(-45 * 60),
                         updatedAt: now.addingTimeInterval(-5 * 60), status: nil),
                MockGame(id: finishedGameID, tournamentID: runningTournamentID, poolID: 2,
                         homeTeamID: 101, awayTeamID: 103, homeTeamScore: 2, awayTeamScore: 1,
                         startDate: now.addingTimeInterval(-2 * 86_400),
                         updatedAt: now.addingTimeInterval(-2 * 86_400 + 2 * 3600), status: 1),
            ]
        ))
        builder.addTournament(MockTournament(
            id: endedTournamentID, name: "Legacy League",
            startDate: now.addingTimeInterval(-60 * 86_400),
            endDate: now.addingTimeInterval(-10 * 86_400),
            categoryID: 1
        ))

        builder
            .addTeam(id: 101, tournamentID: runningTournamentID, name: "Sweden")
            .addTeam(id: 102, tournamentID: runningTournamentID, name: "England")
            .addTeam(id: 103, tournamentID: runningTournamentID, name: "Spain")
            .addTeam(id: 104, tournamentID: runningTournamentID, name: "France")

        builder.addGroup(MockGroup(
            id: groupSundayLegendsID, name: "Sunday Legends",
            tournamentID: runningTournamentID, inviteCode: "SUNLEG",
            welcomeMessage: "Bring your A-game.", description: "The original crew.",
            // Boosters ON in this group (spec §4.1 default fixture: count=2, multiplier=2).
            boostCount: 2, boostMultiplier: 2,
            createdAt: now.addingTimeInterval(-6 * 86_400),
            members: [
                MockMember(userID: currentUserID, score: 5, normalizedScore: 5, accessLevel: 0),
                MockMember(userID: friendUserID, score: 3, normalizedScore: 3, accessLevel: 2),
                MockMember(userID: rivalUserID, nickname: "The Oracle", score: 7, normalizedScore: 7, accessLevel: 2),
            ]
        ))
        builder.addGroup(MockGroup(
            id: groupOfficeRoyaleID, name: "Office Royale",
            tournamentID: runningTournamentID, inviteCode: "OFFICE",
            correctTeamPoints: 2, exactResultPoints: 5,
            // Boosters OFF in this group (spec §4.1 — exercise the disabled-state UI).
            boostCount: 0, boostMultiplier: 2,
            createdAt: now.addingTimeInterval(-5 * 86_400),
            members: [
                MockMember(userID: friendUserID, score: 4, normalizedScore: 4, accessLevel: 0),
                MockMember(userID: currentUserID, score: 2, normalizedScore: 2, accessLevel: 2),
            ]
        ))
        builder.addGroup(MockGroup(
            id: groupWrappedID, name: "Wrapped Winners",
            tournamentID: endedTournamentID, inviteCode: "WRAPPD",
            createdAt: now.addingTimeInterval(-50 * 86_400),
            members: [
                MockMember(userID: currentUserID, score: 9, normalizedScore: 9, accessLevel: 0),
                MockMember(userID: friendUserID, score: 6, normalizedScore: 6, accessLevel: 2),
            ]
        ))
        builder.addGroup(MockGroup(
            id: groupPublicID, name: "Open Arena",
            tournamentID: runningTournamentID, inviteCode: "OPENAR",
            description: "Anyone can join.",
            publicAt: now.addingTimeInterval(-3 * 86_400),
            createdAt: now.addingTimeInterval(-4 * 86_400),
            members: [
                MockMember(userID: friendUserID, score: 1, normalizedScore: 1, accessLevel: 0),
                MockMember(userID: rivalUserID, score: 0, normalizedScore: 0, accessLevel: 2),
            ]
        ))

        // Finished game: evaluated bets. Live game: locked, unprocessed bet.
        // Upcoming game: deliberately un-bet → drives the home "need action" section.
        builder
            .addBet(MockBet(id: 1, userID: currentUserID, gameID: finishedGameID,
                            groupID: groupSundayLegendsID, userPoints: 3,
                            homeTeamScore: 2, awayTeamScore: 1,
                            processedAt: now.addingTimeInterval(-2 * 86_400 + 3 * 3600),
                            createdAt: now.addingTimeInterval(-3 * 86_400)))
            .addBet(MockBet(id: 2, userID: friendUserID, gameID: finishedGameID,
                            groupID: groupSundayLegendsID, userPoints: 0,
                            homeTeamScore: 0, awayTeamScore: 2,
                            processedAt: now.addingTimeInterval(-2 * 86_400 + 3 * 3600),
                            createdAt: now.addingTimeInterval(-3 * 86_400)))
            .addBet(MockBet(id: 3, userID: currentUserID, gameID: liveGameID,
                            groupID: groupSundayLegendsID, userPoints: nil,
                            homeTeamScore: 2, awayTeamScore: 0,
                            createdAt: now.addingTimeInterval(-86_400)))

        builder
            .addMessage(MockMessage(id: 1, groupID: groupSundayLegendsID, userID: friendUserID,
                                    body: "Bring on the weekend!",
                                    createdAt: now.addingTimeInterval(-7200),
                                    reactions: [MockReaction(userID: currentUserID, emojiID: "+1")]))
            .addMessage(MockMessage(id: 2, groupID: groupSundayLegendsID, userID: currentUserID,
                                    body: "Legends till I die.",
                                    createdAt: now.addingTimeInterval(-3600)))

        builder.addAnnouncement(MockAnnouncement(
            id: 1, userID: adminUserID, title: "Welcome to Betty",
            body: "Place your first bet before kickoff!", category: "info",
            createdAt: now.addingTimeInterval(-86_400)
        ))

        builder
            .addCategory(id: 1, name: "Football")
            .addCountry(code: "SE", name: "Sweden", flagEmoji: "🇸🇪")
            .addCountry(code: "GB", name: "United Kingdom", flagEmoji: "🇬🇧")
            .addCountry(code: "FR", name: "France", flagEmoji: "🇫🇷")
            .addArena(MockArena(id: 1, name: "Strawberry Arena", country: "SE",
                                city: "Stockholm", capacity: 50_000, imageURL: ""))

        return builder.build()
    }
}
