import Foundation
import Testing
@testable import Betty

private final class MockTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token-1" }
    func tokenAfterAuthFailure() async throws -> String { "token-2" }
}

@MainActor
struct TournamentStoreLiveTests {
    private static let detailJSON = """
    {"id":1,"name":"t","image_url":null,"start_date":"2026-06-21T12:00:00Z",
     "end_date":"2026-06-22T12:00:00Z","category_id":1,"pools":[],
     "games":[
       {"id":10,"tournament_id":1,"pool_id":1,"home_team_id":1,"away_team_id":2,
        "home_team_score":0,"away_team_score":0,"start_date":"2026-06-21T12:00:00Z",
        "updated_at":null,"status":null,"live_home_team_score":null,"live_away_team_score":null,"live_status":null},
       {"id":11,"tournament_id":1,"pool_id":1,"home_team_id":3,"away_team_id":4,
        "home_team_score":0,"away_team_score":0,"start_date":"2026-06-21T12:00:00Z",
        "updated_at":null,"status":null,"live_home_team_score":null,"live_away_team_score":null,"live_status":null}
     ]}
    """

    @Test func applyLiveScoreUpdatesMatchingGameInPlace() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(Self.detailJSON, url: request.url)
        }
        let store = TournamentStore(api: APIClient(transport: transport, tokens: MockTokens()))
        _ = try await store.loadDetails(id: 1)

        store.applyLiveScore(WSLiveScoreUpdate(gameID: 11, homeTeamScore: 2, awayTeamScore: 1, liveStatus: 1))

        let g11 = store.detailsByID(1)?.games?.first { $0.id == 11 }
        #expect(g11?.liveStatus == 1)
        #expect(g11?.liveHomeTeamScore == 2)
        #expect(g11?.liveAwayTeamScore == 1)
        let g10 = store.detailsByID(1)?.games?.first { $0.id == 10 }
        #expect(g10?.liveStatus == nil)
    }
}
