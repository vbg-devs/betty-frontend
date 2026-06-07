import Foundation

/// `groups.Member` — `user_id` is a Firebase UID STRING.
/// `access_level`: 0 author, 1 admin, 2 participant.
///
/// On `GET /tournament/:id/leaderboard` rows only `user_id`, `name`, `image_url`,
/// `normalized_score` are real (`score`/`access_level` are 0, `nickname` null).
nonisolated struct Member: Decodable, Identifiable, Hashable, Sendable {
    let userID: String
    let name: String?
    let nickname: String?
    let imageURL: String?
    let score: Int
    let normalizedScore: Double
    let accessLevel: Int

    var id: String { userID }
    var isAuthor: Bool { accessLevel == 0 }
    /// Web display rule everywhere: `nickname ?? name`.
    var displayName: String { nickname ?? name ?? "" }

    enum CodingKeys: String, CodingKey {
        case name, nickname, score
        case userID = "user_id"
        case imageURL = "image_url"
        case normalizedScore = "normalized_score"
        case accessLevel = "access_level"
    }

    init(userID: String, name: String?, nickname: String?, imageURL: String?,
         score: Int, normalizedScore: Double, accessLevel: Int) {
        self.userID = userID
        self.name = name
        self.nickname = nickname
        self.imageURL = imageURL
        self.score = score
        self.normalizedScore = normalizedScore
        self.accessLevel = accessLevel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(String.self, forKey: .userID)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        normalizedScore = try c.decodeIfPresent(Double.self, forKey: .normalizedScore) ?? 0
        accessLevel = try c.decodeIfPresent(Int.self, forKey: .accessLevel) ?? 2
    }
}

/// `groups.Group` — returned by `/groups`, `/groupbyid/:id`, `/group/:id/settings`.
///
/// Wire quirk: `is_public` is ALWAYS false on reads (`db:"-"`); publicness is derived
/// from `public_at != nil` (see `isPublic`). The bet-mode key is `mode` here but
/// `bet_mode` on `GroupPlacement`/`PublicGroupItem`.
nonisolated struct Group: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let tournamentID: Int
    let tournamentName: String
    let tournamentImageURL: String?
    let headerImageURL: String?
    let inviteCode: String
    let inviteURL: String
    let welcomeMessage: String?
    let description: String?
    let correctTeamPoints: Int
    let exactResultPoints: Int
    let allowSneakPeek: Bool
    let groupPlayDeadline: Date?
    let mode: Int
    let publicAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let members: [Member]

    /// Derived — `is_public` is unusable on reads.
    var isPublic: Bool { publicAt != nil }

    /// Client-side join: my member row (`Bet.user_id`/`Member.user_id` are UID strings).
    func member(withUserID userID: String?) -> Member? {
        guard let userID else { return nil }
        return members.first { $0.userID == userID }
    }

    /// Web invite link format (also the universal-link deep-link target).
    var inviteLink: URL? { URL(string: "https://betty.social/dashboard/groups/join/\(inviteCode)") }

    enum CodingKeys: String, CodingKey {
        case id, name, mode, members, description
        case tournamentID = "tournament_id"
        case tournamentName = "tournament_name"
        case tournamentImageURL = "tournament_image_url"
        case headerImageURL = "header_image_url"
        case inviteCode = "invite_code"
        case inviteURL = "invite_url"
        case welcomeMessage = "welcome_message"
        case correctTeamPoints = "correct_team_points"
        case exactResultPoints = "exact_result_points"
        case allowSneakPeek = "allow_sneak_peek"
        case groupPlayDeadline = "group_play_deadline"
        case publicAt = "public_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        tournamentID = try c.decode(Int.self, forKey: .tournamentID)
        tournamentName = try c.decodeIfPresent(String.self, forKey: .tournamentName) ?? ""
        tournamentImageURL = try c.decodeIfPresent(String.self, forKey: .tournamentImageURL)
        headerImageURL = try c.decodeIfPresent(String.self, forKey: .headerImageURL)
        inviteCode = try c.decodeIfPresent(String.self, forKey: .inviteCode) ?? ""
        inviteURL = try c.decodeIfPresent(String.self, forKey: .inviteURL) ?? ""
        welcomeMessage = try c.decodeIfPresent(String.self, forKey: .welcomeMessage)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        correctTeamPoints = try c.decodeIfPresent(Int.self, forKey: .correctTeamPoints) ?? 1
        exactResultPoints = try c.decodeIfPresent(Int.self, forKey: .exactResultPoints) ?? 3
        allowSneakPeek = try c.decodeIfPresent(Bool.self, forKey: .allowSneakPeek) ?? false
        groupPlayDeadline = try c.decodeIfPresent(Date.self, forKey: .groupPlayDeadline)
        mode = try c.decodeIfPresent(Int.self, forKey: .mode) ?? 0
        publicAt = try c.decodeIfPresent(Date.self, forKey: .publicAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        members = try c.decodeIfPresent([Member].self, forKey: .members) ?? []
    }
}

/// Row of `GET /user/:id/groups` — `placement` is 1-based standard competition ranking.
nonisolated struct GroupPlacement: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let tournamentID: Int
    let tournamentName: String
    let tournamentImageURL: String?
    let headerImageURL: String?
    let betMode: Int
    let publicAt: Date?
    let createdAt: Date
    let score: Int
    let normalizedScore: Double
    let placement: Int
    let memberCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, score, placement
        case tournamentID = "tournament_id"
        case tournamentName = "tournament_name"
        case tournamentImageURL = "tournament_image_url"
        case headerImageURL = "header_image_url"
        case betMode = "bet_mode"
        case publicAt = "public_at"
        case createdAt = "created_at"
        case normalizedScore = "normalized_score"
        case memberCount = "member_count"
    }
}

