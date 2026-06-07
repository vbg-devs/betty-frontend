import Foundation
@testable import Betty

/// JSON-decoded wire fixtures for the GroupDetail logic tests (response models are
/// Decodable-only; `Member` is the one with a memberwise init).
enum GroupDetailFixtures {
    static func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }

    static func rfc3339(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func game(
        id: Int = 1,
        poolID: Int = 1,
        start: Date,
        status: Int? = nil,
        homeScore: Int? = 0,
        awayScore: Int? = 0,
        homeTeamID: Int = 10,
        awayTeamID: Int = 20
    ) -> Game {
        let json = """
        {
          "id": \(id),
          "tournament_id": 1,
          "pool_id": \(poolID),
          "home_team_id": \(homeTeamID),
          "away_team_id": \(awayTeamID),
          "home_team_score": \(homeScore.map(String.init) ?? "null"),
          "away_team_score": \(awayScore.map(String.init) ?? "null"),
          "start_date": "\(rfc3339(start))",
          "updated_at": null,
          "status": \(status.map(String.init) ?? "null")
        }
        """
        return try! JSONCoding.makeDecoder().decode(Game.self, from: Data(json.utf8))
    }

    static func bet(
        id: Int = 1,
        userID: String = "uid-1",
        gameID: Int = 1,
        groupID: Int = 1,
        userPoints: Int? = nil,
        homeScore: Int = 0,
        awayScore: Int = 0,
        processed: Bool = false
    ) -> Bet {
        let json = """
        {
          "id": \(id),
          "user_id": "\(userID)",
          "game_id": \(gameID),
          "group_id": \(groupID),
          "user_points": \(userPoints.map(String.init) ?? "null"),
          "home_team_score": \(homeScore),
          "away_team_score": \(awayScore),
          "is_universal": false,
          "processed_at": \(processed ? "\"2026-01-01T00:00:00Z\"" : "null"),
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z"
        }
        """
        return try! JSONCoding.makeDecoder().decode(Bet.self, from: Data(json.utf8))
    }

    static func pool(id: Int, name: String) -> Pool {
        let json = """
        {"id": \(id), "tournament_id": 1, "name": "\(name)"}
        """
        return try! JSONCoding.makeDecoder().decode(Pool.self, from: Data(json.utf8))
    }

    static func member(
        userID: String,
        name: String? = nil,
        nickname: String? = nil,
        score: Int = 0
    ) -> Member {
        Member(
            userID: userID,
            name: name ?? "User \(userID)",
            nickname: nickname,
            imageURL: nil,
            score: score,
            normalizedScore: Double(score),
            accessLevel: 2
        )
    }

    /// Fixed UTC gregorian calendar so date-label tests are timezone-independent.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
}
