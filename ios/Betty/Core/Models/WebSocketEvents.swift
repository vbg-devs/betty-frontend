import Foundation

// Envelope (server -> client): {"type": "<string>", "message": <any|null>}.
// Event types are the pubsub subjects minus the "betty_events." prefix.

nonisolated struct WSGroupRef: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
}

/// `group_joined`: `{ "group": { "id": 1, "name": "..." }, "who": "<user name>" }`
nonisolated struct WSGroupJoined: Decodable, Hashable, Sendable {
    let group: WSGroupRef?
    let who: String?
}

/// `group_visibility_changed`: `{ "group_id": 1, "public_at": "time|null" }`
nonisolated struct WSVisibilityChanged: Decodable, Hashable, Sendable {
    let groupID: Int?
    let publicAt: Date?

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case publicAt = "public_at"
    }
}

/// `evaluate_game`: `{ "game_id": 1, "home_team_score": 2, "away_team_score": 1 }`
/// The web app treats this as "full time / refresh scores".
nonisolated struct WSEvaluateGame: Decodable, Hashable, Sendable {
    let gameID: Int
    let homeTeamScore: Int
    let awayTeamScore: Int

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
    }
}

/// `user_exact_score`: `{ "game_id": 1, "user_ids": ["uid", ...] }`
nonisolated struct WSExactScore: Decodable, Hashable, Sendable {
    let gameID: Int?
    let userIDs: [String]

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case userIDs = "user_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameID = try c.decodeIfPresent(Int.self, forKey: .gameID)
        userIDs = try c.decodeIfPresent([String].self, forKey: .userIDs) ?? []
    }
}

/// `lone_ranger_awarded`: `{ "game_id": 1, "user_ids": ["uid", ...] }`.
/// Same wire shape as `user_exact_score` (a distinct event so the feed can render
/// its own celebratory copy). Mirrors `WSExactScore` deliberately.
nonisolated struct WSLoneRanger: Decodable, Hashable, Sendable {
    let gameID: Int?
    let userIDs: [String]

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case userIDs = "user_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameID = try c.decodeIfPresent(Int.self, forKey: .gameID)
        userIDs = try c.decodeIfPresent([String].self, forKey: .userIDs) ?? []
    }
}

nonisolated struct WSGameRef: Decodable, Hashable, Sendable {
    let id: Int
    let startDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case startDate = "start_date"
    }
}

/// `game_starting_soon`: `{ "Games": [ { "id": 1, "start_date": "time" }, ... ] }`
/// NOTE the capital-G `"Games"` key (Go struct field without a json tag).
nonisolated struct WSGameStartingSoon: Decodable, Hashable, Sendable {
    let games: [WSGameRef]

    enum CodingKeys: String, CodingKey {
        case games = "Games"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        games = try c.decodeIfPresent([WSGameRef].self, forKey: .games) ?? []
    }
}

/// Typed WebSocket event. Unknown types decode as `.unknown` so the activity feed can
/// still render them generically (the web shows the raw type uppercased).
nonisolated enum BettyEvent: Hashable, Sendable {
    case ping
    case test(String?)
    case userRegister(UserProfile)
    case betPlaced(Bet)
    case betUpdated(Bet)
    /// `booster_applied` — payload is the updated `Bet` (same echo shape as
    /// `bet_placed` / `bet_updated`). Emitted on false→true transitions only.
    case boosterApplied(Bet)
    case groupJoined(WSGroupJoined)
    case groupLeft
    case groupCreated
    case groupVisibilityChanged(WSVisibilityChanged)
    case evaluateGame(WSEvaluateGame)
    case userExactScore(WSExactScore)
    /// `lone_ranger_awarded` — the set of lone-ranger winners for a game (one per
    /// qualifying group, aggregated across groups, like `user_exact_score`).
    case loneRangerAwarded(WSLoneRanger)
    case gameStartingSoon(WSGameStartingSoon)
    case unknown(type: String, message: JSONValue?)

    var typeName: String {
        switch self {
        case .ping: "ping"
        case .test: "test"
        case .userRegister: "user_register"
        case .betPlaced: "bet_placed"
        case .betUpdated: "bet_updated"
        case .boosterApplied: "booster_applied"
        case .groupJoined: "group_joined"
        case .groupLeft: "group_left"
        case .groupCreated: "group_created"
        case .groupVisibilityChanged: "group_visibility_changed"
        case .evaluateGame: "evaluate_game"
        case .userExactScore: "user_exact_score"
        case .loneRangerAwarded: "lone_ranger_awarded"
        case .gameStartingSoon: "game_starting_soon"
        case .unknown(let type, _): type
        }
    }

    private struct Envelope<T: Decodable>: Decodable {
        let type: String
        let message: T?
    }

    /// Decodes a raw WS frame. Returns nil only when the envelope itself is undecodable.
    /// A known type with an undecodable payload degrades to `.unknown`.
    static func decode(from data: Data) -> BettyEvent? {
        let decoder = JSONCoding.makeDecoder()
        guard let head = try? decoder.decode(Envelope<JSONValue>.self, from: data) else { return nil }

        func payload<T: Decodable>(_ type: T.Type) -> T? {
            (try? decoder.decode(Envelope<T>.self, from: data))?.message
        }
        func fallback() -> BettyEvent {
            .unknown(type: head.type, message: head.message)
        }

        switch head.type {
        case "ping":
            return .ping
        case "test":
            return .test(head.message?.stringValue)
        case "user_register":
            return payload(UserProfile.self).map { .userRegister($0) } ?? fallback()
        case "bet_placed":
            return payload(Bet.self).map { .betPlaced($0) } ?? fallback()
        case "bet_updated":
            return payload(Bet.self).map { .betUpdated($0) } ?? fallback()
        case "booster_applied":
            return payload(Bet.self).map { .boosterApplied($0) } ?? fallback()
        case "group_joined":
            return payload(WSGroupJoined.self).map { .groupJoined($0) } ?? fallback()
        case "group_left":
            return .groupLeft
        case "group_created":
            return .groupCreated
        case "group_visibility_changed":
            return payload(WSVisibilityChanged.self).map { .groupVisibilityChanged($0) } ?? fallback()
        case "evaluate_game":
            return payload(WSEvaluateGame.self).map { .evaluateGame($0) } ?? fallback()
        case "user_exact_score":
            return payload(WSExactScore.self).map { .userExactScore($0) } ?? fallback()
        case "lone_ranger_awarded":
            return payload(WSLoneRanger.self).map { .loneRangerAwarded($0) } ?? fallback()
        case "game_starting_soon":
            return payload(WSGameStartingSoon.self).map { .gameStartingSoon($0) } ?? fallback()
        default:
            return fallback()
        }
    }
}
