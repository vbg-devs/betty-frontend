import Foundation
import Observation

/// Bets for ONE group screen — instantiate per open group (`@State` in the view) or use
/// the shared instance and call `load(groupID:)` when switching groups.
///
/// `bets` holds ALL members' bets for ALL games of the loaded group
/// (`GET /bets/bygroup/:id` — the bet-matrix source). The group screen re-fetches: on
/// appear, every 10 s while visible, and after each successful placement.
@Observable
final class BetStore {
    private let api: APIClient

    private(set) var bets: [Bet] = []
    private(set) var loadedGroupID: Int?

    init(api: APIClient) {
        self.api = api
    }

    func clear() {
        bets = []
        loadedGroupID = nil
    }

    /// Bets for one game in the loaded group (client-side filter of the matrix).
    /// Join members via `Group.member(withUserID:)` for display.
    func betsForGame(_ gameID: Int) -> [Bet] {
        bets.filter { $0.gameID == gameID }
    }

    /// First own bet for a game — `myBet` in the bet sheet (UID string compare).
    func myBet(gameID: Int, userID: String?) -> Bet? {
        BetOwnership.firstOwnBet(in: bets, gameID: gameID, userID: userID)
    }

    /// `GET /bets/bygroup/:groupID`.
    func load(groupID: Int) async throws {
        bets = try await api.bets(groupID: groupID)
        loadedGroupID = groupID
    }

    /// `GET /bets/bygame/:game/:group` — the CALLER's own bets, deduped by id (the wire
    /// can repeat rows once per membership). Use to learn a bet's real id after POST.
    func ownBets(gameID: Int, groupID: Int) async throws -> [Bet] {
        try await api.bets(gameID: gameID, groupID: groupID)
    }

    /// `POST /bet` — returns 200 with a request ECHO (`id: 0`, zero timestamps); the new
    /// bet's real id is NOT returned — re-fetch via `ownBets` before updating it.
    /// `isUniversal: true` upserts the bet into every group of the game's tournament.
    /// Throws `.locked` (423) when the game already started ("betting closed").
    ///
    /// CRITICAL universal-edit rule (regression-pinned by the web): editing an existing
    /// bet with "place in all my groups" checked must RE-POST here with
    /// `isUniversal: true` — `update(...)` only ever touches a single bet.
    @discardableResult
    func place(gameID: Int, groupID: Int, homeTeamScore: Int, awayTeamScore: Int, isUniversal: Bool) async throws -> Bet {
        let echo = try await api.placeBet(PlaceBetRequest(
            gameID: gameID,
            groupID: groupID,
            homeTeamScore: homeTeamScore,
            awayTeamScore: awayTeamScore,
            isUniversal: isUniversal
        ))
        if loadedGroupID == groupID {
            try? await load(groupID: groupID)
        }
        return echo
    }

    /// `PUT /bet/:id` — SINGLE-group edit only (404 unknown id, 423 started, 401 not
    /// yours, 500 already processed). Patches the matching local entry.
    @discardableResult
    func update(betID: Int, homeTeamScore: Int, awayTeamScore: Int) async throws -> Bet {
        let updated = try await api.updateBet(id: betID, homeTeamScore: homeTeamScore, awayTeamScore: awayTeamScore)
        if let index = bets.firstIndex(where: { $0.id == betID }) {
            bets[index] = updated
        }
        return updated
    }
}
