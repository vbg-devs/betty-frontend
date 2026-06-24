import Foundation

/// Every Betty REST endpoint as a typed `Endpoint` factory. Bodies are pre-encoded by
/// `APIClient` (see the matching methods there) — factories taking `Data` expect an
/// already-encoded JSON body.
extension Endpoint {
    // MARK: Misc

    static let ping = Endpoint.get("/ping")
    /// Stubbed server-side — always returns `[]`. Wired for future feed backfill.
    static let activityStream = Endpoint.get("/activitystream")

    // MARK: Users

    static func createUser(_ body: Data) -> Endpoint { .post("/user", body: body) }
    static let me = Endpoint.get("/user/me")
    static func updateMe(_ body: Data) -> Endpoint { .put("/user/me", body: body) }
    static let deleteMe = Endpoint.delete("/user/me")
    static func addPushToken(_ body: Data) -> Endpoint { .post("/user/me/add_push_token", body: body) }
    static func profileImageUploadURL(_ body: Data) -> Endpoint { .post("/user/me/profile-image/upload-url", body: body) }
    static func setProfileImage(_ body: Data) -> Endpoint { .put("/user/me/profile-image", body: body) }
    static let deleteProfileImage = Endpoint.delete("/user/me/profile-image")
    static func userGroups(userID: String) -> Endpoint { .get("/user/\(userID)/groups") }

    // MARK: Groups

    static func createGroup(_ body: Data) -> Endpoint { .post("/group", body: body) }
    static func join(code: String) -> Endpoint { .post("/join/\(code)", body: Data("{}".utf8)) }
    static func groupByID(_ id: Int) -> Endpoint { .get("/groupbyid/\(id)") }
    static let groups = Endpoint.get("/groups")
    static func peekGroup(code: String) -> Endpoint { .get("/group/\(code)") }
    static func rotateInviteCode(groupID: Int) -> Endpoint { .put("/group/\(groupID)/code") }
    static func setNickname(groupID: Int, _ body: Data) -> Endpoint { .put("/group/\(groupID)/nickname", body: body) }
    static func setVisibility(groupID: Int, _ body: Data) -> Endpoint { .put("/group/\(groupID)/visibility", body: body) }
    static func updateSettings(groupID: Int, _ body: Data) -> Endpoint { .put("/group/\(groupID)/settings", body: body) }
    static func joinPublicGroup(id: Int) -> Endpoint { .post("/group/\(id)/join", body: Data("{}".utf8)) }
    static func publicGroups(cursor: String?, q: String?, tournamentID: Int?, limit: Int?) -> Endpoint {
        var query: [URLQueryItem] = []
        // Pinned rules: omit cursor/q when empty or absent; include tournament_id/limit
        // whenever set, including 0.
        if let cursor, !cursor.isEmpty { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let q, !q.isEmpty { query.append(URLQueryItem(name: "q", value: q)) }
        if let tournamentID { query.append(URLQueryItem(name: "tournament_id", value: String(tournamentID))) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        return .get("/groups/public", query: query)
    }
    static func disableSneakPeek(groupID: Int) -> Endpoint { .post("/groupbyid/\(groupID)/disable-peak") }
    static func leaveGroup(id: Int) -> Endpoint { .delete("/group/\(id)/leave") }
    static func blockMember(groupID: Int, userID: String) -> Endpoint { .delete("/group/\(groupID)/block/\(userID)") }
    static func headerImageUploadURL(groupID: Int, _ body: Data) -> Endpoint { .post("/group/\(groupID)/header-image/upload-url", body: body) }
    static func setHeaderImage(groupID: Int, _ body: Data) -> Endpoint { .put("/group/\(groupID)/header-image", body: body) }
    static func deleteHeaderImage(groupID: Int) -> Endpoint { .delete("/group/\(groupID)/header-image") }

    // MARK: Bets

    static func betsByGroup(_ groupID: Int) -> Endpoint { .get("/bets/bygroup/\(groupID)") }
    static func betsByGame(gameID: Int, groupID: Int) -> Endpoint { .get("/bets/bygame/\(gameID)/\(groupID)") }
    static func placeBet(_ body: Data) -> Endpoint { .post("/bet", body: body) }
    static func updateBet(id: Int, _ body: Data) -> Endpoint { .put("/bet/\(id)", body: body) }

    // MARK: Tournaments & games

    static let tournaments = Endpoint.get("/tournaments")
    static func tournament(id: Int) -> Endpoint { .get("/tournament/\(id)") }
    static func tournamentLeaderboard(id: Int, limit: Int) -> Endpoint {
        .get("/tournament/\(id)/leaderboard", query: [URLQueryItem(name: "limit", value: String(limit))])
    }
    static func game(id: Int) -> Endpoint { .get("/game/\(id)") }
    static func setGameScore(id: Int, _ body: Data) -> Endpoint { .put("/game/\(id)", body: body) }
    static func evaluateGame(_ body: Data) -> Endpoint { .post("/evaluategame", body: body) }
    static func rollbackGame(gameID: Int) -> Endpoint { .put("/rollbackgame/\(gameID)") }

    // MARK: FIFA admin (result proposals)

    static func fifaProposals(status: String) -> Endpoint {
        .get("/admin/fifa/proposals", query: [URLQueryItem(name: "status", value: status)])
    }
    static func confirmFIFAProposal(id: Int) -> Endpoint { .post("/admin/fifa/proposals/\(id)/confirm") }
    static func dismissFIFAProposal(id: Int) -> Endpoint { .post("/admin/fifa/proposals/\(id)/dismiss") }
    static let fifaProposalsCount = Endpoint.get(
        "/admin/fifa/proposals/count",
        query: [URLQueryItem(name: "status", value: "pending")]
    )

    // MARK: Reference data

    static let teams = Endpoint.get("/teams")
    static let categories = Endpoint.get("/categories")
    static let arenas = Endpoint.get("/arenas")
    static func arenas(country: String) -> Endpoint { .get("/arenas/\(country)") }
    static let countries = Endpoint.get("/countries")

    // MARK: Message board

    static func messages(groupID: Int, amount: Int, page: Int) -> Endpoint {
        // NOTE: `offset` is a PAGE INDEX (SQL OFFSET offset*amount), not a row offset.
        .get("/messageboard/\(groupID)", query: [
            URLQueryItem(name: "amount", value: String(amount)),
            URLQueryItem(name: "offset", value: String(page)),
        ])
    }
    static func postMessage(_ body: Data) -> Endpoint { .post("/messageboard", body: body) }
    static func deleteMessage(id: Int) -> Endpoint { .delete("/messageboard/\(id)") }
    static func setReaction(messageID: Int, _ body: Data) -> Endpoint { .put("/messageboard/\(messageID)/reaction", body: body) }
    static func removeReaction(messageID: Int) -> Endpoint { .delete("/messageboard/\(messageID)/reaction") }

    // MARK: Announcements & feature requests

    static let announcements = Endpoint.get("/announcements")
    static func createAnnouncement(_ body: Data) -> Endpoint { .post("/announcement", body: body) }
    static func createFeatureRequest(_ body: Data) -> Endpoint { .post("/feature-requests", body: body) }
}
