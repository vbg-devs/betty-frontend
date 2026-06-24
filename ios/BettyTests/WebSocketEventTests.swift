import Foundation
import Testing
@testable import Betty

/// Pins the `{type, message}` envelope decoding — including the capital-G `"Games"` key
/// and the unknown-type fallback.
@Suite struct WebSocketEventTests {
    @Test func pingDecodes() {
        let event = BettyEvent.decode(from: Data(#"{"type":"ping","message":null}"#.utf8))
        #expect(event == .ping)
    }

    @Test func gameStartingSoonUsesCapitalGamesKey() throws {
        let json = """
        {"type":"game_starting_soon","message":{"Games":[{"id":9,"start_date":"2026-06-10T18:00:00Z"}]}}
        """
        let event = BettyEvent.decode(from: Data(json.utf8))
        guard case .gameStartingSoon(let payload) = event else {
            Issue.record("expected gameStartingSoon, got \(String(describing: event))")
            return
        }
        #expect(payload.games.first?.id == 9)
    }

    @Test func groupJoinedDecodesGroupRefAndWho() throws {
        let json = """
        {"type":"group_joined","message":{"group":{"id":7,"name":"Office League"},"who":"Ada"}}
        """
        let event = BettyEvent.decode(from: Data(json.utf8))
        guard case .groupJoined(let payload) = event else {
            Issue.record("expected groupJoined, got \(String(describing: event))")
            return
        }
        #expect(payload.group?.id == 7)
        #expect(payload.who == "Ada")
    }

    @Test func evaluateGameDecodesScores() throws {
        let json = """
        {"type":"evaluate_game","message":{"game_id":9,"home_team_score":2,"away_team_score":1}}
        """
        let event = BettyEvent.decode(from: Data(json.utf8))
        #expect(event == .evaluateGame(WSEvaluateGame(gameID: 9, homeTeamScore: 2, awayTeamScore: 1)))
    }

    @Test func betPlacedDecodesEchoShape() throws {
        let json = """
        {"type":"bet_placed","message":{
          "id":0,"user_id":"uid-1","game_id":9,"group_id":7,
          "user_points":null,"home_team_score":2,"away_team_score":1,
          "is_universal":true,"processed_at":null,
          "created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}}
        """
        let event = BettyEvent.decode(from: Data(json.utf8))
        guard case .betPlaced(let bet) = event else {
            Issue.record("expected betPlaced, got \(String(describing: event))")
            return
        }
        #expect(bet.userID == "uid-1")
        #expect(bet.id == 0)
    }

    @Test func unknownTypeFallsBackWithRawPayload() throws {
        let json = #"{"type":"something_new","message":{"answer":42}}"#
        let event = BettyEvent.decode(from: Data(json.utf8))
        guard case .unknown(let type, let message) = event else {
            Issue.record("expected unknown, got \(String(describing: event))")
            return
        }
        #expect(type == "something_new")
        #expect(message?.objectValue?["answer"] == .number(42))
    }

    @Test func userExactScoreDefaultsMissingUserIDs() throws {
        let json = #"{"type":"user_exact_score","message":{"game_id":9}}"#
        let event = BettyEvent.decode(from: Data(json.utf8))
        guard case .userExactScore(let payload) = event else {
            Issue.record("expected userExactScore, got \(String(describing: event))")
            return
        }
        #expect(payload.userIDs.isEmpty)
    }

    @Test func decodesLoneRangerAwarded() throws {
        let json = #"{"type":"lone_ranger_awarded","message":{"game_id":1,"user_ids":["a"]}}"#
        let event = BettyEvent.decode(from: Data(json.utf8))
        guard case .loneRangerAwarded(let payload) = event else {
            Issue.record("expected loneRangerAwarded, got \(String(describing: event))")
            return
        }
        #expect(payload.gameID == 1)
        #expect(payload.userIDs == ["a"])
        #expect(event?.typeName == "lone_ranger_awarded")
    }

    @Test func loneRangerAwardedDefaultsMissingUserIDs() throws {
        let json = #"{"type":"lone_ranger_awarded","message":{"game_id":9}}"#
        let event = BettyEvent.decode(from: Data(json.utf8))
        guard case .loneRangerAwarded(let payload) = event else {
            Issue.record("expected loneRangerAwarded, got \(String(describing: event))")
            return
        }
        #expect(payload.userIDs.isEmpty)
    }
}

private extension WSEvaluateGame {
    /// Decodable-only struct — round-trip through JSON for test construction.
    init(gameID: Int, homeTeamScore: Int, awayTeamScore: Int) {
        let json = #"{"game_id":\#(gameID),"home_team_score":\#(homeTeamScore),"away_team_score":\#(awayTeamScore)}"#
        self = try! JSONCoding.makeDecoder().decode(WSEvaluateGame.self, from: Data(json.utf8))
    }
}
