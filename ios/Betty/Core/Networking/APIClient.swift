import Foundation

/// Token source for `APIClient` — implemented by `AuthService`.
protocol TokenProviding: AnyObject {
    var isSignedIn: Bool { get }
    /// A currently-valid ID token (refreshes proactively when < 5 min remain).
    func validIDToken() async throws -> String
    /// Force-refreshed token after the API answered 401 with the previous one.
    func tokenAfterAuthFailure() async throws -> String
}

/// Typed async client for `https://api.betty.social/api/v1`.
///
/// Every call: throws `APIError.notAuthenticated` before any I/O when signed out and
/// sets `Authorization: Bearer <fresh id token>` (always overwritten). A 401 is retried
/// once with a force-refreshed token ONLY when it is the auth middleware rejecting the
/// token itself (`{"error": ...}` body — the request never reached a handler); handler
/// 401s are authorization failures (empty body) and surface immediately, so mutating
/// requests are never blindly re-executed.
final class APIClient {
    static let defaultBaseURL = URL(string: "https://api.betty.social/api/v1")!

    private let baseURL: URL
    private let transport: any HTTPTransport
    private let tokens: any TokenProviding
    private let decoder = JSONCoding.makeDecoder()
    private let encoder = JSONCoding.makeEncoder()

    init(transport: any HTTPTransport = URLSessionTransport(),
         tokens: any TokenProviding,
         baseURL: URL = APIClient.defaultBaseURL) {
        self.transport = transport
        self.tokens = tokens
        self.baseURL = baseURL
    }

    // MARK: - Misc

    /// Auth smoke test — echoes the decoded Firebase token claims.
    @discardableResult
    func ping() async throws -> Data {
        try await perform(.ping).0
    }

    /// Server-side stub: always `[]` today. Wired for future Activity-tab backfill.
    func activityStream() async throws -> [JSONValue] {
        try await requestList(.activityStream)
    }

    // MARK: - Users

    /// `POST /user` — 201 echo has zero timestamps; re-GET /user/me for real values.
    /// Gate behind a `getMe()` 404 — duplicate creation 500s.
    func createUser(email: String, name: String, imageURL: String?) async throws -> UserProfile {
        try await request(.createUser(encode(CreateUserRequest(email: email, name: name, imageURL: imageURL))))
    }

    /// `GET /user/me` — throws `.notFound` when authenticated but no profile row exists
    /// yet (trigger onboarding).
    func getMe() async throws -> UserProfile {
        try await request(.me)
    }

    /// `PUT /user/me` — ONLY `name` and `country` are applied (email/image_url dropped).
    func updateMe(name: String, country: String?) async throws -> UserProfile {
        try await request(.updateMe(encode(UpdateUserRequest(name: name, country: country))))
    }

    /// `DELETE /user/me` — anonymizes the row, deletes push tokens AND the Firebase
    /// account. Call `AuthService.signOut()` afterwards.
    func deleteMe() async throws {
        try await requestVoid(.deleteMe)
    }

    /// `POST /user/me/add_push_token` — server-side delivery uses FCM; a raw APNs token
    /// is accepted but never receives a push. Dormant until an FCM bridge exists.
    func addPushToken(_ token: String) async throws {
        struct Body: Encodable { let token: String }
        try await requestVoid(.addPushToken(encode(Body(token: token))))
    }

    func profileImageUploadURL(contentType: String, contentLength: Int) async throws -> PresignedUpload {
        try await request(.profileImageUploadURL(encode(UploadURLRequest(contentType: contentType, contentLength: contentLength))))
    }

    /// `PUT /user/me/profile-image` — URL must be the presign `public_url`.
    func setProfileImage(imageURL: String) async throws -> String? {
        struct Body: Encodable {
            let imageURL: String
            enum CodingKeys: String, CodingKey { case imageURL = "image_url" }
        }
        let response: ImageURLResponse = try await request(.setProfileImage(encode(Body(imageURL: imageURL))))
        return response.imageURL
    }

