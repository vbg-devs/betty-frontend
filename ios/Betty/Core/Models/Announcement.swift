import Foundation

/// `category` is one of: info | warning | excitement | important | reminder.
/// `cta` is omitted when null (`omitempty`).
nonisolated struct Announcement: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let userID: String
    let title: String
    let body: String
    let category: String
    let cta: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, body, category, cta
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

/// Body for `POST /announcement` (admin only — 403 for non-admins).
nonisolated struct CreateAnnouncementRequest: Encodable, Sendable {
    var title: String
    var body: String
    var category: String
    var cta: String?
}
