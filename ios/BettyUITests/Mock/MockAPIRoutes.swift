import Foundation

/// Every `/api/v1` route, with the production wire quirks preserved (api-contract.md):
/// POST /bet answers 200 with an id-0 echo (423 once started), /groupbyid 500s for
/// unknown/non-member, /join/:code does 404/409/403, PUT /user/me applies only
/// name+country, 204s have no body, several 200s are the literal `null`, ...
extension BettyMockBackend {
    private static let allowedImageTypes = ["image/jpeg", "image/png", "image/webp", "image/gif"]

    func registerAPIRoutes() {
        registerMiscAndUserRoutes()
        registerGroupRoutes()
        registerBetRoutes()
        registerTournamentRoutes()
        registerReferenceRoutes()
        registerMessageBoardRoutes()
        registerAnnouncementRoutes()
        registerFIFARoutes()
        registerUploadCatchAll()
    }

    // MARK: - Misc + users

    private func registerMiscAndUserRoutes() {
        api("GET", "/ping") { _, _, uid, _ in
            .json([
                "iss": "https://securetoken.google.com/betty-f676d",
                "aud": "betty-f676d",
                "exp": Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
                "iat": Int(Date().timeIntervalSince1970),
                "sub": uid,
                "uid": uid,
                "firebase": ["sign_in_provider": "password"],
            ])
        }

        // Stubbed server-side — ALWAYS an empty array.
        api("GET", "/activitystream") { _, _, _, _ in .json([Any]()) }

        api("POST", "/user") { request, _, uid, scenario in
            guard var user = scenario.user(uid) else { return .empty(500) }
            guard !user.hasProfile else { return .empty(500) } // duplicate create → 500
            let body = request.bodyJSON ?? [:]
            if let name = body["name"] as? String, !name.isEmpty { user.name = name }
            if let email = body["email"] as? String, !email.isEmpty { user.email = email }
            if user.name.isEmpty || user.email.isEmpty {
                return .empty(500) // handler panics when field AND claim are missing
            }
            if let imageURL = body["image_url"] as? String, !imageURL.isEmpty {
                user.imageURL = imageURL
                user.firebaseImageURL = imageURL
            }
            user.hasProfile = true
            scenario.updateUser(uid) { $0 = user }
            // 201 echo with ZERO timestamps — clients must re-GET /user/me.
            return .json(MockWire.user(user, zeroTimestamps: true), status: 201)
        }

        api("GET", "/user/me") { _, _, uid, scenario in
            guard let user = scenario.user(uid), user.hasProfile else { return .empty(404) }
            return .json(MockWire.user(user))
        }

        api("PUT", "/user/me") { request, _, uid, scenario in
            guard let user = scenario.user(uid), user.hasProfile else { return .empty(500) }
            let body = request.bodyJSON ?? [:]
            scenario.updateUser(uid) { user in
                // ONLY name and country are applied; an omitted name clears to "".
                user.name = body["name"] as? String ?? ""
                user.country = body["country"] as? String // NSNull/absent → nil clears
            }
            return .json(MockWire.user(scenario.user(uid)!))
        }

        api("DELETE", "/user/me") { _, _, uid, scenario in
            scenario.updateUser(uid) { user in
                user.name = "Deleted User"
                user.email = ""
                user.imageURL = nil
                user.hasProfile = false
            }
            return .null()
        }

        api("POST", "/user/me/add_push_token") { request, _, _, _ in
            let token = (request.bodyJSON?["token"] as? String) ?? ""
            return token.isEmpty ? .empty(400) : .empty(200)
        }

        api("POST", "/user/me/profile-image/upload-url") { [weak self] request, _, uid, _ in
            guard let self else { return .empty(500) }
            return self.presign(request, key: "users/\(uid)/profile/mock-\(Int.random(in: 1000...9999))")
        }

        api("PUT", "/user/me/profile-image") { [weak self] request, _, uid, scenario in
            guard let self else { return .empty(500) }
            guard let url = request.bodyJSON?["image_url"] as? String,
                  url.hasPrefix(self.publicAssetBase) else { return .empty(400) }
            scenario.updateUser(uid) { $0.imageURL = url }
            return .json(["image_url": url])
        }

        api("DELETE", "/user/me/profile-image") { _, _, uid, scenario in
            scenario.updateUser(uid) { $0.imageURL = $0.firebaseImageURL }
            return .json(["image_url": MockWire.orNull(scenario.user(uid)?.imageURL)])
        }

        api("GET", "/user/:id/groups") { _, params, _, scenario in
            guard let id = params["id"], let user = scenario.user(id), user.hasProfile else {
                return .empty(404)
            }
            let placements = scenario.groups.compactMap { group -> [String: Any]? in
                guard let member = group.member(id), member.status == .active else { return nil }
                return MockWire.placement(group, of: member, in: scenario)
            }
            return .json(["user": MockWire.user(user), "groups": placements])
        }
    }