/// `{ "user": User, "groups": [GroupPlacement] }` — `GET /user/:id/groups`.
nonisolated struct UserGroupsResponse: Decodable, Sendable {
    let user: UserProfile
    let groups: [GroupPlacement]

    enum CodingKeys: String, CodingKey { case user, groups }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decode(UserProfile.self, forKey: .user)
        groups = try c.decodeIfPresent([GroupPlacement].self, forKey: .groups) ?? []
    }
}

/// Item of `GET /groups/public` (`public_at` is non-null here).
nonisolated struct PublicGroupItem: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let description: String?
    let tournamentID: Int
    let tournamentName: String
    let tournamentImageURL: String?
    let headerImageURL: String?
    let correctTeamPoints: Int
    let exactResultPoints: Int
    let allowSneakPeek: Bool
    let betMode: Int
    let groupPlayDeadline: Date?
    let publicAt: Date
    let createdAt: Date
    var memberCount: Int   // var: mutated optimistically on join
    var isMember: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case tournamentID = "tournament_id"
        case tournamentName = "tournament_name"
        case tournamentImageURL = "tournament_image_url"
        case headerImageURL = "header_image_url"
        case correctTeamPoints = "correct_team_points"
        case exactResultPoints = "exact_result_points"
        case allowSneakPeek = "allow_sneak_peek"
        case betMode = "bet_mode"
        case groupPlayDeadline = "group_play_deadline"
        case publicAt = "public_at"
        case createdAt = "created_at"
        case memberCount = "member_count"
        case isMember = "is_member"
    }
}

/// `{ "items": [...], "next_cursor": "..." }` — empty `nextCursor` means no more pages.
nonisolated struct PublicGroupList: Decodable, Sendable {
    let items: [PublicGroupItem]
    let nextCursor: String

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([PublicGroupItem].self, forKey: .items) ?? []
        nextCursor = try c.decodeIfPresent(String.self, forKey: .nextCursor) ?? ""
    }
}

/// `GET /group/:code` — invite-link preview (`:code` is the invite code).
nonisolated struct GroupPeek: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let description: String?
    let tournamentID: Int
    let tournamentName: String
    let tournamentImageURL: String?
    let headerImageURL: String?
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case tournamentID = "tournament_id"
        case tournamentName = "tournament_name"
        case tournamentImageURL = "tournament_image_url"
        case headerImageURL = "header_image_url"
        case inviteCode = "invite_code"
    }
}

/// Body for `POST /group`. `correct_team_points`/`exact_result_points` must be NON-ZERO
/// (Gin binding rejects 0 with a 400).
nonisolated struct CreateGroupRequest: Encodable, Sendable {
    var name: String
    var tournamentID: Int
    var correctTeamPoints: Int
    var exactResultPoints: Int
    var allowSneakPeek: Bool = true
    var groupPlayDeadline: Date?
    var welcomeMessage: String?
    var description: String?
    var isPublic: Bool = false
    var mode: Int = 0

    enum CodingKeys: String, CodingKey {
        case name, mode, description
        case tournamentID = "tournament_id"
        case correctTeamPoints = "correct_team_points"
        case exactResultPoints = "exact_result_points"
        case allowSneakPeek = "allow_sneak_peek"
        case groupPlayDeadline = "group_play_deadline"
        case welcomeMessage = "welcome_message"
        case isPublic = "is_public"
    }
}

/// Body for `PUT /group/:id/settings`. All five fields are always sent (matching the web
/// settings sheet); explicit `null` clears `welcome_message`/`description`.
nonisolated struct GroupSettingsUpdate: Encodable, Sendable {
    var welcomeMessage: String?
    var description: String?
    var correctTeamPoints: Int
    var exactResultPoints: Int
    var allowSneakPeek: Bool

    enum CodingKeys: String, CodingKey {
        case description
        case welcomeMessage = "welcome_message"
        case correctTeamPoints = "correct_team_points"
        case exactResultPoints = "exact_result_points"
        case allowSneakPeek = "allow_sneak_peek"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let welcomeMessage { try c.encode(welcomeMessage, forKey: .welcomeMessage) }
        else { try c.encodeNil(forKey: .welcomeMessage) }
        if let description { try c.encode(description, forKey: .description) }
        else { try c.encodeNil(forKey: .description) }
        try c.encode(correctTeamPoints, forKey: .correctTeamPoints)
        try c.encode(exactResultPoints, forKey: .exactResultPoints)
        try c.encode(allowSneakPeek, forKey: .allowSneakPeek)
    }
}

/// `{ "group_id": 7 }` — POST /group, POST /join/:code, POST /group/:id/join.
nonisolated struct GroupIDResponse: Decodable, Sendable {
    let groupID: Int
    enum CodingKeys: String, CodingKey { case groupID = "group_id" }
}

/// `{ "code": "newCode" }` — PUT /group/:id/code.
nonisolated struct InviteCodeResponse: Decodable, Sendable {
    let code: String
}

/// `{ "nickname": "string|null" }` — PUT /group/:id/nickname.
nonisolated struct NicknameResponse: Decodable, Sendable {
    let nickname: String?
}

/// `{ "public_at": "time|null" }` — PUT /group/:id/visibility.
nonisolated struct VisibilityResponse: Decodable, Sendable {
    let publicAt: Date?
    enum CodingKeys: String, CodingKey { case publicAt = "public_at" }
}

/// `{ "header_image_url": "..." }` — PUT /group/:id/header-image.
nonisolated struct HeaderImageResponse: Decodable, Sendable {
    let headerImageURL: String?
    enum CodingKeys: String, CodingKey { case headerImageURL = "header_image_url" }
}
