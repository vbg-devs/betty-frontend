import Foundation
import Observation

/// The signed-in user's groups (each including full `members[]`).
///
/// Matching the web store: every successful mutation re-fetches the whole list via
/// `GET /groups` — no optimistic group state. `listPublic`/`peek` results are NOT stored
/// (page-local pagination).
@Observable
final class GroupStore {
    private let api: APIClient

    private(set) var groups: [Group] = []
    private(set) var isLoaded = false

    init(api: APIClient) {
        self.api = api
    }

    func byID(_ id: Int) -> Group? {
        groups.first { $0.id == id }
    }

    func clear() {
        groups = []
        isLoaded = false
    }

    /// `GET /groups` (null body → []).
    func load() async throws {
        groups = try await api.groups()
        isLoaded = true
    }

    /// `POST /group` → group id (reloads the list before returning, so `byID(result)`
    /// resolves the new group incl. its `invite_code`).
    @discardableResult
    func create(_ payload: CreateGroupRequest) async throws -> Int {
        let groupID = try await api.createGroup(payload)
        try await load()
        return groupID
    }

    /// `POST /join/:code` → group id, then reload. Caller maps 404 invalid code /
    /// 409 already member / 403 blocked.
    @discardableResult
    func join(code: String) async throws -> Int {
        let groupID = try await api.join(code: code)
        try await load()
        return groupID
    }

    /// `POST /group/:id/join` (public groups) → group id, then reload.
    /// Caller maps 409 already member / 403 blocked / 404 no longer public.
    @discardableResult
    func joinPublic(id: Int) async throws -> Int {
        let groupID = try await api.joinPublicGroup(id: id)
        try await load()
        return groupID
    }

    /// `DELETE /group/:id/leave`, then reload.
    func leave(id: Int) async throws {
        try await api.leaveGroup(id: id)
        try await load()
    }

    /// `PUT /group/:id/visibility` → `public_at`, then reload. 401 → "only the group
    /// author can change visibility".
    @discardableResult
    func setVisibility(id: Int, isPublic: Bool) async throws -> Date? {
        let publicAt = try await api.setVisibility(groupID: id, isPublic: isPublic)
        try await load()
        return publicAt
    }

    /// `PUT /group/:id/settings` (author only — 401/403 → "Only the group author can
    /// edit these settings."), then reload.
    @discardableResult
    func updateSettings(id: Int, _ update: GroupSettingsUpdate) async throws -> Group {
        let updated = try await api.updateGroupSettings(groupID: id, update)
        try await load()
        return updated
    }

    /// `PUT /group/:id/nickname` — nil/empty clears; max 120 chars. Then reload.
    @discardableResult
    func setNickname(id: Int, _ nickname: String?) async throws -> String? {
        let result = try await api.setNickname(groupID: id, nickname: nickname)
        try await load()
        return result
    }

    /// `PUT /group/:id/code` (author only) — rotates the invite code, then reload.
    @discardableResult
    func rotateInviteCode(id: Int) async throws -> String {
        let code = try await api.rotateInviteCode(groupID: id)
        try await load()
        return code
    }

    /// `POST /groupbyid/:id/disable-peak` (author only), then reload.
    func disableSneakPeek(id: Int) async throws {
        try await api.disableSneakPeek(groupID: id)
        try await load()
    }

    /// `DELETE /group/:id/block/:userid` (author only), then reload.
    func blockMember(groupID: Int, userID: String) async throws {
        try await api.blockMember(groupID: groupID, userID: userID)
        try await load()
    }

    /// Header-image presigned flow (author only): presign → raw PUT → commit → reload.
    /// Errors: 401 not author, 413 > 1 MiB, 415 bad type, 503 uploads unavailable.
    @discardableResult
    func uploadHeaderImage(groupID: Int, data: Data, contentType: String) async throws -> String? {
        let presigned = try await api.headerImageUploadURL(groupID: groupID, contentType: contentType, contentLength: data.count)
        try await api.upload(data, with: presigned, contentType: contentType)
        let committed = try await api.setHeaderImage(groupID: groupID, headerImageURL: presigned.publicURL)
        try await load()
        return committed
    }

    /// `DELETE /group/:id/header-image` (author only), then reload.
    func deleteHeaderImage(groupID: Int) async throws {
        try await api.deleteHeaderImage(groupID: groupID)
        try await load()
    }

    /// `GET /group/:code` — invite preview; NOT stored.
    func peek(code: String) async throws -> GroupPeek {
        try await api.peekGroup(code: code)
    }

    /// `GET /groups/public` — cursor pagination; NOT stored (page-local).
    func listPublic(cursor: String? = nil, query: String? = nil,
                    tournamentID: Int? = nil, limit: Int? = nil) async throws -> PublicGroupList {
        try await api.publicGroups(cursor: cursor, query: query, tournamentID: tournamentID, limit: limit)
    }
}
