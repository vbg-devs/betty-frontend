import Foundation
import Testing
@testable import Betty

private final class MockTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token-1" }
    func tokenAfterAuthFailure() async throws -> String { "token-2" }
}

/// Pins the WS → store wiring: `evaluate_game` is the only score mutation (forced
/// tournament-detail reload + game refresh + bet matrix reload + leaderboard trigger);
/// bet events refresh the loaded group's matrix; everything else is informational.
@Suite struct LiveUpdateCoordinatorTests {
    private let transport = MockTransport()
    private let tournamentStore: TournamentStore
    private let gameStore: GameStore
    private let betStore: BetStore
    private let coordinator: LiveUpdateCoordinator

    private static let tournamentJSON = """
    {"id":3,"name":"Euro","image_url":null,"start_date":"2026-06-01T00:00:00Z",
     "end_date":"2026-07-01T00:00:00Z","category_id":1,
     "pools":[{"id":1,"tournament_id":3,"name":"A"}],
     "games":[{"id":7,"tournament_id":3,"pool_id":1,"home_team_id":1,"away_team_id":2,
       "home_team_score":0,"away_team_score":0,"start_date":"2026-06-07T15:00:00Z",
       "updated_at":null,"status":null}]}
    """
    private static let gameJSON = """
    {"id":7,"tournament_id":3,"pool_id":1,"home_team_id":1,"away_team_id":2,
     "home_team_score":2,"away_team_score":1,"start_date":"2026-06-07T15:00:00Z",
     "updated_at":null,"status":1}
    """
    private static let betsJSON = """
    [{"id":11,"user_id":"uid-1","game_id":7,"group_id":5,"user_points":null,
      "home_team_score":1,"away_team_score":0,"is_universal":false,"processed_at":null,
      "created_at":"2026-06-01T10:00:00Z","updated_at":"2026-06-01T10:00:00Z"}]
    """

