import Foundation

/// Message-board message. `reactions` is `[]` (never null) on GET, but **null** in the
/// `POST /messageboard` 201 response — normalized to `[]` here.
nonisolated struct GroupMessage: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let groupID: Int
    let userID: String
    let imageURL: String?
    let body: String?
    let createdAt: Date
    var reactions: [MessageReaction]

    enum CodingKeys: String, CodingKey {
        case id, body, reactions
        case groupID = "group_id"
        case userID = "user_id"
        case imageURL = "image_url"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        groupID = try c.decodeIfPresent(Int.self, forKey: .groupID) ?? 0
        userID = try c.decode(String.self, forKey: .userID)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        reactions = try c.decodeIfPresent([MessageReaction].self, forKey: .reactions) ?? []
    }
}

/// One reaction per user per message (server-enforced upsert). `user_id` is a UID string.
nonisolated struct MessageReaction: Decodable, Hashable, Sendable {
    let userID: String
    let emojiID: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case emojiID = "emoji_id"
        case createdAt = "created_at"
    }

    /// Memberwise init for optimistic local reactions.
    init(userID: String, emojiID: String, createdAt: Date) {
        self.userID = userID
        self.emojiID = emojiID
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(String.self, forKey: .userID)
        emojiID = try c.decode(String.self, forKey: .emojiID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
    }
}

/// Body for `POST /messageboard` — at least one of `body`/`image_url` must be non-nil
/// (nil fields are omitted, matching the web client).
nonisolated struct PostMessageRequest: Encodable, Sendable {
    var groupID: Int
    var body: String?
    var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case body
        case groupID = "group_id"
        case imageURL = "image_url"
    }
}

/// Body for `PUT /messageboard/:id/reaction` (`emoji_id` <= 64 chars).
nonisolated struct SetReactionRequest: Encodable, Sendable {
    var emojiID: String
    enum CodingKeys: String, CodingKey { case emojiID = "emoji_id" }
}
