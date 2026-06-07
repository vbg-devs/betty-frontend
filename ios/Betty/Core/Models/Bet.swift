import Foundation

/// `bets.Bet` — `user_id` is a Firebase UID STRING. `user_points` is null until the game
/// is evaluated. `is_universal` is request-only (always false in GET responses).
///
/// The `POST /bet` 200 body is a request echo: `id: 0`, zero timestamps,
/// `user_points: null` — re-fetch via `GET /bets/bygame/...` to learn the real id.
/// `bet.user` is a CLIENT-SIDE join (see `Group.member(withUserID:)`), never a wire field.
nonisolated struct Bet: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let userID: String
    let gameID: Int
    let groupID: Int
    let userPoints: Int?
    let homeTeamScore: Int
    let awayTeamScore: Int
    let isUniversal: Bool
    let processedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var isProcessed: Bool { processedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case gameID = "game_id"
        case groupID = "group_id"
        case userPoints = "user_points"
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
        case isUniversal = "is_universal"
        case processedAt = "processed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        userID = try c.decode(String.self, forKey: .userID)
        gameID = try c.decode(Int.self, forKey: .gameID)
        groupID = try c.decodeIfPresent(Int.self, forKey: .groupID) ?? 0
        userPoints = try c.decodeIfPresent(Int.self, forKey: .userPoints)
        homeTeamScore = try c.decode(Int.self, forKey: .homeTeamScore)
        awayTeamScore = try c.decode(Int.self, forKey: .awayTeamScore)
        isUniversal = try c.decodeIfPresent(Bool.self, forKey: .isUniversal) ?? false
        processedAt = try c.decodeIfPresent(Date.self, forKey: .processedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }
}

/// Body for `POST /bet`. With `is_universal: true` the bet is upserted into EVERY group
/// the caller belongs to in the game's tournament (`group_id` then irrelevant).
/// Success is **200** (not 201); **423** means the game already started.
nonisolated struct PlaceBetRequest: Encodable, Sendable {
    var gameID: Int
    var groupID: Int
    var homeTeamScore: Int
    var awayTeamScore: Int
    var isUniversal: Bool

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case groupID = "group_id"
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
        case isUniversal = "is_universal"
    }
}

/// Body for `PUT /bet/:id` — only the scores are used server-side (id mirrors the web body).
nonisolated struct UpdateBetRequest: Encodable, Sendable {
    var id: Int
    var homeTeamScore: Int
    var awayTeamScore: Int

    enum CodingKeys: String, CodingKey {
        case id
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
    }
}