    init() {
        let api = APIClient(transport: transport, tokens: MockTokens())
        tournamentStore = TournamentStore(api: api)
        gameStore = GameStore(api: api)
        betStore = BetStore(api: api)
        coordinator = LiveUpdateCoordinator(
            tournamentStore: tournamentStore,
            gameStore: gameStore,
            betStore: betStore
        )
        transport.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/tournament/3") {
                return MockTransport.json(Self.tournamentJSON, url: request.url)
            }
            if path.hasSuffix("/game/7") {
                return MockTransport.json(Self.gameJSON, url: request.url)
            }
            if path.hasSuffix("/bets/bygroup/5") {
                return MockTransport.json(Self.betsJSON, url: request.url)
            }
            return MockTransport.json("null", status: 404, url: request.url)
        }
    }

    private var requestPaths: [String] {
        transport.requests.compactMap { $0.url?.path }
    }

    @Test func evaluateGameRefreshesEverythingCached() async throws {
        try await tournamentStore.loadDetails(id: 3)
        try await gameStore.load(id: 7)
        try await betStore.load(groupID: 5)
        let seeded = transport.requests.count

        await coordinator.handle(.evaluateGame(WSEvaluateGame(gameID: 7, homeTeamScore: 2, awayTeamScore: 1)))

        let refreshed = requestPaths.dropFirst(seeded)
        #expect(refreshed.contains { $0.hasSuffix("/tournament/3") }) // forced detail reload
        #expect(refreshed.contains { $0.hasSuffix("/game/7") })       // live score refresh
        #expect(refreshed.contains { $0.hasSuffix("/bets/bygroup/5") }) // evaluated user_points
        #expect(coordinator.evaluationCount == 1)
        #expect(coordinator.lastEvaluatedGameID == 7)
        #expect(gameStore.byID(7)?.isFinished == true)
    }

    @Test func evaluateGameWithNothingCachedStillBumpsLeaderboardTrigger() async {
        await coordinator.handle(.evaluateGame(WSEvaluateGame(gameID: 99, homeTeamScore: 1, awayTeamScore: 0)))

        #expect(transport.requests.isEmpty)
        #expect(coordinator.evaluationCount == 1)
        #expect(coordinator.lastEvaluatedGameID == 99)
    }

    @Test func evaluateGameSkipsTournamentsNotContainingTheGame() async throws {
        try await tournamentStore.loadDetails(id: 3)
        let seeded = transport.requests.count

        await coordinator.handle(.evaluateGame(WSEvaluateGame(gameID: 99, homeTeamScore: 1, awayTeamScore: 0)))

        #expect(transport.requests.count == seeded)
        #expect(coordinator.evaluationCount == 1)
    }

    @Test func betPlacedReloadsTheLoadedGroupMatrix() async throws {
        try await betStore.load(groupID: 5)
        let seeded = transport.requests.count

        let envelope = """
        {"type":"bet_placed","message":{"id":0,"user_id":"uid-2","game_id":7,"group_id":5,
         "user_points":null,"home_team_score":3,"away_team_score":0,"is_universal":false,
         "processed_at":null,"created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}}
        """
        let event = try #require(BettyEvent.decode(from: Data(envelope.utf8)))
        await coordinator.handle(event)

        let refreshed = requestPaths.dropFirst(seeded)
        #expect(refreshed.contains { $0.hasSuffix("/bets/bygroup/5") })
    }

    @Test func betUpdatedForAnotherGroupIsIgnored() async throws {
        try await betStore.load(groupID: 5)
        let seeded = transport.requests.count

        let envelope = """
        {"type":"bet_updated","message":{"id":12,"user_id":"uid-2","game_id":7,"group_id":6,
         "user_points":null,"home_team_score":3,"away_team_score":0,"is_universal":false,
         "processed_at":null,"created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}}
        """
        let event = try #require(BettyEvent.decode(from: Data(envelope.utf8)))
        await coordinator.handle(event)

        #expect(transport.requests.count == seeded)
    }

    @Test func universalBetRefreshesEvenFromAnotherGroup() async throws {
        try await betStore.load(groupID: 5)
        let seeded = transport.requests.count

        let envelope = """
        {"type":"bet_placed","message":{"id":0,"user_id":"uid-2","game_id":7,"group_id":6,
         "user_points":null,"home_team_score":3,"away_team_score":0,"is_universal":true,
         "processed_at":null,"created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}}
        """
        let event = try #require(BettyEvent.decode(from: Data(envelope.utf8)))
        await coordinator.handle(event)

        let refreshed = requestPaths.dropFirst(seeded)
        #expect(refreshed.contains { $0.hasSuffix("/bets/bygroup/5") })
    }

    @Test func betEventsWithoutALoadedGroupAreIgnored() async throws {
        let envelope = """
        {"type":"bet_placed","message":{"id":0,"user_id":"uid-2","game_id":7,"group_id":5,
         "user_points":null,"home_team_score":3,"away_team_score":0,"is_universal":true,
         "processed_at":null,"created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}}
        """
        let event = try #require(BettyEvent.decode(from: Data(envelope.utf8)))
        await coordinator.handle(event)

        #expect(transport.requests.isEmpty)
    }

    @Test func informationalEventsTouchNoStores() async throws {
        try await tournamentStore.loadDetails(id: 3)
        try await betStore.load(groupID: 5)
        let seeded = transport.requests.count

        let envelopes = [
            #"{"type":"group_left","message":null}"#,
            #"{"type":"group_created","message":null}"#,
            #"{"type":"group_visibility_changed","message":{"group_id":5,"public_at":null}}"#,
            #"{"type":"game_starting_soon","message":{"Games":[{"id":7,"start_date":null}]}}"#,
            #"{"type":"user_exact_score","message":{"game_id":7,"user_ids":["uid-1"]}}"#,
            #"{"type":"something_new","message":{"x":1}}"#,
        ]
        for envelope in envelopes {
            let event = try #require(BettyEvent.decode(from: Data(envelope.utf8)))
            await coordinator.handle(event)
        }

        #expect(transport.requests.count == seeded)
        #expect(coordinator.evaluationCount == 0)
    }
}
