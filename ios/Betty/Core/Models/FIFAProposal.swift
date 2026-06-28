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
    /// Kickoff for the mapped betty game. Optional: the backend enrichment can omit it,
    /// and Go's zero time serializes as `0001-01-01T00:00:00Z` — both mean "no kickoff"
    /// and render nothing rather than a sentinel date.
    let gameStartDate: Date?

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
        // Parse the raw string ourselves (not as `Date`) so a present-but-unparseable or
        // Go zero-time kickoff degrades to `nil` instead of throwing and aborting the
        // entire `[FIFAProposal]` decode over a single malformed row.
        let rawStartDate = (try? c.decodeIfPresent(String.self, forKey: .gameStartDate)) ?? nil
        if let rawStartDate, !rawStartDate.hasPrefix("0001-") {
            gameStartDate = JSONCoding.parseRFC3339(rawStartDate)
        } else {
            gameStartDate = nil
        }
    }
}

/// A confirmed-mapped FIFA final betty has not settled and has no pending proposal for
/// (e.g. an extra-time knockout whose detail will not reconcile), surfaced so an admin
/// can settle it by hand. Wire shape: betty-api `GET /admin/fifa/unsettled-finals`.
nonisolated struct FIFAUnsettledFinal: Decodable, Identifiable, Hashable, Sendable {
    let competitionID: String
    let gameID: Int
    let matchID: String
    let homeTeam: String
    let awayTeam: String
    /// Kickoff (UTC). Optional: a missing/Go-zero/unparseable time degrades to nil
    /// instead of throwing and aborting the whole `[FIFAUnsettledFinal]` decode.
    let startTime: Date?

    /// FIFA match id is unique per match, so it is a stable SwiftUI list identity.
    var id: String { matchID }

    enum CodingKeys: String, CodingKey {
        case competitionID = "competition_id"
        case gameID = "game_id"
        case matchID = "match_id"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case startTime = "start_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        competitionID = try c.decodeIfPresent(String.self, forKey: .competitionID) ?? ""
        gameID = try c.decode(Int.self, forKey: .gameID)
        matchID = try c.decode(String.self, forKey: .matchID)
        homeTeam = try c.decodeIfPresent(String.self, forKey: .homeTeam) ?? ""
        awayTeam = try c.decodeIfPresent(String.self, forKey: .awayTeam) ?? ""
        let rawStart = (try? c.decodeIfPresent(String.self, forKey: .startTime)) ?? nil
        if let rawStart, !rawStart.hasPrefix("0001-") {
            startTime = JSONCoding.parseRFC3339(rawStart)
        } else {
            startTime = nil
        }
    }
}