    // MARK: - Groups

    private func registerGroupRoutes() {
        api("POST", "/group") { request, _, uid, scenario in
            let body = request.bodyJSON ?? [:]
            // Gin binding: name + tournament_id required, points required NON-ZERO.
            guard let name = body["name"] as? String, !name.isEmpty,
                  let tournamentID = body["tournament_id"] as? Int, tournamentID != 0,
                  let correct = body["correct_team_points"] as? Int, correct != 0,
                  let exact = body["exact_result_points"] as? Int, exact != 0
            else { return .empty(400) }
            if let description = body["description"] as? String, description.count > 1000 {
                return .empty(400)
            }
            // Spec §1.1: boost_count >= 0, boost_multiplier >= 1.
            let boostCount = body["boost_count"] as? Int ?? 0
            let boostMultiplier = body["boost_multiplier"] as? Int ?? 2
            guard boostCount >= 0, boostMultiplier >= 1 else {
                return .json(["error": "invalid booster config"], status: 400)
            }
            let id = scenario.nextGroupID
            scenario.nextGroupID += 1
            scenario.groups.append(MockGroup(
                id: id, name: name, tournamentID: tournamentID,
                inviteCode: "NEW\(id)",
                welcomeMessage: body["welcome_message"] as? String,
                description: body["description"] as? String,
                correctTeamPoints: correct, exactResultPoints: exact,
                allowSneakPeek: body["allow_sneak_peek"] as? Bool ?? false,
                groupPlayDeadline: MockWire.parseTime(body["group_play_deadline"]),
                mode: body["mode"] as? Int ?? 0,
                boostCount: boostCount, boostMultiplier: boostMultiplier,
                publicAt: (body["is_public"] as? Bool ?? false) ? Date() : nil,
                members: [MockMember(userID: uid, accessLevel: 0)]
            ))
            return .json(["group_id": id], status: 201)
        }

        api("POST", "/join/:code") { [weak self] _, params, uid, scenario in
            guard let group = scenario.groupByCode(params["code"] ?? "") else { return .empty(404) }
            if let member = group.member(uid) {
                switch member.status {
                case .blocked: return .empty(403)
                case .active: return .empty(409)
                case .left:
                    scenario.updateMember(groupID: group.id, userID: uid) { $0.status = .active }
                }
            } else {
                scenario.updateGroup(group.id) {
                    $0.members.append(MockMember(userID: uid, accessLevel: 2))
                }
            }
            let who = scenario.user(uid)?.name ?? "Someone"
            self?.pushEvent(type: "group_joined",
                            message: ["group": ["id": group.id, "name": group.name], "who": who])
            return .json(["group_id": group.id])
        }

        api("GET", "/groupbyid/:id") { _, params, uid, scenario in
            // Production quirk: 500 (not 404) for unknown group / non-member.
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id),
                  group.isActiveMember(uid) else { return .empty(500) }
            return .json(MockWire.group(group, in: scenario))
        }

        api("GET", "/groups") { _, _, uid, scenario in
            let groups = scenario.groups
                .filter { $0.isActiveMember(uid) }
                .map { MockWire.group($0, in: scenario) }
            return .json(groups)
        }

        api("GET", "/group/:code") { _, params, _, scenario in
            guard let group = scenario.groupByCode(params["code"] ?? "") else { return .empty(404) }
            return .json(MockWire.groupPeek(group, in: scenario))
        }

