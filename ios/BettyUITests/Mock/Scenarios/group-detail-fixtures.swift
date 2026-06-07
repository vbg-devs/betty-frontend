import Foundation

// Group-detail suite fixtures — small, composable tweaks layered onto
// `DefaultScenario` via `withScenario` BEFORE `launchApp()`.

extension MockScenario {
    /// Flips `allow_sneak_peek` on a group (default: Sunday Legends).
    mutating func groupDetailSetSneakPeek(
        _ allowed: Bool,
        groupID: Int = DefaultScenario.groupSundayLegendsID
    ) {
        updateGroup(groupID) { $0.allowSneakPeek = allowed }
    }

    /// Adds a bet with explicit evaluation state (processed bets carry points).
    mutating func groupDetailAddBet(
        userID: String,
        gameID: Int,
        groupID: Int = DefaultScenario.groupSundayLegendsID,
        home: Int,
        away: Int,
        points: Int? = nil,
        processed: Bool = false
    ) {
        let bet = MockBet(
            id: nextBetID,
            userID: userID,
            gameID: gameID,
            groupID: groupID,
            userPoints: points,
            homeTeamScore: home,
            awayTeamScore: away,
            processedAt: processed ? Date().addingTimeInterval(-3600) : nil,
            createdAt: Date().addingTimeInterval(-86_400)
        )
        nextBetID += 1
        bets.append(bet)
    }

    /// Overrides a member's score (drives dense-ranking/tie fixtures).
    mutating func groupDetailSetMemberScore(
        userID: String,
        score: Int,
        groupID: Int = DefaultScenario.groupSundayLegendsID
    ) {
        updateMember(groupID: groupID, userID: userID) {
            $0.score = score
            $0.normalizedScore = Double(score)
        }
    }

    /// Appends an extra active participant (top-3 cutoff fixtures).
    mutating func groupDetailAddMember(
        userID: String,
        score: Int,
        groupID: Int = DefaultScenario.groupSundayLegendsID
    ) {
        updateGroup(groupID) {
            $0.members.append(MockMember(userID: userID, score: score,
                                         normalizedScore: Double(score), accessLevel: 2))
        }
    }

    /// Sets/clears a group's committed cover image (flips the author CTA between
    /// "+ ADD COVER" and "CHANGE COVER →").
    mutating func groupDetailSetHeaderImage(
        _ url: String?,
        groupID: Int = DefaultScenario.groupSundayLegendsID
    ) {
        updateGroup(groupID) { $0.headerImageURL = url }
    }

    /// Renames the running tournament's pools in order (pool-name header fixtures —
    /// names containing "Group" collapse the schedule header to the day title only).
    mutating func groupDetailRenamePools(
        _ names: [String],
        tournamentID: Int = DefaultScenario.runningTournamentID
    ) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else { return }
        for (offset, name) in names.enumerated() where offset < tournaments[index].pools.count {
            tournaments[index].pools[offset].name = name
        }
    }
}
