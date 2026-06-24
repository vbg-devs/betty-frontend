import Foundation
import Observation

/// Two independent caches: `tournaments` (summary list — `pools`/`games` are null there)
/// and `details` (full per-id payloads with the FLAT `pools[]` + `games[]`).
@Observable
final class TournamentStore {
    private let api: APIClient

    private(set) var tournaments: [Tournament] = []
    private(set) var details: [Int: Tournament] = [:]
    private(set) var isLoaded = false

    init(api: APIClient) {
        self.api = api
    }

    /// Tournaments where `end_date` is missing OR `end_date >= now`.
    var running: [Tournament] {
        tournaments.filter { $0.isRunning() }
    }

    func byID(_ id: Int) -> Tournament? {
        tournaments.first { $0.id == id }
    }

    /// Nil until `loadDetails(id:)` ran for this id.
    func detailsByID(_ id: Int) -> Tournament? {
        details[id]
    }

    func clear() {
        tournaments = []
        details = [:]
        isLoaded = false
    }

    /// `GET /tournaments` — replaces the summary list (404 on empty table → []).
    /// Returns ALL tournaments including finished ones.
    func load() async throws {
        tournaments = try await api.tournaments()
        isLoaded = true
    }

    /// `GET /tournament/:id` — cached per id; refetches only when `force` (the
    /// `evaluate_game` WS event forces). 404 when the tournament is unknown OR has
    /// already ended. Failures leave the cache untouched.
    @discardableResult
    func loadDetails(id: Int, force: Bool = false) async throws -> Tournament {
        if !force, let cached = details[id] {
            return cached
        }
        let detail = try await api.tournament(id: id)
        details[id] = detail
        return detail
    }

    /// `GET /tournament/:id/leaderboard?limit=` — NOT cached (fetched per screen view).
    /// Only `user_id`, `name`, `image_url`, `normalized_score` are meaningful in rows.
    func leaderboard(id: Int, limit: Int = 100) async throws -> [Member] {
        try await api.tournamentLeaderboard(id: id, limit: limit)
    }

    /// Web default-leaderboard rule: from `running` (fallback all), the tournament with
    /// the LATEST `start_date`.
    var defaultLeaderboardTournament: Tournament? {
        let pool = running.isEmpty ? tournaments : running
        return pool.max { $0.startDate < $1.startDate }
    }
}
