import Testing
import Foundation
@testable import Betty

struct GameDisplayStateTests {
    private func game(status: Int?, liveStatus: Int?) -> Game {
        let json = """
        {"id":1,"tournament_id":1,"pool_id":1,"home_team_id":1,"away_team_id":2,
         "home_team_score":0,"away_team_score":0,"start_date":"2026-06-21T12:00:00Z",
         "updated_at":null,"status":\(status.map(String.init) ?? "null"),
         "live_home_team_score":1,"live_away_team_score":0,
         "live_status":\(liveStatus.map(String.init) ?? "null")}
        """.data(using: .utf8)!
        return try! JSONCoding.makeDecoder().decode(Game.self, from: json)
    }

    @Test func finishedBeatsEverything() {
        #expect(game(status: 1, liveStatus: 1).displayState == .finished)
        #expect(game(status: 1, liveStatus: 2).displayState == .finished)
    }
    @Test func fullTimeWhenLiveStatusTwo() {
        #expect(game(status: nil, liveStatus: 2).displayState == .fullTime)
    }
    @Test func liveWhenLiveStatusOne() {
        #expect(game(status: nil, liveStatus: 1).displayState == .live)
    }
    @Test func scheduledOtherwise() {
        #expect(game(status: nil, liveStatus: nil).displayState == .scheduled)
        #expect(game(status: 0, liveStatus: 0).displayState == .scheduled)
    }

    @Test func decodesLiveScoreUpdateEvent() {
        let data = """
        {"type":"live_score_update","message":{"game_id":11,"home_team_score":2,"away_team_score":1,"live_status":1}}
        """.data(using: .utf8)!
        guard case .liveScoreUpdate(let p) = BettyEvent.decode(from: data) else {
            Issue.record("expected liveScoreUpdate"); return
        }
        #expect(p.gameID == 11)
        #expect(p.homeTeamScore == 2)
        #expect(p.awayTeamScore == 1)
        #expect(p.liveStatus == 1)
    }
}
