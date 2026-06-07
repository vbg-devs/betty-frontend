import Foundation
import Testing
@testable import Betty

private final class HomeMockTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token" }
}

private let profileJSON = """
{"id": "uid-1", "email": "pat@test.dev", "name": "Pat", "image_url": null,
 "firebase_image_url": null, "country": null, "created_at": "2026-01-01T00:00:00Z",
 "updated_at": "2026-01-01T00:00:00Z", "is_admin": false}
"""

private let tournamentSummaryJSON = """
{"id": 1, "name": "World Cup 2026", "image_url": null, "category_id": 1,
 "start_date": "2026-06-11T00:00:00Z", "end_date": "2099-07-19T00:00:00Z",
 "pools": null, "games": null}
"""

private let userGroupsJSON = """
{"user": \(profileJSON),
 "groups": [
   {"id": 10, "name": "Alpha", "tournament_id": 1, "tournament_name": "World Cup 2026",
    "tournament_image_url": null, "header_image_url": null, "bet_mode": 0,
    "public_at": null, "created_at": "2026-01-01T00:00:00Z", "score": 7,
    "normalized_score": 0.5, "placement": 2, "member_count": 5},
   {"id": 20, "name": "Beta", "tournament_id": 1, "tournament_name": "World Cup 2026",
    "tournament_image_url": null, "header_image_url": null, "bet_mode": 0,
    "public_at": null, "created_at": "2026-01-01T00:00:00Z", "score": 0,
    "normalized_score": 0, "placement": 1, "member_count": 2}
 ]}
"""

private func tournamentDetailJSON(gameStart: String) -> String {
    """
    {"id": 1, "name": "World Cup 2026", "image_url": null, "category_id": 1,
     "start_date": "2026-06-11T00:00:00Z", "end_date": "2099-07-19T00:00:00Z",
     "pools": [{"id": 1, "tournament_id": 1, "name": "Group A"}],
     "games": [{"id": 100, "tournament_id": 1, "pool_id": 1, "home_team_id": 11,
                "away_team_id": 12, "home_team_score": null, "away_team_score": null,
                "start_date": "\(gameStart)", "updated_at": null, "status": 0}]}
    """
}

private func myBetJSON(gameID: Int, groupID: Int) -> String {
    """
    [{"id": 1, "user_id": "uid-1", "game_id": \(gameID), "group_id": \(groupID),
      "user_points": null, "home_team_score": 1, "away_team_score": 0,
      "is_universal": false, "processed_at": null,
      "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z"}]
    """
}

@Suite struct HomeViewModelTests {
    private struct Stack {
        let transport: MockTransport
        let viewModel: HomeViewModel
        let userStore: UserStore
    }

