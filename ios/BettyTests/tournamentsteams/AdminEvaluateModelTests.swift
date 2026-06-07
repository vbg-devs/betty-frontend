import Foundation
import Testing
@testable import Betty

private final class MockTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token" }
}

private func makeGame(id: Int, start: String, status: Int? = 0) throws -> Game {
    let json = """
    {"id": \(id), "tournament_id": 7, "pool_id": 1, "home_team_id": 1, "away_team_id": 2,
     "home_team_score": null, "away_team_score": null, "start_date": "\(start)",
     "status": \(status.map(String.init) ?? "null")}
    """
    return try JSONCoding.makeDecoder().decode(Game.self, from: Data(json.utf8))
}

/// Detail payload: g12 is already evaluated; g10 kicks off after g11.
private func tournamentJSON(id: Int) -> String {
    """
    {
      "id": \(id),
      "name": "Euro 2028",
      "image_url": null,
      "start_date": "2026-06-11T00:00:00Z",
      "end_date": null,
      "category_id": 1,
      "pools": [{"id": 1, "tournament_id": \(id), "name": "Group A"}],
      "games": [
        {"id": 10, "tournament_id": \(id), "pool_id": 1, "home_team_id": 1, "away_team_id": 2,
         "home_team_score": null, "away_team_score": null,
         "start_date": "2026-06-14T18:00:00Z", "status": 0},
        {"id": 12, "tournament_id": \(id), "pool_id": 1, "home_team_id": 3, "away_team_id": 4,
         "home_team_score": 2, "away_team_score": 0,
         "start_date": "2026-06-12T15:00:00Z", "status": 1},
        {"id": 11, "tournament_id": \(id), "pool_id": 1, "home_team_id": 5, "away_team_id": 6,
         "home_team_score": null, "away_team_score": null,
         "start_date": "2026-06-13T12:00:00Z", "status": 0}
      ]
    }
    """
    }

@Suite struct AdminEvaluateCanSaveTests {
    private let now = ISO8601DateFormatter().date(from: "2026-06-15T12:00:00Z")!

    @Test func startedGameWithBothScoresCanSave() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T10:00:00Z")
        #expect(AdminEvaluateModel.canSave(game: game, homeScore: "2", awayScore: "1", now: now))
        #expect(AdminEvaluateModel.canSave(game: game, homeScore: "0", awayScore: "0", now: now))
    }

    @Test func futureGameCannotSave() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T14:00:00Z")
        #expect(!AdminEvaluateModel.canSave(game: game, homeScore: "2", awayScore: "1", now: now))
    }

    @Test func missingScoreCannotSave() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T10:00:00Z")
        #expect(!AdminEvaluateModel.canSave(game: game, homeScore: "", awayScore: "1", now: now))
        #expect(!AdminEvaluateModel.canSave(game: game, homeScore: "2", awayScore: "", now: now))
    }

    @Test func nonNumericScoreCannotSave() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T10:00:00Z")
        #expect(!AdminEvaluateModel.canSave(game: game, homeScore: "x", awayScore: "1", now: now))
    }

    @Test func alreadyEvaluatedGameCannotSave() throws {
        let game = try makeGame(id: 1, start: "2026-06-15T10:00:00Z", status: 1)
        #expect(!AdminEvaluateModel.canSave(game: game, homeScore: "2", awayScore: "1", now: now))
    }

    @Test func exactKickoffInstantCannotSave() throws {
        // Web: isBefore(start, now) is strict — the exact instant is not "started".
        let game = try makeGame(id: 1, start: "2026-06-15T12:00:00Z")
        #expect(!AdminEvaluateModel.canSave(game: game, homeScore: "2", awayScore: "1", now: now))
    }
}

@Suite struct AdminEvaluateConfirmCopyTests {
    @Test func confirmQuestionMatchesWebCopy() {
        let question = AdminEvaluateModel.confirmQuestion(
            homeTeam: "Sweden", awayTeam: "Poland", homeScore: "2", awayScore: "1"
        )
        #expect(question == "Report that Sweden - Poland ended 2 - 1? Make sure the score is correct")
    }