        api("PUT", "/group/:id/code") { _, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id) else { return .empty(500) }
            guard group.isAuthor(uid) else { return .empty(401) }
            let fresh = "RC\(Int.random(in: 100_000...999_999))"
            scenario.updateGroup(id) { $0.inviteCode = fresh }
            return .json(["code": fresh])
        }

        api("PUT", "/group/:id/nickname") { request, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id),
                  group.isActiveMember(uid) else { return .empty(404) } // no active membership
            let raw = request.bodyJSON?["nickname"] as? String // NSNull/absent → nil clears
            return Self.applyNickname(groupID: id, uid: uid, raw: raw, scenario: &scenario)
        }

        api("PUT", "/group/:id/visibility") { [weak self] request, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id) else { return .empty(404) }
            guard group.isAuthor(uid) else { return .empty(401) }
            let isPublic = request.bodyJSON?["is_public"] as? Bool ?? false
            let publicAt: Date? = isPublic ? (group.publicAt ?? Date()) : nil
            scenario.updateGroup(id) { $0.publicAt = publicAt }
            self?.pushEvent(type: "group_visibility_changed",
                            message: ["group_id": id, "public_at": MockWire.time(publicAt)])
            return .json(["public_at": MockWire.time(publicAt)])
        }

        api("PUT", "/group/:id/settings") { request, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), scenario.group(id) != nil else { return .empty(404) }
            guard scenario.group(id)!.isAuthor(uid) else { return .empty(401) }
            let body = request.bodyJSON ?? [:]
            if let description = body["description"] as? String, description.count > 1000 {
                return .empty(400)
            }
            // Spec §1.1: validate booster fields BEFORE persisting anything else, so a
            // bad request leaves all state intact (matches betty-api behavior).
            if let boostCount = body["boost_count"] as? Int, boostCount < 0 {
                return .json(["error": "invalid booster config"], status: 400)
            }
            if let boostMultiplier = body["boost_multiplier"] as? Int, boostMultiplier < 1 {
                return .json(["error": "invalid booster config"], status: 400)
            }
            // Partial update: only PRESENT keys are written; explicit null clears the
            // two nullable ones.
            scenario.updateGroup(id) { group in
                if body.keys.contains("welcome_message") {
                    group.welcomeMessage = body["welcome_message"] as? String
                }
                if body.keys.contains("description") {
                    group.description = body["description"] as? String
                }
                if let correct = body["correct_team_points"] as? Int, correct >= 0 {
                    group.correctTeamPoints = correct
                }
                if let exact = body["exact_result_points"] as? Int, exact >= 0 {
                    group.exactResultPoints = exact
                }
                if let peek = body["allow_sneak_peek"] as? Bool {
                    group.allowSneakPeek = peek
                }
                if let boostCount = body["boost_count"] as? Int, boostCount >= 0 {
                    group.boostCount = boostCount
                }
                if let boostMultiplier = body["boost_multiplier"] as? Int, boostMultiplier >= 1 {
                    group.boostMultiplier = boostMultiplier
                }
                group.updatedAt = Date()
            }
            return .json(MockWire.group(scenario.group(id)!, in: scenario))
        }

        api("POST", "/group/:id/join") { [weak self] _, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id),
                  group.publicAt != nil else { return .empty(404) } // missing OR private
            if let member = group.member(uid) {
                switch member.status {
                case .blocked: return .empty(403)
                case .active: return .empty(409)
                case .left:
                    scenario.updateMember(groupID: id, userID: uid) { $0.status = .active }
                }
            } else {
                scenario.updateGroup(id) {
                    $0.members.append(MockMember(userID: uid, accessLevel: 2))
                }
            }
            let who = scenario.user(uid)?.name ?? "Someone"
            self?.pushEvent(type: "group_joined",
                            message: ["group": ["id": group.id, "name": group.name], "who": who])
            return .json(["group_id": id])
        }

        api("GET", "/groups/public") { request, _, uid, scenario in
            let q = request.query["q"]?.lowercased() ?? ""
            let tournamentID = request.query["tournament_id"].flatMap(Int.init)
            let items = scenario.groups
                .filter { $0.publicAt != nil }
                .filter { q.isEmpty || $0.name.lowercased().contains(q) }
                .filter { tournamentID == nil || $0.tournamentID == tournamentID }
                .map { MockWire.publicGroupItem($0, callerID: uid, in: scenario) }
            return .json(["items": items, "next_cursor": ""]) // empty = no more pages
        }

        api("POST", "/groupbyid/:id/disable-peak") { _, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id) else { return .empty(500) }
            guard group.isAuthor(uid) else { return .empty(401) }
            scenario.updateGroup(id) { $0.allowSneakPeek = false }
            return .empty(200)
        }

        api("DELETE", "/group/:id/leave") { _, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id),
                  !group.members.isEmpty else { return .empty(400) }
            scenario.updateMember(groupID: id, userID: uid) { $0.status = .left }
            return .null()
        }

        api("DELETE", "/group/:id/block/:userid") { _, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id) else { return .empty(400) }
            // Production quirk: a non-author gets 500, not 401.
            guard group.isAuthor(uid) else { return .empty(500) }
            scenario.updateMember(groupID: id, userID: params["userid"] ?? "") { $0.status = .blocked }
            return .null()
        }

        api("POST", "/group/:id/header-image/upload-url") { [weak self] request, params, uid, scenario in
            guard let self else { return .empty(500) }
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id) else { return .empty(400) }
            guard group.isAuthor(uid) else { return .empty(401) }
            return self.presign(request, key: "groups/\(id)/header/mock-\(Int.random(in: 1000...9999))")
        }

        api("PUT", "/group/:id/header-image") { [weak self] request, params, uid, scenario in
            guard let self else { return .empty(500) }
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id) else { return .empty(400) }
            guard group.isAuthor(uid) else { return .empty(401) }
            guard let url = request.bodyJSON?["header_image_url"] as? String,
                  url.hasPrefix(self.publicAssetBase) else { return .empty(400) }
            scenario.updateGroup(id) { $0.headerImageURL = url }
            return .json(["header_image_url": url])
        }

        api("DELETE", "/group/:id/header-image") { _, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""), let group = scenario.group(id) else { return .empty(400) }
            guard group.isAuthor(uid) else { return .empty(401) }
            scenario.updateGroup(id) { $0.headerImageURL = nil }
            return .empty(200)
        }
    }

    private static func applyNickname(groupID: Int, uid: String, raw: String?,
                                      scenario: inout MockScenario) -> MockHTTPResponse {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.count <= 120 else {
            return .json(["error": "nickname too long"], status: 400)
        }
        let value: String? = trimmed.isEmpty ? nil : trimmed
        scenario.updateMember(groupID: groupID, userID: uid) { $0.nickname = value }
        return .json(["nickname": MockWire.orNull(value)])
    }

    // MARK: - Bets

    private func registerBetRoutes() {
        api("GET", "/bets/bygroup/:group") { _, params, _, scenario in
            guard let groupID = Int(params["group"] ?? "") else { return .empty(500) }
            // ALL members' bets for ALL games in the group.
            return .json(scenario.bets.filter { $0.groupID == groupID }.map { MockWire.bet($0) })
        }

        api("GET", "/bets/bygame/:game/:group") { _, params, uid, scenario in
            guard let gameID = Int(params["game"] ?? ""),
                  let groupID = Int(params["group"] ?? "") else { return .empty(500) }
            // The CALLER's own bets only.
            let mine = scenario.bets.filter {
                $0.userID == uid && $0.gameID == gameID && $0.groupID == groupID
            }
            return .json(mine.map { MockWire.bet($0) })
        }

        api("POST", "/bet") { [weak self] request, _, uid, scenario in
            let body = request.bodyJSON ?? [:]
            guard let gameID = body["game_id"] as? Int else { return .empty(400) }
            let groupID = body["group_id"] as? Int ?? 0
            let home = body["home_team_score"] as? Int ?? 0
            let away = body["away_team_score"] as? Int ?? 0
            let isUniversal = body["is_universal"] as? Bool ?? false
            let boosted = body["boosted"] as? Bool ?? false
            guard let game = scenario.game(gameID) else { return .empty(500) } // unknown game → 500
            guard game.startDate > Date() else { return .empty(423) }          // already started

            // Spec §1.2 booster validation against the bet's TARGET group (the row that
            // will be marked boosted). For universal bets the target is `group_id`; the
            // sibling rows in other groups are written `boosted: false` regardless.
            if boosted {
                guard let targetGroup = scenario.group(groupID) else { return .empty(401) }
                guard targetGroup.boostCount > 0 else {
                    return .json(["error": "boosters not enabled"], status: 400)
                }
                // For a no-op re-place keep the existing-boost exemption — usage count
                // EXCLUDES this user's existing bet on this game in this group.
                let existing = scenario.bets.first {
                    $0.userID == uid && $0.gameID == gameID && $0.groupID == groupID
                }
                let used = scenario.boostersUsed(userID: uid, groupID: groupID,
                                                 excludingBetID: existing?.id)
                if used >= targetGroup.boostCount {
                    return .json(["error": "no boosters remaining"], status: 400)
                }
            }

            // Track false→true transitions for the booster_applied emit.
            var transitionedBet: MockBet?
            if isUniversal {
                // Upsert into EVERY group of the caller in the game's tournament.
                // Only the row whose group_id matches request.group_id is `boosted`
                // (spec §2.3); siblings stay false even if `boosted: true`.
                for group in scenario.groups
                where group.tournamentID == game.tournamentID && group.isActiveMember(uid) {
                    let rowBoosted = (group.id == groupID) ? boosted : false
                    let previous = scenario.bets.first {
                        $0.userID == uid && $0.gameID == gameID && $0.groupID == group.id
                    }
                    let stored = scenario.upsertBet(userID: uid, gameID: gameID,
                                                   groupID: group.id, home: home, away: away,
                                                   boosted: rowBoosted)
                    if rowBoosted && !(previous?.boosted ?? false) {
                        transitionedBet = stored
                    }
                }
            } else {
                guard let group = scenario.group(groupID), group.isActiveMember(uid) else {
                    return .empty(401)
                }
                let previous = scenario.bets.first {
                    $0.userID == uid && $0.gameID == gameID && $0.groupID == groupID
                }
                let stored = scenario.upsertBet(userID: uid, gameID: gameID, groupID: groupID,
                                                home: home, away: away, boosted: boosted)
                if boosted && !(previous?.boosted ?? false) {
                    transitionedBet = stored
                }
                _ = group
            }
            let echo = MockWire.betEcho(userID: uid, gameID: gameID, groupID: groupID,
                                        home: home, away: away, isUniversal: isUniversal,
                                        boosted: boosted)
            self?.pushEvent(type: "bet_placed", message: echo)
            if let transitionedBet {
                self?.pushEvent(type: "booster_applied", message: MockWire.bet(transitionedBet))
            }
            // 200 (NOT 201) — echo with id 0 and zero timestamps.
            return .json(echo)
        }

        api("PUT", "/bet/:id") { [weak self] request, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""),
                  let index = scenario.bets.firstIndex(where: { $0.id == id }) else { return .empty(404) }
            let bet = scenario.bets[index]
            guard bet.userID == uid else { return .empty(401) } // someone else's bet
            if let game = scenario.game(bet.gameID), game.startDate <= Date() {
                return .empty(423)
            }
            guard bet.processedAt == nil else { return .empty(500) } // already evaluated
            let body = request.bodyJSON ?? [:]
            let requestedBoosted = body["boosted"] as? Bool ?? false

            // Spec §1.2 validation when flipping on (no-op true→true never fails).
            if requestedBoosted, requestedBoosted != bet.boosted {
                guard let targetGroup = scenario.group(bet.groupID) else { return .empty(401) }
                guard targetGroup.boostCount > 0 else {
                    return .json(["error": "boosters not enabled"], status: 400)
                }
                let used = scenario.boostersUsed(userID: uid, groupID: bet.groupID,
                                                 excludingBetID: bet.id)
                if used >= targetGroup.boostCount {
                    return .json(["error": "no boosters remaining"], status: 400)
                }
            }

            let previousBoosted = bet.boosted
            scenario.bets[index].homeTeamScore = body["home_team_score"] as? Int ?? bet.homeTeamScore
            scenario.bets[index].awayTeamScore = body["away_team_score"] as? Int ?? bet.awayTeamScore
            scenario.bets[index].boosted = requestedBoosted
            scenario.bets[index].updatedAt = Date()
            self?.pushEvent(type: "bet_updated", message: MockWire.bet(scenario.bets[index]))
            if requestedBoosted && !previousBoosted {
                self?.pushEvent(type: "booster_applied", message: MockWire.bet(scenario.bets[index]))
            }
            return .json(MockWire.bet(scenario.bets[index])) // the DB row, real id/timestamps
        }
    }

    // MARK: - Tournaments & games

    private func registerTournamentRoutes() {
        api("GET", "/tournaments") { _, _, _, scenario in
            guard !scenario.tournaments.isEmpty else { return .empty(404) } // empty table
            // pools/games are NULL in the list shape.
            return .json(scenario.tournaments.map { MockWire.tournament($0, details: false) })
        }

        api("GET", "/tournament/:id") { _, params, _, scenario in
            guard let id = Int(params["id"] ?? "") else { return .empty(500) }
            guard id >= 0 else { return .empty(400) }
            // 404 when unknown OR already ended (end_date <= NOW()).
            guard let tournament = scenario.tournament(id), !tournament.hasEnded() else {
                return .empty(404)
            }
            return .json(MockWire.tournament(tournament, details: true))
        }

        api("GET", "/tournament/:id/leaderboard") { request, params, _, scenario in
            guard let id = Int(params["id"] ?? ""), id >= 0 else { return .empty(400) }
            let limit = max(10, request.query["limit"].flatMap(Int.init) ?? 10)
            // Best normalized_score per user across the tournament's groups.
            var best: [String: Double] = [:]
            for group in scenario.groups where group.tournamentID == id {
                for member in group.members where member.status == .active {
                    best[member.userID] = max(best[member.userID] ?? 0, member.normalizedScore)
                }
            }
            let rows = best.sorted { $0.value > $1.value }.prefix(limit).map { userID, score -> [String: Any] in
                let user = scenario.user(userID)
                return [
                    "user_id": userID,
                    "name": MockWire.orNull(user?.name),
                    "nickname": NSNull(),     // not selected by the leaderboard SQL
                    "image_url": MockWire.orNull(user?.imageURL),
                    "score": 0,               // always 0 here
                    "normalized_score": score,
                    "access_level": 0,        // always 0 here
                ]
            }
            return .json(Array(rows))
        }

        api("GET", "/game/:id") { _, params, _, scenario in
            guard let id = Int(params["id"] ?? "") else { return .empty(500) }
            guard id >= 0 else { return .empty(400) }
            guard let game = scenario.game(id) else { return .empty(404) }
            return .json(MockWire.game(game))
        }

        api("PUT", "/game/:id") { request, params, _, scenario in
            guard let id = Int(params["id"] ?? "") else { return .empty(500) }
            guard scenario.game(id) != nil else { return .empty(404) }
            let body = request.bodyJSON ?? [:]
            // binding:"required" — a 0 (or missing) score is rejected with 400.
            guard let home = body["home_team_score"] as? Int, home != 0,
                  let away = body["away_team_score"] as? Int, away != 0 else { return .empty(400) }
            scenario.updateGame(id) {
                $0.homeTeamScore = home
                $0.awayTeamScore = away
                $0.updatedAt = Date()
            }
            return .null()
        }

        api("POST", "/evaluategame") { [weak self] request, _, _, scenario in
            let body = request.bodyJSON ?? [:]
            guard let gameID = body["game_id"] as? Int, gameID > 0 else { return .empty(400) }
            guard let game = scenario.game(gameID) else { return .empty(500) }
            guard game.status != 1 else { return .empty(410) } // already processed → Gone
            let home = body["home_team_score"] as? Int ?? 0
            let away = body["away_team_score"] as? Int ?? 0
            scenario.updateGame(gameID) {
                $0.homeTeamScore = home
                $0.awayTeamScore = away
                $0.status = 1
                $0.updatedAt = Date()
            }
            var exactUserIDs: [String] = []
            for index in scenario.bets.indices where scenario.bets[index].gameID == gameID {
                let bet = scenario.bets[index]
                let group = scenario.group(bet.groupID)
                let exact = bet.homeTeamScore == home && bet.awayTeamScore == away
                let correctSide = (bet.homeTeamScore > bet.awayTeamScore) == (home > away)
                    && ((bet.homeTeamScore == bet.awayTeamScore) == (home == away))
                let basePoints = exact ? (group?.exactResultPoints ?? 3)
                    : (correctSide ? (group?.correctTeamPoints ?? 1) : 0)
                // Spec §1.3 live-config-wins: multiply by current `boost_multiplier`
                // iff the bet is boosted AND boosters are still enabled in the group
                // (count > 0). Disabling count to 0 mid-tournament silently neutralizes
                // existing boosts (`× 1`).
                let multiplier: Int
                if bet.boosted, let group, group.boostCount > 0 {
                    multiplier = group.boostMultiplier
                } else {
                    multiplier = 1
                }
                let points = basePoints * multiplier
                scenario.bets[index].userPoints = points
                scenario.bets[index].processedAt = Date()
                scenario.updateMember(groupID: bet.groupID, userID: bet.userID) {
                    $0.score += points
                    $0.normalizedScore += Double(points)
                }
                if exact { exactUserIDs.append(bet.userID) }
            }
            self?.pushEvent(type: "evaluate_game",
                            message: ["game_id": gameID, "home_team_score": home, "away_team_score": away])
            if !exactUserIDs.isEmpty {
                self?.pushEvent(type: "user_exact_score",
                                message: ["game_id": gameID, "user_ids": exactUserIDs])
            }
            return .null()
        }

        api("PUT", "/rollbackgame/:gameid") { _, params, uid, scenario in
            guard scenario.user(uid)?.isAdmin == true else { return .empty(401) } // properly enforced
            guard let gameID = Int(params["gameid"] ?? ""), scenario.game(gameID) != nil else {
                return .empty(500)
            }
            scenario.updateGame(gameID) { $0.status = nil }
            for index in scenario.bets.indices where scenario.bets[index].gameID == gameID {
                scenario.bets[index].userPoints = nil
                scenario.bets[index].processedAt = nil
            }
            return .null()
        }
    }

    // MARK: - FIFA admin (result proposals)

    private func registerFIFARoutes() {
        api("GET", "/admin/fifa/proposals/count") { request, _, uid, scenario in
            guard scenario.user(uid)?.isAdmin == true else { return .empty(401) }
            let status = request.query["status"] ?? "pending"
            let count = scenario.fifaProposals.filter { $0.status == status }.count
            return .json(["count": count])
        }

        api("GET", "/admin/fifa/proposals") { request, _, uid, scenario in
            guard scenario.user(uid)?.isAdmin == true else { return .empty(401) }
            let status = request.query["status"] ?? "pending"
            let proposals = scenario.fifaProposals
                .filter { $0.status == status }
                .map { MockWire.fifaProposal($0) }
            return .json(["proposals": proposals])
        }

        api("GET", "/admin/fifa/unsettled-finals") { _, _, uid, scenario in
            guard scenario.user(uid)?.isAdmin == true else { return .empty(401) }
            let unsettled = scenario.fifaUnsettledFinals.map { MockWire.fifaUnsettledFinal($0) }
            return .json(["unsettled": unsettled])
        }

        api("POST", "/admin/fifa/proposals/:id/confirm") { _, params, uid, scenario in
            guard scenario.user(uid)?.isAdmin == true else { return .empty(401) }
            guard let id = Int(params["id"] ?? ""), let proposal = scenario.fifaProposal(id) else {
                return .empty(500)
            }
            guard proposal.status == "pending" else { return .empty(410) } // already processed → Gone
            // Apply like manual evaluation: finalize the game, then move the proposal to
            // applied so the Pending tab no longer returns it.
            scenario.updateGame(proposal.gameID) {
                $0.homeTeamScore = proposal.homeTeamScore
                $0.awayTeamScore = proposal.awayTeamScore
                $0.status = 1
                $0.updatedAt = Date()
            }
            scenario.updateFIFAProposal(id) { $0.status = "applied" }
            return .null()
        }

        api("POST", "/admin/fifa/proposals/:id/dismiss") { _, params, uid, scenario in
            guard scenario.user(uid)?.isAdmin == true else { return .empty(401) }
            guard let id = Int(params["id"] ?? ""), scenario.fifaProposal(id) != nil else {
                return .empty(500)
            }
            scenario.updateFIFAProposal(id) { $0.status = "dismissed" }
            return .null()
        }
    }

    // MARK: - Reference data

    private func registerReferenceRoutes() {
        api("GET", "/teams") { _, _, _, scenario in
            guard !scenario.teams.isEmpty else { return .empty(404) }
            return .json(scenario.teams.map { MockWire.team($0) })
        }
        api("GET", "/categories") { _, _, _, scenario in
            guard !scenario.categories.isEmpty else { return .empty(404) }
            return .json(scenario.categories.map { MockWire.category($0) })
        }
        api("GET", "/arenas") { _, _, _, scenario in
            .json(scenario.arenas.map { MockWire.arena($0) })
        }
        api("GET", "/arenas/:country") { _, params, _, scenario in
            .json(scenario.arenas.filter { $0.country == params["country"] }.map { MockWire.arena($0) })
        }
        api("GET", "/countries") { _, _, _, scenario in
            .json(scenario.countries.map { MockWire.country($0) })
        }
    }

    // MARK: - Message board

    private func registerMessageBoardRoutes() {
        api("GET", "/messageboard/:groupid") { request, params, uid, scenario in
            guard let groupID = Int(params["groupid"] ?? ""), let group = scenario.group(groupID) else {
                return .empty(400)
            }
            // ANY membership status counts here (the check ignores status).
            guard group.member(uid) != nil else { return .empty(403) }
            let amount = request.query["amount"].flatMap(Int.init) ?? 50
            let page = request.query["offset"].flatMap(Int.init) ?? 0 // PAGE INDEX
            let all = scenario.messages
                .filter { $0.groupID == groupID && !$0.deleted }
                .sorted { $0.createdAt > $1.createdAt } // newest first
            let start = page * amount
            guard start < all.count, amount > 0 else { return .json([Any]()) }
            let slice = all[start..<min(start + amount, all.count)]
            return .json(slice.map { MockWire.message($0) })
        }

        api("POST", "/messageboard") { request, _, uid, scenario in
            let body = request.bodyJSON ?? [:]
            guard let groupID = body["group_id"] as? Int, let group = scenario.group(groupID) else {
                return .empty(400)
            }
            guard group.member(uid) != nil else { return .empty(403) }
            let text = body["body"] as? String
            let imageURL = body["image_url"] as? String
            guard text != nil || imageURL != nil else { return .empty(400) }
            let message = MockMessage(id: scenario.nextMessageID, groupID: groupID, userID: uid,
                                      body: text, imageURL: imageURL)
            scenario.nextMessageID += 1
            scenario.messages.append(message)
            // 201, with "reactions": null (not attached on create).
            return .json(MockWire.message(message, nullReactions: true), status: 201)
        }

        api("DELETE", "/messageboard/:id") { _, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""),
                  let index = scenario.messages.firstIndex(where: { $0.id == id }),
                  scenario.messages[index].userID == uid,
                  !scenario.messages[index].deleted else { return .empty(404) }
            scenario.messages[index].deleted = true
            return .empty(204)
        }

        api("PUT", "/messageboard/:id/reaction") { request, params, uid, scenario in
            let emoji = (request.bodyJSON?["emoji_id"] as? String) ?? ""
            guard !emoji.isEmpty, emoji.count <= 64 else {
                return .json(["error": "emoji_id required, max 64 chars"], status: 400)
            }
            guard let id = Int(params["id"] ?? ""),
                  let index = scenario.messages.firstIndex(where: { $0.id == id && !$0.deleted })
            else { return .empty(404) }
            guard scenario.group(scenario.messages[index].groupID)?.member(uid) != nil else {
                return .empty(403)
            }
            // One reaction per user per message (server-enforced upsert).
            scenario.messages[index].reactions.removeAll { $0.userID == uid }
            scenario.messages[index].reactions.append(MockReaction(userID: uid, emojiID: emoji))
            return .empty(204)
        }

        api("DELETE", "/messageboard/:id/reaction") { _, params, uid, scenario in
            guard let id = Int(params["id"] ?? ""),
                  let index = scenario.messages.firstIndex(where: { $0.id == id && !$0.deleted })
            else { return .empty(404) }
            guard scenario.group(scenario.messages[index].groupID)?.member(uid) != nil else {
                return .empty(403)
            }
            scenario.messages[index].reactions.removeAll { $0.userID == uid } // idempotent
            return .empty(204)
        }
    }

    // MARK: - Announcements & feature requests

    private func registerAnnouncementRoutes() {
        api("GET", "/announcements") { _, _, _, scenario in
            .json(scenario.announcements.sorted { $0.createdAt > $1.createdAt }
                .map { MockWire.announcement($0) })
        }

        api("POST", "/announcement") { request, _, uid, scenario in
            guard scenario.user(uid)?.isAdmin == true else { return .empty(403) }
            let body = request.bodyJSON ?? [:]
            guard let title = body["title"] as? String, !title.isEmpty,
                  let text = body["body"] as? String, !text.isEmpty,
                  let category = body["category"] as? String,
                  ["info", "warning", "excitement", "important", "reminder"].contains(category)
            else { return .empty(400) }
            let announcement = MockAnnouncement(id: scenario.nextAnnouncementID, userID: uid,
                                                title: title, body: text, category: category,
                                                cta: body["cta"] as? String)
            scenario.nextAnnouncementID += 1
            scenario.announcements.append(announcement)
            return .json(MockWire.announcement(announcement), status: 201)
        }

        api("POST", "/feature-requests") { request, _, uid, scenario in
            let description = (request.bodyJSON?["description"] as? String) ?? ""
            guard (1...5000).contains(description.count) else { return .empty(400) }
            let id = scenario.nextFeatureRequestID
            scenario.nextFeatureRequestID += 1
            return .json([
                "id": id,
                "user_id": uid,
                "description": description,
                "created_at": MockWire.time(Date()),
            ], status: 201)
        }
    }

    // MARK: - Presigned upload plumbing

    /// Shared 415/413/400 validation for both upload-url endpoints.
    private func presign(_ request: MockHTTPRequest, key: String) -> MockHTTPResponse {
        let body = request.bodyJSON ?? [:]
        guard let contentType = body["content_type"] as? String,
              let contentLength = body["content_length"] as? Int, contentLength > 0
        else { return .empty(400) }
        guard Self.allowedImageTypes.contains(contentType) else { return .empty(415) }
        guard contentLength <= 1 << 20 else { return .empty(413) } // 1 MiB
        let ext = contentType == "image/jpeg" ? "jpg" : String(contentType.dropFirst("image/".count))
        return .json(MockWire.presignedUpload(key: "\(key).\(ext)", httpBase: httpBase,
                                              contentType: contentType, contentLength: contentLength))
    }

    /// The raw R2 PUT — outside the API base/bearer, accepts the presigned upload bytes.
    private func registerUploadCatchAll() {
        http.route("PUT", "/_upload/*") { _, _ in .empty(200) }
        http.route("GET", "/_public/*") { _, _ in
            MockHTTPResponse(status: 200, headers: ["Content-Type": "image/png"], body: Data())
        }
    }
}