    /// `DELETE /user/me/profile-image` — reverts to the Firebase snapshot.
    func deleteProfileImage() async throws -> String? {
        let response: ImageURLResponse = try await request(.deleteProfileImage)
        return response.imageURL
    }

    /// `GET /user/:id/groups` — rich profile + placements payload (unused by web; ideal
    /// one-shot home payload). Works for any user id.
    func userGroups(userID: String) async throws -> UserGroupsResponse {
        try await request(.userGroups(userID: userID))
    }

    // MARK: - Groups

    /// `POST /group` — 201 `{group_id}`.
    func createGroup(_ payload: CreateGroupRequest) async throws -> Int {
        let response: GroupIDResponse = try await request(.createGroup(encode(payload)))
        return response.groupID
    }

    /// `POST /join/:code` — 200 `{group_id}`; 404 unknown code, 409 already a member,
    /// 403 blocked.
    func join(code: String) async throws -> Int {
        let response: GroupIDResponse = try await request(.join(code: code))
        return response.groupID
    }

    /// `GET /groupbyid/:id`. Wire quirk: the backend answers 500 (not 404) for an unknown
    /// group or a non-member — mapped to `.notFound` here.
    func group(id: Int) async throws -> Group {
        do {
            return try await request(.groupByID(id))
        } catch let error as APIError {
            if case .server = error { throw APIError.notFound }
            throw error
        }
    }

    /// `GET /groups` — the caller's groups, each including `members[]`.
    func groups() async throws -> [Group] {
        try await requestList(.groups)
    }

    /// `GET /group/:code` — invite-code peek.
    func peekGroup(code: String) async throws -> GroupPeek {
        try await request(.peekGroup(code: code))
    }

    /// `PUT /group/:id/code` (author only; 401 otherwise).
    func rotateInviteCode(groupID: Int) async throws -> String {
        let response: InviteCodeResponse = try await request(.rotateInviteCode(groupID: groupID))
        return response.code
    }