    @Test func confirmQuestionFallsBackForMissingTeams() {
        let question = AdminEvaluateModel.confirmQuestion(
            homeTeam: nil, awayTeam: "Poland", homeScore: "0", awayScore: "0"
        )
        #expect(question == "Report that ? - Poland ended 0 - 0? Make sure the score is correct")
    }
}

@Suite struct AdminEvaluateModelTests {
    private func makeModel() -> (AdminEvaluateModel, MockTransport) {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())
        return (AdminEvaluateModel(api: api), transport)
    }

    @Test func selectFetchesDetailsAndFiltersPendingGames() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            MockTransport.json(tournamentJSON(id: 7), url: request.url)
        }

        try await model.select(tournamentID: 7)

        #expect(transport.requests.count == 1)
        #expect(transport.requests[0].url?.path.hasSuffix("/tournament/7") == true)
        #expect(model.selectedTournamentID == 7)
        // Evaluated game 12 dropped; the rest ordered by kickoff (11 before 10).
        #expect(model.pendingGames.map(\.id) == [11, 10])
    }

    @Test func reselectingTheSameTournamentDoesNotRefetch() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            MockTransport.json(tournamentJSON(id: 7), url: request.url)
        }

        try await model.select(tournamentID: 7)
        try await model.select(tournamentID: 7)

        #expect(transport.requests.count == 1)
    }

    @Test func selectingAnotherTournamentRefetches() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            let id = Int(request.url?.lastPathComponent ?? "") ?? 0
            return MockTransport.json(tournamentJSON(id: id), url: request.url)
        }

        try await model.select(tournamentID: 7)
        try await model.select(tournamentID: 8)

        #expect(transport.requests.count == 2)
        #expect(transport.requests[1].url?.path.hasSuffix("/tournament/8") == true)
        #expect(model.details?.id == 8)
    }

    @Test func failedSelectFlagsLoadFailureAndRethrows() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            MockTransport.json(#"{"error":"boom"}"#, status: 500, url: request.url)
        }

        await #expect(throws: APIError.self) {
            try await model.select(tournamentID: 7)
        }
        #expect(model.loadFailed)
        #expect(model.details == nil)
    }

    @Test func evaluatePostsNumericScoresAndRefreshesTheTournament() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            if request.url?.path.hasSuffix("/evaluategame") == true {
                return MockTransport.json("{}", url: request.url)
            }
            return MockTransport.json(tournamentJSON(id: 7), url: request.url)
        }
        try await model.select(tournamentID: 7)
        let game = try makeGame(id: 10, start: "2026-06-14T18:00:00Z")

        try await model.evaluate(game: game, homeScore: 2, awayScore: 1)

        #expect(transport.requests.count == 3) // select GET + POST + refresh GET
        let post = transport.requests[1]
        #expect(post.httpMethod == "POST")
        #expect(post.url?.path.hasSuffix("/evaluategame") == true)
        let body = try JSONSerialization.jsonObject(with: post.httpBody ?? Data()) as? [String: Int]
        #expect(body == ["game_id": 10, "home_team_score": 2, "away_team_score": 1])
        #expect(transport.requests[2].url?.path.hasSuffix("/tournament/7") == true)
    }

    @Test func evaluateFailureThrowsGoneAndSkipsTheRefresh() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            if request.url?.path.hasSuffix("/evaluategame") == true {
                return MockTransport.json(#"{"error":"already processed"}"#, status: 410, url: request.url)
            }
            return MockTransport.json(tournamentJSON(id: 7), url: request.url)
        }
        try await model.select(tournamentID: 7)
        let game = try makeGame(id: 10, start: "2026-06-14T18:00:00Z")

        do {
            try await model.evaluate(game: game, homeScore: 2, awayScore: 1)
            Issue.record("expected a 410 to throw")
        } catch let error as APIError {
            guard case .gone = error else {
                Issue.record("expected .gone, got \(error)")
                return
            }
        }
        #expect(transport.requests.count == 2) // select GET + failed POST, no refresh
        #expect(model.pendingGames.map(\.id) == [11, 10]) // details untouched
    }
}
