import Foundation

/// Serializes scenario entities to the EXACT Betty wire format (api-contract.md):
/// snake_case keys, RFC 3339 UTC times, Go zero time `0001-01-01T00:00:00Z`, the
/// `PushTokens: null` quirk, `is_public` always false on reads, `mode` vs `bet_mode`
/// naming, flat sibling `pools[]`/`games[]`, nullable `Game.status`.
enum MockWire {
    static let zeroTime = "0001-01-01T00:00:00Z"

    static func time(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle())
    }

    static func time(_ date: Date?) -> Any {
        date.map { time($0) as Any } ?? NSNull()
    }

    static func orNull<T>(_ value: T?) -> Any {
        value.map { $0 as Any } ?? NSNull()
    }

    static func parseTime(_ raw: Any?) -> Date? {
        guard let string = raw as? String else { return nil }
        if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        return try? Date(string, strategy: Date.ISO8601FormatStyle())
    }

    // MARK: - Users

    static func user(_ u: MockUser, zeroTimestamps: Bool = false) -> [String: Any] {
        [
            "id": u.id,
            "email": u.email,
            "name": u.name,
            "image_url": orNull(u.imageURL),
            "firebase_image_url": orNull(u.firebaseImageURL),
            "country": orNull(u.country),
            "created_at": zeroTimestamps ? zeroTime : time(u.createdAt),
            "updated_at": zeroTimestamps ? zeroTime : time(u.createdAt),
            "is_admin": zeroTimestamps ? false : u.isAdmin,
            "PushTokens": NSNull(),
        ]
    }

    // MARK: - Groups

    static func member(_ m: MockMember, in scenario: MockScenario) -> [String: Any] {
        let user = scenario.user(m.userID)
        return [
            "user_id": m.userID,
            "name": orNull(user?.name),
            "nickname": orNull(m.nickname),
            "image_url": orNull(user?.imageURL),
            "score": m.score,
            "normalized_score": m.normalizedScore,
            "access_level": m.accessLevel,
        ]
    }

    static func group(_ g: MockGroup, in scenario: MockScenario) -> [String: Any] {
        let tournament = scenario.tournament(g.tournamentID)
        return [
            "id": g.id,
            "name": g.name,
            "tournament_id": g.tournamentID,
            "tournament_name": tournament?.name ?? "",
            "tournament_image_url": orNull(tournament?.imageURL),
            "header_image_url": orNull(g.headerImageURL),
            "invite_code": g.inviteCode,
            "invite_url": "https://betty.social/dashboard/groups/join/\(g.inviteCode)",
            "welcome_message": orNull(g.welcomeMessage),
            "description": orNull(g.description),
            "correct_team_points": g.correctTeamPoints,
            "exact_result_points": g.exactResultPoints,
            "allow_sneak_peek": g.allowSneakPeek,
            "group_play_deadline": time(g.groupPlayDeadline),
            "mode": g.mode,
            "is_public": false, // db:"-" — ALWAYS false on reads; derive from public_at
            "public_at": time(g.publicAt),
            "created_at": time(g.createdAt),
            "updated_at": time(g.updatedAt),
            "members": g.members.filter { $0.status == .active }.map { member($0, in: scenario) },
        ]
    }

    /// `GET /user/:id/groups` row — 1-based standard competition ranking by score.
    static func placement(_ g: MockGroup, of m: MockMember, in scenario: MockScenario) -> [String: Any] {
        let active = g.members.filter { $0.status == .active }
        let rank = 1 + active.filter { $0.score > m.score }.count
        let tournament = scenario.tournament(g.tournamentID)
        return [
            "id": g.id,
            "name": g.name,
            "tournament_id": g.tournamentID,
            "tournament_name": tournament?.name ?? "",
            "tournament_image_url": orNull(tournament?.imageURL),
            "header_image_url": orNull(g.headerImageURL),
            "bet_mode": g.mode, // named bet_mode HERE, mode on Group
            "public_at": time(g.publicAt),
            "created_at": time(g.createdAt),
            "score": m.score,
            "normalized_score": m.normalizedScore,
            "placement": rank,
            "member_count": active.count,
        ]
    }

    static func publicGroupItem(_ g: MockGroup, callerID: String, in scenario: MockScenario) -> [String: Any] {
        let tournament = scenario.tournament(g.tournamentID)
        return [
            "id": g.id,
            "name": g.name,
            "description": orNull(g.description),
            "tournament_id": g.tournamentID,
            "tournament_name": tournament?.name ?? "",
            "tournament_image_url": orNull(tournament?.imageURL),
            "header_image_url": orNull(g.headerImageURL),
            "correct_team_points": g.correctTeamPoints,
            "exact_result_points": g.exactResultPoints,
            "allow_sneak_peek": g.allowSneakPeek,
            "bet_mode": g.mode,
            "group_play_deadline": time(g.groupPlayDeadline),
            "public_at": time(g.publicAt ?? Date()),
            "created_at": time(g.createdAt),
            "member_count": g.members.filter { $0.status == .active }.count,
            "is_member": g.isActiveMember(callerID),
        ]
    }

    static func groupPeek(_ g: MockGroup, in scenario: MockScenario) -> [String: Any] {
        let tournament = scenario.tournament(g.tournamentID)
        return [
            "id": g.id,
            "name": g.name,
            "description": orNull(g.description),
            "tournament_id": g.tournamentID,
            "tournament_name": tournament?.name ?? "",
            "tournament_image_url": orNull(tournament?.imageURL),
            "header_image_url": orNull(g.headerImageURL),
            "invite_code": g.inviteCode,
        ]
    }

    // MARK: - Bets

    static func bet(_ b: MockBet) -> [String: Any] {
        [
            "id": b.id,
            "user_id": b.userID,
            "game_id": b.gameID,
            "group_id": b.groupID,
            "user_points": orNull(b.userPoints),
            "home_team_score": b.homeTeamScore,
            "away_team_score": b.awayTeamScore,
            "is_universal": false, // request-only flag — never stored
            "processed_at": time(b.processedAt),
            "created_at": time(b.createdAt),
            "updated_at": time(b.updatedAt),
        ]
    }

    /// The `POST /bet` 200 body: a request echo with `id: 0` and zero timestamps.
    static func betEcho(userID: String, gameID: Int, groupID: Int,
                        home: Int, away: Int, isUniversal: Bool) -> [String: Any] {
        [
            "id": 0,
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

    // MARK: - Tournaments

    static func pool(_ p: MockPool) -> [String: Any] {
        ["id": p.id, "tournament_id": p.tournamentID, "name": p.name]
    }

    static func game(_ g: MockGame) -> [String: Any] {
        [
            "id": g.id,
            "tournament_id": g.tournamentID,
            "pool_id": g.poolID,
            "home_team_id": g.homeTeamID,
            "away_team_id": g.awayTeamID,
            "home_team_score": g.homeTeamScore, // non-null ints, always present
            "away_team_score": g.awayTeamScore,
            "start_date": time(g.startDate),
            "updated_at": time(g.updatedAt),
            "status": orNull(g.status), // int|null
        ]
    }

    /// `details: false` → list shape (`pools`/`games` are null);
    /// `details: true` → FLAT sibling `pools[]` + `games[]` (games by start_date).
    static func tournament(_ t: MockTournament, details: Bool) -> [String: Any] {
        [
            "id": t.id,
            "name": t.name,
            "image_url": orNull(t.imageURL),
            "start_date": time(t.startDate),
            "end_date": time(t.endDate),
            "category_id": t.categoryID,
            "pools": details ? t.pools.map { pool($0) } : NSNull(),
            "games": details
                ? t.games.sorted { $0.startDate < $1.startDate }.map { game($0) }
                : NSNull(),
        ]
    }

    // MARK: - Reference data

    static func team(_ t: MockTeam) -> [String: Any] {
        [
            "id": t.id,
            "tournament_id": t.tournamentID,
            "image_url": orNull(t.imageURL),
            "name": t.name,
            "is_placeholder": t.isPlaceholder,
        ]
    }

    static func category(_ c: MockCategory) -> [String: Any] {
        ["id": c.id, "name": c.name]
    }

    static func country(_ c: MockCountry) -> [String: Any] {
        ["code": c.code, "name": c.name, "flag_emoji": orNull(c.flagEmoji)]
    }

    static func arena(_ a: MockArena) -> [String: Any] {
        ["id": a.id, "name": a.name, "country": a.country, "city": a.city,
         "capacity": a.capacity, "image_url": a.imageURL]
    }

    // MARK: - Message board

    static func reaction(_ r: MockReaction) -> [String: Any] {
        ["user_id": r.userID, "emoji_id": r.emojiID, "created_at": time(r.createdAt)]
    }

    /// `reactions` is `[]` on GET but the literal `null` in the POST 201 echo.
    static func message(_ m: MockMessage, nullReactions: Bool = false) -> [String: Any] {
        [
            "id": m.id,
            "group_id": m.groupID,
            "user_id": m.userID,
            "image_url": orNull(m.imageURL),
            "body": orNull(m.body),
            "created_at": time(m.createdAt),
            "reactions": nullReactions ? NSNull() : m.reactions.map { reaction($0) },
        ]
    }

    // MARK: - Announcements

    static func announcement(_ a: MockAnnouncement) -> [String: Any] {
        var json: [String: Any] = [
            "id": a.id,
            "user_id": a.userID,
            "title": a.title,
            "body": a.body,
            "category": a.category,
            "created_at": time(a.createdAt),
        ]
        if let cta = a.cta { json["cta"] = cta } // omitempty
        return json
    }

    // MARK: - Presigned uploads

    static func presignedUpload(key: String, httpBase: String,
                                contentType: String, contentLength: Int) -> [String: Any] {
        [
            "key": key,
            "upload_url": "\(httpBase)/_upload/\(key)",
            "method": "PUT",
            // Go http.Header — map of string → ARRAY of strings.
            "headers": [
                "Content-Length": [String(contentLength)],
                "Content-Type": [contentType],
            ],
            "public_url": "\(httpBase)/_public/\(key)",
            "expires_at": time(Date().addingTimeInterval(300)),
        ]
    }

    // MARK: - Firebase identity

    static func firebaseError(_ message: String) -> MockHTTPResponse {
        .json([
            "error": [
                "code": 400,
                "message": message,
                "errors": [["message": message, "domain": "global", "reason": "invalid"]],
            ],
        ], status: 400)
    }
}
