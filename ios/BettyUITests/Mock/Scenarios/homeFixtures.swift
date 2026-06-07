import Foundation

// Home-area fixture helpers layered on DefaultScenario.
extension MockScenario {
    /// Removes the user from every group so `/user/:id/groups` answers an empty list
    /// (the dashboard global empty state).
    mutating func homeRemoveAllMemberships(of userID: String) {
        for index in groups.indices {
            groups[index].members.removeAll { $0.userID == userID }
        }
    }

    mutating func homeRemoveMembership(of userID: String, fromGroup groupID: Int) {
        updateGroup(groupID) { group in
            group.members.removeAll { $0.userID == userID }
        }
    }

    /// Pushes the ended tournament past the 28-day recently-ended window so its groups
    /// classify into the Ended tab instead of Running + JUST ENDED.
    mutating func homeEndTournamentBeyondRecentWindow(_ tournamentID: Int) {
        homeSetTournamentDates(
            tournamentID,
            start: Date().addingTimeInterval(-70 * 86_400),
            end: Date().addingTimeInterval(-40 * 86_400)
        )
    }

    mutating func homeSetTournamentDates(_ tournamentID: Int, start: Date? = nil, end: Date? = nil) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else { return }
        if let start { tournaments[index].startDate = start }
        if let end { tournaments[index].endDate = end }
    }

    /// Adds an un-bet, unfinished game to the running tournament (need-action input).
    mutating func homeAddUpcomingGame(
        id: Int,
        startingIn interval: TimeInterval,
        homeTeamID: Int = 102,
        awayTeamID: Int = 104
    ) {
        guard let index = tournaments.firstIndex(where: { $0.id == DefaultScenario.runningTournamentID })
        else { return }
        tournaments[index].games.append(MockGame(
            id: id,
            tournamentID: DefaultScenario.runningTournamentID,
            poolID: 1,
            homeTeamID: homeTeamID,
            awayTeamID: awayTeamID,
            startDate: Date().addingTimeInterval(interval),
            status: nil
        ))
    }

    /// Bets the game for the user in every group they're an active member of — the
    /// need-action banner treats a game as bet only when each surfacing group has a bet.
    mutating func homeBetEverywhere(userID: String, gameID: Int, home: Int, away: Int) {
        for group in groups where group.isActiveMember(userID) {
            upsertBet(userID: userID, gameID: gameID, groupID: group.id, home: home, away: away)
        }
    }
}

extension BettyMockBackend {
    /// Re-registers the stock `/user/:id/groups` handler (LAST registration wins) —
    /// recovers the route after a test forced it to fail.
    func homeRestoreUserGroupsRoute() {
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
}
