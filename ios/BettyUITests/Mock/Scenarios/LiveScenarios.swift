import Foundation

/// Wire-format payload builders for the Live suite's WebSocket pushes — shapes per
/// docs/mobile/api-contract.md §4 (verified against the Go source: string user UIDs,
/// zero timestamps on bet echoes, the capital-G `"Games"` key).
enum LiveWire {
    /// Go's zero time — what the backend serializes for never-set timestamps.
    static let zeroTime = "0001-01-01T00:00:00Z"

    static func iso(_ date: Date) -> String {
        date.ISO8601Format()
    }

    /// `bet_placed` / `bet_updated` payload — the backend echoes the request:
    /// `id` 0 on placement (real id on update), zero timestamps, `user_points` null.
    static func bet(userID: String, gameID: Int, groupID: Int,
                    home: Int, away: Int, id: Int = 0, isUniversal: Bool = false) -> [String: Any] {
        [
            "id": id,
            "user_id": userID,
            "game_id": gameID,
            "group_id": groupID,
            "user_points": NSNull(),
            "home_team_score": home,
            "away_team_score": away,
            "is_universal": isUniversal,
            "processed_at": NSNull(),
            "created_at": zeroTime,
            "updated_at": zeroTime,
        ]
    }

    /// `user_register` payload — the full User object of the new signup.
    static func user(id: String, email: String, name: String) -> [String: Any] {
        [
            "id": id,
            "email": email,
            "name": name,
            "image_url": NSNull(),
            "firebase_image_url": NSNull(),
            "country": NSNull(),
            "is_admin": false,
            "PushTokens": NSNull(),
            "created_at": zeroTime,
            "updated_at": zeroTime,
        ]
    }

    /// `evaluate_game` — "full time / refresh scores".
    static func evaluateGame(gameID: Int, home: Int, away: Int) -> [String: Any] {
        ["game_id": gameID, "home_team_score": home, "away_team_score": away]
    }

    /// `group_joined` — `who: nil` sends the empty string the web falls back from.
    static func groupJoined(groupID: Int, name: String, who: String?) -> [String: Any] {
        ["group": ["id": groupID, "name": name], "who": who ?? ""]
    }

    /// `game_starting_soon` — NOTE the capital-G `"Games"` key (Go struct field
    /// without a json tag).
    static func gameStartingSoon(gameID: Int, startDate: Date) -> [String: Any] {
        ["Games": [["id": gameID, "start_date": iso(startDate)]]]
    }
}

extension MockScenario {
    /// Appends a chat message as a pure server-side change — there are no
    /// message-board events on the wire, so only the app's 10 s poll can surface it.
    mutating func addServerSideMessage(id: Int, groupID: Int, userID: String, body: String) {
        messages.append(MockMessage(id: id, groupID: groupID, userID: userID,
                                    body: body, createdAt: Date()))
    }
}
