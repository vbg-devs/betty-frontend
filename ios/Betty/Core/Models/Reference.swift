import Foundation

/// `image_url` is a scheme string `"<type>:<key>"` (`flag:se`, `pl:arsenal`) resolved to
/// static web assets, not an absolute URL — see `TeamLogoView`.
nonisolated struct Team: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let tournamentID: Int
    let imageURL: String?
    let name: String
    let isPlaceholder: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case tournamentID = "tournament_id"
        case imageURL = "image_url"
        case isPlaceholder = "is_placeholder"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        tournamentID = try c.decodeIfPresent(Int.self, forKey: .tournamentID) ?? 0
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        isPlaceholder = try c.decodeIfPresent(Bool.self, forKey: .isPlaceholder) ?? false
    }
}

nonisolated struct Category: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct Arena: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let country: String
    let city: String
    let capacity: Int
    let imageURL: String

    enum CodingKeys: String, CodingKey {
        case id, name, country, city, capacity
        case imageURL = "image_url"
    }
}
