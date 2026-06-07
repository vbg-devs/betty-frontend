import Foundation

/// `GET /tournament/:id` returns FLAT sibling `pools[]` and `games[]` arrays — games
/// reference pools via `pool_id`. `pool.games` / `game.pool` are CLIENT-SIDE joins
/// (see `games(inPool:)` / `poolsWithGames`), never wire fields.
///
/// In `GET /tournaments` both `pools` and `games` are `null`. The detail route 404s when
/// the tournament doesn't exist OR has already ended (`end_date <= NOW()`).
nonisolated struct Tournament: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let imageURL: String?
    let startDate: Date
    let endDate: Date?
    let categoryID: Int
    let pools: [Pool]?
    let games: [Game]?

    /// Web rule: running when `end_date` missing or `end_date >= now`.
    func isRunning(at now: Date = Date()) -> Bool {
        guard let endDate else { return true }
        return endDate >= now
    }

    // MARK: client-side joins

    func games(inPool poolID: Int) -> [Game] {
        (games ?? []).filter { $0.poolID == poolID }
    }

    var poolsWithGames: [PoolGames] {
        (pools ?? []).map { PoolGames(pool: $0, games: games(inPool: $0.id)) }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, pools, games
        case imageURL = "image_url"
        case startDate = "start_date"
        case endDate = "end_date"
        case categoryID = "category_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        categoryID = try c.decodeIfPresent(Int.self, forKey: .categoryID) ?? 0
        pools = try c.decodeIfPresent([Pool].self, forKey: .pools)
        games = try c.decodeIfPresent([Game].self, forKey: .games)
    }
}

/// A pool joined with its games — derived value, not a wire shape.
nonisolated struct PoolGames: Identifiable, Hashable, Sendable {
    let pool: Pool
    let games: [Game]
    var id: Int { pool.id }
}

nonisolated struct Pool: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let tournamentID: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case tournamentID = "tournament_id"
    }
}

/// `Game.status` is a NULLABLE int — `status == 1` means finished, anything else
/// (including nil) is not final. Scores are non-null ints on the wire (0 before play),
/// modeled as `Int?` defensively.
nonisolated struct Game: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let tournamentID: Int
    let poolID: Int
    let homeTeamID: Int
    let awayTeamID: Int
    let homeTeamScore: Int?
    let awayTeamScore: Int?
    let startDate: Date
    let updatedAt: Date?
    let status: Int?

    var isFinished: Bool { status == 1 }

    /// LIVE window: not finished, kicked off, and within 150 minutes of kickoff.
    func isLive(at now: Date = Date()) -> Bool {
        !isFinished && now > startDate && now < startDate.addingTimeInterval(150 * 60)
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case tournamentID = "tournament_id"
        case poolID = "pool_id"
        case homeTeamID = "home_team_id"
        case awayTeamID = "away_team_id"
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
        case startDate = "start_date"
        case updatedAt = "updated_at"
    }
}

/// Body for `PUT /game/:id` — both fields `binding:"required"`, so a 0 score is rejected
/// with 400 (use `POST /evaluategame` for 0-goal results). No admin check server-side;
/// keep off non-admin UI.
nonisolated struct SetGameScoreRequest: Encodable, Sendable {
    var homeTeamScore: Int
    var awayTeamScore: Int

    enum CodingKeys: String, CodingKey {
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
    }
}

/// Body for `POST /evaluategame` (admin) — scores >= 0 allowed here.
nonisolated struct EvaluateGameRequest: Encodable, Sendable {
    var gameID: Int
    var homeTeamScore: Int
    var awayTeamScore: Int

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
    }
}
