import Foundation

/// `POST /feature-requests` 201 response.
nonisolated struct FeatureRequest: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let userID: String
    let description: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, description
        case userID = "user_id"
        case createdAt = "created_at"
    }
}
