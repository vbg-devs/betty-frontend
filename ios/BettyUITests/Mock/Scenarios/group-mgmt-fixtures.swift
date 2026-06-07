import Foundation

/// Fixtures for the group-management e2e suite: DefaultScenario plus enough public
/// groups to exercise the browse list (pagination, search, tournament filter).
enum GroupMgmtFixtures {
    static let springTournamentID = 5
    static let springGroupID = 41
    static let springGroupName = "Spring Hoppers"

    static let arenaClubBaseID = 50
    static let arenaClubCount = 8

    static func arenaClubName(_ number: Int) -> String {
        String(format: "Arena Club %02d", number)
    }

    /// DefaultScenario + a second RUNNING tournament with one public group and 8 public
    /// "Arena Club NN" Euro Cup groups (alex is a member of none of them).
    static func browseScenario(now: Date = Date()) -> MockScenario {
        var scenario = DefaultScenario.build(now: now)

        scenario.tournaments.append(MockTournament(
            id: springTournamentID, name: "Spring Invitational",
            startDate: now.addingTimeInterval(-3 * 86_400),
            endDate: now.addingTimeInterval(30 * 86_400),
            categoryID: 1
        ))
        scenario.groups.append(MockGroup(
            id: springGroupID, name: springGroupName,
            tournamentID: springTournamentID, inviteCode: "SPRING",
            description: "Hop in.",
            publicAt: now.addingTimeInterval(-86_400),
            createdAt: now.addingTimeInterval(-2 * 86_400),
            members: [MockMember(userID: DefaultScenario.friendUserID, accessLevel: 0)]
        ))

        for index in 0..<arenaClubCount {
            scenario.groups.append(MockGroup(
                id: arenaClubBaseID + index,
                name: arenaClubName(index + 1),
                tournamentID: DefaultScenario.runningTournamentID,
                inviteCode: "CLUB0\(index + 1)",
                publicAt: now.addingTimeInterval(-3600),
                createdAt: now.addingTimeInterval(-Double(index + 2) * 3600),
                members: [MockMember(userID: DefaultScenario.rivalUserID, accessLevel: 0)]
            ))
        }
        return scenario
    }
}

extension BettyMockBackend {
    /// Replaces the built-in single-page `/groups/public` route with REAL cursor
    /// pagination (opaque cursor = offset into the filtered list), preserving the
    /// `q` / `tournament_id` filters and the contract shape
    /// `{ "items": [...], "next_cursor": "" }` (empty string = no more pages).
    func installPaginatedPublicGroups(pageSize: Int) {
        api("GET", "/groups/public") { request, _, uid, scenario in
            let q = request.query["q"]?.lowercased() ?? ""
            let tournamentID = request.query["tournament_id"].flatMap(Int.init)
            let all = scenario.groups
                .filter { $0.publicAt != nil }
                .filter { q.isEmpty || $0.name.lowercased().contains(q) }
                .filter { tournamentID == nil || $0.tournamentID == tournamentID }
            let offset = request.query["cursor"].flatMap(Int.init) ?? 0
            let page = Array(all.dropFirst(offset).prefix(pageSize))
            let nextOffset = offset + page.count
            return .json([
                "items": page.map { MockWire.publicGroupItem($0, callerID: uid, in: scenario) },
                "next_cursor": nextOffset < all.count ? String(nextOffset) : "",
            ])
        }
    }
}