    /// `PUT /group/:id/nickname` — nil/empty/whitespace clears; max 120 chars (400).
    func setNickname(groupID: Int, nickname: String?) async throws -> String? {
        struct Body: Encodable {
            let nickname: String?
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                if let nickname { try c.encode(nickname, forKey: .nickname) }
                else { try c.encodeNil(forKey: .nickname) }
            }
            enum CodingKeys: String, CodingKey { case nickname }
        }
        let response: NicknameResponse = try await request(.setNickname(groupID: groupID, encode(Body(nickname: nickname))))
        return response.nickname
    }

    /// `PUT /group/:id/visibility` (author only; 401 otherwise) — returns `public_at`.
    func setVisibility(groupID: Int, isPublic: Bool) async throws -> Date? {
        struct Body: Encodable {
            let isPublic: Bool
            enum CodingKeys: String, CodingKey { case isPublic = "is_public" }
        }
        let response: VisibilityResponse = try await request(.setVisibility(groupID: groupID, encode(Body(isPublic: isPublic))))
        return response.publicAt
    }

    /// `PUT /group/:id/settings` (author only; 401 otherwise) — returns the full Group.
    func updateGroupSettings(groupID: Int, _ update: GroupSettingsUpdate) async throws -> Group {
        try await request(.updateSettings(groupID: groupID, encode(update)))
    }

    /// `POST /group/:id/join` — public groups by numeric id; 404 missing OR private,
    /// 409 already member, 403 blocked.
    func joinPublicGroup(id: Int) async throws -> Int {
        let response: GroupIDResponse = try await request(.joinPublicGroup(id: id))
        return response.groupID
    }

    /// `GET /groups/public` — cursor pagination; empty `nextCursor` = no more pages.
    func publicGroups(cursor: String? = nil, query: String? = nil,
                      tournamentID: Int? = nil, limit: Int? = nil) async throws -> PublicGroupList {
        try await request(.publicGroups(cursor: cursor, q: query, tournamentID: tournamentID, limit: limit))
    }

    /// `POST /groupbyid/:id/disable-peak` (author only; 401 otherwise).
    func disableSneakPeek(groupID: Int) async throws {
        try await requestVoid(.disableSneakPeek(groupID: groupID))
    }

    /// `DELETE /group/:id/leave` — soft leave; rejoining reactivates.
    func leaveGroup(id: Int) async throws {
        try await requestVoid(.leaveGroup(id: id))
    }

    /// `DELETE /group/:id/block/:userid` (author only). Wire quirk: a non-author gets
    /// 500, not 401.
    func blockMember(groupID: Int, userID: String) async throws {
        try await requestVoid(.blockMember(groupID: groupID, userID: userID))
    }

    func headerImageUploadURL(groupID: Int, contentType: String, contentLength: Int) async throws -> PresignedUpload {
        try await request(.headerImageUploadURL(groupID: groupID, encode(UploadURLRequest(contentType: contentType, contentLength: contentLength))))
    }

    /// `PUT /group/:id/header-image` — URL must be the presign `public_url` (400 otherwise).
    func setHeaderImage(groupID: Int, headerImageURL: String) async throws -> String? {
        struct Body: Encodable {
            let headerImageURL: String
            enum CodingKeys: String, CodingKey { case headerImageURL = "header_image_url" }
        }
        let response: HeaderImageResponse = try await request(.setHeaderImage(groupID: groupID, encode(Body(headerImageURL: headerImageURL))))
        return response.headerImageURL
    }

    func deleteHeaderImage(groupID: Int) async throws {
        try await requestVoid(.deleteHeaderImage(groupID: groupID))
    }

    // MARK: - Bets

    /// `GET /bets/bygroup/:group` — ALL members' bets for ALL games in the group.
    func bets(groupID: Int) async throws -> [Bet] {
        try await requestList(.betsByGroup(groupID))
    }

    /// `GET /bets/bygame/:game/:group` — the CALLER's own bets only. Wire quirk: rows
    /// can repeat once per membership (join fan-out) — deduped by `id` here.
    func bets(gameID: Int, groupID: Int) async throws -> [Bet] {
        let raw: [Bet] = try await requestList(.betsByGame(gameID: gameID, groupID: groupID))
        var seen = Set<Int>()
        return raw.filter { seen.insert($0.id).inserted }
    }

    /// `POST /bet` — returns **200** (not 201) with a request echo (`id: 0`, zero
    /// timestamps); throws `.locked` (423) when the game already started, and
    /// `.unauthorized` when not an active member of `group_id` (non-universal only).
    func placeBet(_ payload: PlaceBetRequest) async throws -> Bet {
        try await request(.placeBet(encode(payload)))
    }

    /// `PUT /bet/:id` — single-bet score edit; 404 unknown id, 423 game started,
    /// 401 someone else's bet, 500 if already processed.
    func updateBet(id: Int, homeTeamScore: Int, awayTeamScore: Int) async throws -> Bet {
        let body = UpdateBetRequest(id: id, homeTeamScore: homeTeamScore, awayTeamScore: awayTeamScore)
        return try await request(.updateBet(id: id, encode(body)))
    }

    // MARK: - Tournaments & games

    /// `GET /tournaments` — summaries; `pools`/`games` are null here. 404 (empty table)
    /// is normalized to `[]`.
    func tournaments() async throws -> [Tournament] {
        try await emptyOn404 { try await self.requestList(.tournaments) }
    }

    /// `GET /tournament/:id` — flat `pools[]` + `games[]`. 404 when the tournament is
    /// unknown OR already ended.
    func tournament(id: Int) async throws -> Tournament {
        try await request(.tournament(id: id))
    }

    /// `GET /tournament/:id/leaderboard` — only `user_id`, `name`, `image_url`,
    /// `normalized_score` are meaningful; `limit` values <= 10 are raised to 10.
    func tournamentLeaderboard(id: Int, limit: Int = 100) async throws -> [Member] {
        try await requestList(.tournamentLeaderboard(id: id, limit: limit))
    }

    func game(id: Int) async throws -> Game {
        try await request(.game(id: id))
    }

    /// `PUT /game/:id` — rejects 0 scores (400); NO admin check server-side. Admin UI only.
    func setGameScore(id: Int, homeTeamScore: Int, awayTeamScore: Int) async throws {
        try await requestVoid(.setGameScore(id: id, encode(SetGameScoreRequest(homeTeamScore: homeTeamScore, awayTeamScore: awayTeamScore))))
    }

    /// `POST /evaluategame` (admin) — 410 when already processed; scores >= 0 allowed.
    func evaluateGame(gameID: Int, homeTeamScore: Int, awayTeamScore: Int) async throws {
        try await requestVoid(.evaluateGame(encode(EvaluateGameRequest(gameID: gameID, homeTeamScore: homeTeamScore, awayTeamScore: awayTeamScore))))
    }

    /// `PUT /rollbackgame/:gameid` (admin, properly enforced — 401 otherwise).
    func rollbackGame(gameID: Int) async throws {
        try await requestVoid(.rollbackGame(gameID: gameID))
    }

    // MARK: - Reference data

    /// `GET /teams` — all tournaments; filter by `tournamentID` client-side. 404 -> [].
    func teams() async throws -> [Team] {
        try await emptyOn404 { try await self.requestList(.teams) }
    }

    func categories() async throws -> [Category] {
        try await emptyOn404 { try await self.requestList(.categories) }
    }

    func arenas() async throws -> [Arena] {
        try await requestList(.arenas)
    }

    func arenas(country: String) async throws -> [Arena] {
        try await requestList(.arenas(country: country))
    }

    func countries() async throws -> [Country] {
        try await requestList(.countries)
    }

    // MARK: - Message board

    /// `GET /messageboard/:groupid` — newest first; `page` is a PAGE INDEX, not a row
    /// offset. 403 when the caller is not a member.
    func messages(groupID: Int, amount: Int = 50, page: Int = 0) async throws -> [GroupMessage] {
        try await requestList(.messages(groupID: groupID, amount: amount, page: page))
    }

    /// `POST /messageboard` — 201; the created message arrives with `reactions: null`
    /// (normalized to `[]` by the model).
    func postMessage(groupID: Int, body: String?, imageURL: String?) async throws -> GroupMessage {
        try await request(.postMessage(encode(PostMessageRequest(groupID: groupID, body: body, imageURL: imageURL))))
    }

    /// `DELETE /messageboard/:id` — 204; 404 when missing/not the caller's/already gone.
    func deleteMessage(id: Int) async throws {
        try await requestVoid(.deleteMessage(id: id))
    }

    /// `PUT /messageboard/:id/reaction` — replaces any prior reaction by the caller. 204.
    func setReaction(messageID: Int, emojiID: String) async throws {
        try await requestVoid(.setReaction(messageID: messageID, encode(SetReactionRequest(emojiID: emojiID))))
    }

    /// `DELETE /messageboard/:id/reaction` — 204, idempotent.
    func removeReaction(messageID: Int) async throws {
        try await requestVoid(.removeReaction(messageID: messageID))
    }

    // MARK: - Announcements & feature requests

    func announcements() async throws -> [Announcement] {
        try await requestList(.announcements)
    }

    /// Admin only (403 for non-admins).
    func createAnnouncement(title: String, body: String, category: String, cta: String? = nil) async throws -> Announcement {
        try await request(.createAnnouncement(encode(CreateAnnouncementRequest(title: title, body: body, category: category, cta: cta))))
    }

    /// `POST /feature-requests` — description 1..5000 chars.
    func createFeatureRequest(description: String) async throws -> FeatureRequest {
        struct Body: Encodable { let description: String }
        return try await request(.createFeatureRequest(encode(Body(description: description))))
    }

    // MARK: - Presigned uploads (raw PUT to R2, outside the API base/bearer)

    /// PUT the raw bytes to `upload.uploadURL`, applying the presigned headers with the
    /// web's rules: skip empty values, skip `Content-Length`/`Host` (URLSession manages
    /// them), join multi-values with ", ", default `Content-Type` to the file's.
    func upload(_ data: Data, with upload: PresignedUpload, contentType: String) async throws {
        guard let url = URL(string: upload.uploadURL) else {
            throw APIError.badRequest(message: "Invalid presigned upload URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = upload.method.isEmpty ? "PUT" : upload.method
        var hasContentType = false
        for (key, values) in upload.headers {
            let joined = values.joined(separator: ", ")
            guard !joined.isEmpty else { continue }
            if key.caseInsensitiveCompare("Content-Length") == .orderedSame { continue }
            if key.caseInsensitiveCompare("Host") == .orderedSame { continue }
            if key.caseInsensitiveCompare("Content-Type") == .orderedSame { hasContentType = true }
            request.setValue(joined, forHTTPHeaderField: key)
        }
        if !hasContentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = data
        let (responseData, response): (Data, HTTPURLResponse)
        do {
            (responseData, response) = try await transport.send(request)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
        guard (200...299).contains(response.statusCode) else {
            throw APIError(status: response.statusCode, data: responseData)
        }
    }

    // MARK: - Core request machinery

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let (data, _) = try await perform(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Like `request`, but a literal `null`/empty body decodes to `nil`
    /// (`c.JSON(200, nil)` responses).
    func requestOptional<T: Decodable>(_ endpoint: Endpoint) async throws -> T? {
        let (data, _) = try await perform(endpoint)
        guard !Self.isNullBody(data) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Array responses where Go may serialize `null` instead of `[]`.
    func requestList<T: Decodable>(_ endpoint: Endpoint) async throws -> [T] {
        try await requestOptional(endpoint) ?? []
    }

    /// 200/201/204 with empty, `null`, or ignored bodies.
    func requestVoid(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    private func perform(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        guard tokens.isSignedIn else { throw APIError.notAuthenticated }
        let token = try await tokens.validIDToken()
        var (data, response) = try await execute(endpoint, token: token)
        if response.statusCode == 401, Self.isTokenRejection(data) {
            let fresh = try await tokens.tokenAfterAuthFailure()
            (data, response) = try await execute(endpoint, token: fresh)
        }
        guard (200...299).contains(response.statusCode) else {
            throw APIError(status: response.statusCode, data: data)
        }
        return (data, response)
    }

    /// The Go auth middleware aborts BEFORE any handler runs and always answers 401 with
    /// `{"error": "API token required"|"Invalid API token"}`. Handlers reuse 401 for
    /// authorization failures (not the author, someone else's bet, non-admin) via
    /// `c.Status(401)` — an empty body. Only middleware rejections are stale-token
    /// candidates: retrying a handler 401 can never succeed with a fresher token and
    /// would re-execute mutations.
    private nonisolated static func isTokenRejection(_ data: Data) -> Bool {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return object["error"] is String
    }

    private func execute(_ endpoint: Endpoint, token: String) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false) else {
            throw APIError.badRequest(message: "Invalid endpoint path: \(endpoint.path)")
        }
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
        }
        guard let url = components.url else {
            throw APIError.badRequest(message: "Invalid endpoint URL: \(endpoint.path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        do {
            return try await transport.send(request)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    private func encode(_ value: some Encodable) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw APIError.encoding(error)
        }
    }

    private func emptyOn404<T>(_ operation: () async throws -> [T]) async rethrows -> [T] {
        do {
            return try await operation()
        } catch APIError.notFound {
            return []
        }
    }

    private nonisolated static func isNullBody(_ data: Data) -> Bool {
        if data.isEmpty { return true }
        let trimmed = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "null" || trimmed.isEmpty
    }
}
