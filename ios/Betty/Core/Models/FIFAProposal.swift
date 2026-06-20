import Foundation

/// A staged FIFA result for a mapped betty game, enriched by the backend with the
/// game's team names + kickoff so the admin screen reads "Mexico 2 - 0 South Africa"
/// instead of an opaque id. Wire shape: betty-api `ProposalView` from
/// `GET /admin/fifa/proposals?status=`. The score is already oriented to betty's
/// home/away.
nonisolated struct FIFAProposal: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let gameID: Int
    let matchID: String
    let homeTeamScore: Int
    let awayTeamScore: Int
    /// "initial" | "correction" | "rollback".
    let kind: String
    /// "pending" | "applied" | "dismissed" | "superseded".
    let status: String
    /// "proposal" | "auto" — provenance, shown on the Applied tab.
    let source: String
    let prevHomeScore: Int?
    let prevAwayScore: Int?
    let gameHomeTeam: String
    let gameAwayTeam: String
    let gameStartDate: Date

    var isCorrection: Bool { kind == "correction" }

    enum CodingKeys: String, CodingKey {
        case id, kind, status, source
        case gameID = "game_id"
        case matchID = "match_id"
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
        case prevHomeScore = "prev_home_score"
        case prevAwayScore = "prev_away_score"
        case gameHomeTeam = "game_home_team"
        case gameAwayTeam = "game_away_team"
        case gameStartDate = "game_start_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        gameID = try c.decode(Int.self, forKey: .gameID)
        matchID = try c.decode(String.self, forKey: .matchID)
        homeTeamScore = try c.decode(Int.self, forKey: .homeTeamScore)
        awayTeamScore = try c.decode(Int.self, forKey: .awayTeamScore)
        kind = try c.decode(String.self, forKey: .kind)
        status = try c.decode(String.self, forKey: .status)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "proposal"
        prevHomeScore = try c.decodeIfPresent(Int.self, forKey: .prevHomeScore)
        prevAwayScore = try c.decodeIfPresent(Int.self, forKey: .prevAwayScore)
        gameHomeTeam = try c.decodeIfPresent(String.self, forKey: .gameHomeTeam) ?? ""
        gameAwayTeam = try c.decodeIfPresent(String.self, forKey: .gameAwayTeam) ?? ""
        gameStartDate = try c.decodeIfPresent(Date.self, forKey: .gameStartDate) ?? Date(timeIntervalSince1970: 0)
    }
}