    private func makeStack() -> Stack {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: HomeMockTokens())
        let userStore = UserStore(api: api)
        let tournamentStore = TournamentStore(api: api)
        let viewModel = HomeViewModel(api: api, userStore: userStore, tournamentStore: tournamentStore)
        return Stack(transport: transport, viewModel: viewModel, userStore: userStore)
    }

    /// Routes the happy-path backend; `gameStart` controls the lone game's kickoff.
    private func routeHappyPath(
        _ transport: MockTransport,
        gameStart: String,
        betsForGroup20Fail: Bool = false
    ) {
        transport.handler = { request in
            switch request.url!.path {
            case "/api/v1/user/me":
                return MockTransport.json(profileJSON, url: request.url)
            case "/api/v1/tournaments":
                return MockTransport.json("[\(tournamentSummaryJSON)]", url: request.url)
            case "/api/v1/user/uid-1/groups":
                return MockTransport.json(userGroupsJSON, url: request.url)
            case "/api/v1/tournament/1":
                return MockTransport.json(tournamentDetailJSON(gameStart: gameStart), url: request.url)
            case "/api/v1/bets/bygroup/10":
                return MockTransport.json("[]", url: request.url)
            case "/api/v1/bets/bygroup/20":
                if betsForGroup20Fail {
                    return MockTransport.json("", status: 500, url: request.url)
                }
                return MockTransport.json(myBetJSON(gameID: 100, groupID: 20), url: request.url)
            default:
                return MockTransport.json("", status: 404, url: request.url)
            }
        }
    }

    private func isoString(hoursFromNow hours: Double) -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(hours * 3600))
    }

    @Test func refreshLoadsRichPlacementsAndNeedActionSources() async throws {
        let stack = makeStack()
        routeHappyPath(stack.transport, gameStart: isoString(hoursFromNow: 2))
        try await stack.userStore.loadMe()

        await stack.viewModel.refresh()

        #expect(stack.viewModel.isLoaded)
        #expect(!stack.viewModel.loadFailed)
        #expect(stack.viewModel.placements.map(\.id) == [10, 20])
        // Rich payload fields surface on the wire model.
        #expect(stack.viewModel.placements[0].placement == 2)
        #expect(stack.viewModel.placements[0].memberCount == 5)
        #expect(stack.viewModel.placements[0].score == 7)
        #expect(stack.viewModel.needActionSources.map(\.groupID) == [10, 20])
    }

    @Test func urgentGameSurfacesForTheGroupWhereItIsUnbet() async throws {
        let stack = makeStack()
        // Bet exists in group 20 only — the urgent entry must target group 10.
        routeHappyPath(stack.transport, gameStart: isoString(hoursFromNow: 2))
        try await stack.userStore.loadMe()
        await stack.viewModel.refresh()

        guard case .urgent(let entries) = stack.viewModel.needActionDisplay() else {
            Issue.record("expected an urgent display")
            return
        }
        #expect(entries.map(\.game.id) == [100])
        #expect(entries[0].groupID == 10)
    }

    @Test func failedBetMatrixExcludesThatGroupFromNeedAction() async throws {
        let stack = makeStack()
        routeHappyPath(stack.transport, gameStart: isoString(hoursFromNow: 2), betsForGroup20Fail: true)
        try await stack.userStore.loadMe()

        await stack.viewModel.refresh()

        #expect(stack.viewModel.needActionSources.map(\.groupID) == [10])
    }

    @Test func farOffGameProducesNoNeedActionDisplay() async throws {
        let stack = makeStack()
        routeHappyPath(stack.transport, gameStart: "2099-06-11T18:00:00Z")
        try await stack.userStore.loadMe()
        await stack.viewModel.refresh()

        #expect(stack.viewModel.needActionDisplay() == .hidden)
    }

    @Test func failedRefreshKeepsTheLastGoodPlacements() async throws {
        let stack = makeStack()
        routeHappyPath(stack.transport, gameStart: isoString(hoursFromNow: 2))
        try await stack.userStore.loadMe()
        await stack.viewModel.refresh()
        #expect(stack.viewModel.placements.count == 2)

        stack.transport.handler = { request in
            MockTransport.json("", status: 500, url: request.url)
        }
        await stack.viewModel.refresh()

        #expect(stack.viewModel.placements.count == 2)
        #expect(!stack.viewModel.loadFailed) // we still have data to show
    }

    @Test func firstLoadFailureFlagsLoadFailed() async throws {
        let stack = makeStack()
        routeHappyPath(stack.transport, gameStart: isoString(hoursFromNow: 2))
        try await stack.userStore.loadMe()

        stack.transport.handler = { request in
            MockTransport.json("", status: 500, url: request.url)
        }
        await stack.viewModel.refresh()

        #expect(stack.viewModel.isLoaded)
        #expect(stack.viewModel.loadFailed)
        #expect(stack.viewModel.placements.isEmpty)
    }

    @Test func loadIfNeededFetchesOnlyOnce() async throws {
        let stack = makeStack()
        routeHappyPath(stack.transport, gameStart: isoString(hoursFromNow: 2))
        try await stack.userStore.loadMe()

        await stack.viewModel.loadIfNeeded()
        await stack.viewModel.loadIfNeeded()

        let groupsCalls = stack.transport.requests.count { $0.url!.path == "/api/v1/user/uid-1/groups" }
        #expect(groupsCalls == 1)
    }

    @Test func refreshWithoutAProfileStillMarksLoaded() async {
        let stack = makeStack()
        await stack.viewModel.refresh()

        #expect(stack.viewModel.isLoaded)
        #expect(stack.viewModel.placements.isEmpty)
        #expect(stack.transport.requests.isEmpty)
    }
}
