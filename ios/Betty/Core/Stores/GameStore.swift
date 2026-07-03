import Foundation
import Observation

/// Tiny fetch-through game cache for activity-feed items (`GET /game/:id`).
/// Feed rows lazily call `load(id:)` when a game is not cached and never re-fetch a
/// cached one.
@Observable
final class GameStore {
    private let api: APIClient

    private(set) var games: [Game] = []

    init(api: APIClient) {
        self.api = api
    }

    func byID(_ id: Int) -> Game? {
        games.first { $0.id == id }
    }

    func clear() {
        games = []
    }

    /// Upserts by id; already-cached games are returned without a network call.
    @discardableResult
    func load(id: Int) async throws -> Game {
        if let cached = byID(id) {
            return cached
        }
        let game = try await api.game(id: id)
        upsert(game)
        return game
    }

    /// Force-refreshes a single game (e.g. after `evaluate_game`).
    @discardableResult
    func reload(id: Int) async throws -> Game {
        let game = try await api.game(id: id)
        upsert(game)
        return game
    }

    /// Patches a cached game's live score in place (`live_score_update`); no-op if the
    /// game isn't cached (mirrors `TournamentStore.applyLiveScore`'s cache-only semantics).
    func applyLiveScore(_ payload: WSLiveScoreUpdate) {
        guard let index = games.firstIndex(where: { $0.id == payload.gameID }) else { return }
        games[index] = games[index].withLiveScore(
            home: payload.homeTeamScore,
            away: payload.awayTeamScore,
            liveStatus: payload.liveStatus)
    }

    private func upsert(_ game: Game) {
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index] = game
        } else {
            games.append(game)
        }
    }
}
