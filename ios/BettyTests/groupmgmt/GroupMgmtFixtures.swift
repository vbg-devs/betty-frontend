import Foundation
@testable import Betty

/// Always-fresh-token mock for `APIClient` in group-management tests.
final class GroupMgmtMockTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token-2" }
}

/// Wire-shaped fixtures decoded through `JSONCoding` (response models are
/// Decodable-only — never fabricated via memberwise inits).
enum GroupMgmtFixtures {
    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONCoding.makeDecoder().decode(T.self, from: Data(json.utf8))
    }

    static func publicGroupItemJSON(
        id: Int,
        name: String = "Sunday Roast XI",
        description: String? = nil,
        tournamentID: Int = 5,
        tournamentName: String = "Euro 2028",
        tournamentImageURL: String? = nil,
        headerImageURL: String? = nil,
        correctTeamPoints: Int = 1,
        exactResultPoints: Int = 3,
        memberCount: Int = 2,
        isMember: Bool = false
    ) -> String {
        """
        {
          "id": \(id),
          "name": "\(name)",
          "description": \(description.map { "\"\($0)\"" } ?? "null"),
          "tournament_id": \(tournamentID),
          "tournament_name": "\(tournamentName)",
          "tournament_image_url": \(tournamentImageURL.map { "\"\($0)\"" } ?? "null"),
          "header_image_url": \(headerImageURL.map { "\"\($0)\"" } ?? "null"),
          "correct_team_points": \(correctTeamPoints),
          "exact_result_points": \(exactResultPoints),
          "allow_sneak_peek": true,
          "bet_mode": 0,
          "group_play_deadline": null,
          "public_at": "2026-01-01T00:00:00Z",
          "created_at": "2026-01-01T00:00:00Z",
          "member_count": \(memberCount),
          "is_member": \(isMember)
        }
        """
    }

    static func publicGroupItem(
        id: Int,
        name: String = "Sunday Roast XI",
        description: String? = nil,
        tournamentID: Int = 5,
        tournamentName: String = "Euro 2028",
        tournamentImageURL: String? = nil,
        headerImageURL: String? = nil,
        memberCount: Int = 2,
        isMember: Bool = false
    ) throws -> PublicGroupItem {
        try decode(PublicGroupItem.self, from: publicGroupItemJSON(
            id: id,
            name: name,
            description: description,
            tournamentID: tournamentID,
            tournamentName: tournamentName,
            tournamentImageURL: tournamentImageURL,
            headerImageURL: headerImageURL,
            memberCount: memberCount,
            isMember: isMember
        ))
    }

    static func tournament(
        id: Int,
        name: String = "Euro 2028",
        startDate: String = "2026-06-10T18:00:00Z",
        endDate: String? = nil
    ) throws -> Tournament {
        try decode(Tournament.self, from: """
        {
          "id": \(id),
          "name": "\(name)",
          "image_url": null,
          "start_date": "\(startDate)",
          "end_date": \(endDate.map { "\"\($0)\"" } ?? "null"),
          "category_id": 1
        }
        """)
    }

    static func group(
        id: Int = 7,
        name: String = "Sunday Roast XI",
        welcomeMessage: String? = nil,
        description: String? = nil,
        correctTeamPoints: Int = 2,
        exactResultPoints: Int = 4,
        allowSneakPeek: Bool = true,
        boostCount: Int = 0,
        boostMultiplier: Int = 2
    ) throws -> Group {
        try decode(Group.self, from: """
        {
          "id": \(id),
          "name": "\(name)",
          "tournament_id": 5,
          "tournament_name": "Euro 2028",
          "invite_code": "abc-123",
          "invite_url": "https://betty.social/dashboard/groups/join/abc-123",
          "welcome_message": \(welcomeMessage.map { "\"\($0)\"" } ?? "null"),
          "description": \(description.map { "\"\($0)\"" } ?? "null"),
          "correct_team_points": \(correctTeamPoints),
          "exact_result_points": \(exactResultPoints),
          "allow_sneak_peek": \(allowSneakPeek),
          "mode": 0,
          "boost_count": \(boostCount),
          "boost_multiplier": \(boostMultiplier),
          "public_at": null,
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z",
          "members": []
        }
        """)
    }
}
