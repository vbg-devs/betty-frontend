import Foundation

/// `users.User` — user IDs are Firebase UID STRINGS on the wire.
///
/// The wire also carries `"PushTokens": null` (capital P, no json tag) — intentionally
/// not modeled.
nonisolated struct UserProfile: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let email: String
    let name: String
    var imageURL: String?
    let firebaseImageURL: String?
    let country: String?
    let createdAt: Date
    let updatedAt: Date
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id, email, name, country
        case imageURL = "image_url"
        case firebaseImageURL = "firebase_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isAdmin = "is_admin"
    }
}

nonisolated struct Country: Codable, Hashable, Sendable, Identifiable {
    let code: String
    let name: String
    let flagEmoji: String?

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code, name
        case flagEmoji = "flag_emoji"
    }

    init(code: String, name: String, flagEmoji: String?) {
        self.code = code
        self.name = name
        self.flagEmoji = flagEmoji
    }
}

/// Body for `POST /user` (create profile). Always send both `email` and `name` —
/// the handler 500s when both the field and the token claim are missing.
nonisolated struct CreateUserRequest: Encodable, Sendable {
    var email: String
    var name: String
    var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case email, name
        case imageURL = "image_url"
    }
}

/// Body for `PUT /user/me`. The backend applies ONLY `name` and `country`
/// (email/image_url are silently dropped). An omitted name clears the stored
/// name — always send the full current name.
nonisolated struct UpdateUserRequest: Encodable, Sendable {
    var name: String
    var country: String?

    enum CodingKeys: String, CodingKey { case name, country }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let country {
            try container.encode(country, forKey: .country)
        } else {
            try container.encodeNil(forKey: .country) // explicit null clears
        }
    }
}

/// `{ "image_url": "string|null" }` — profile-image commit / delete responses.
nonisolated struct ImageURLResponse: Decodable, Sendable {
    let imageURL: String?
    enum CodingKeys: String, CodingKey { case imageURL = "image_url" }
}
