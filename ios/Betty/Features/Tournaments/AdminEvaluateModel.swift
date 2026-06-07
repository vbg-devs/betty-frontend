import Foundation
import Observation

/// State for the admin evaluate screen (web `/admin`). Mirrors the page's pinned
/// behaviors: details are fetched once per selection (re-selecting the same tournament
/// does not refetch), the games list hides evaluated games (`status == 1`) and sorts by
/// kickoff, and a successful evaluation refetches the tournament.
@Observable
final class AdminEvaluateModel {
    private let api: APIClient

    private(set) var selectedTournamentID: Int?
    private(set) var details: Tournament?
    private(set) var isLoadingDetails = false
    private(set) var loadFailed = false
    private(set) var isSubmitting = false

    init(api: APIClient) {
        self.api = api
    }

    /// Un-evaluated games (`status != 1`) ordered by kickoff time.
    var pendingGames: [Game] {
        (details?.games ?? [])
            .filter { $0.status != 1 }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Web `canSave`: the game has kicked off, both scores are entered (whole numbers),
    /// and the game is not already evaluated.
    nonisolated static func canSave(
        game: Game,
        homeScore: String,
        awayScore: String,
        now: Date = Date()
    ) -> Bool {
        guard game.startDate < now else { return false }
        guard game.status != 1 else { return false }
        return Int(homeScore) != nil && Int(awayScore) != nil
    }

    /// The web confirm copy, verbatim (missing teams render "?").
    nonisolated static func confirmQuestion(
        homeTeam: String?,
        awayTeam: String?,
        homeScore: String,
        awayScore: String
    ) -> String {
        "Report that \(homeTeam ?? "?") - \(awayTeam ?? "?") ended \(homeScore) - \(awayScore)? Make sure the score is correct"
    }

    /// Fetch `GET /tournament/:id` for a newly selected tournament. Selecting the
    /// already-selected tournament is a no-op (web `watch` only fires on change).
    func select(tournamentID: Int) async throws {
        guard selectedTournamentID != tournamentID else { return }
        selectedTournamentID = tournamentID
        details = nil
        loadFailed = false
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            let detail = try await api.tournament(id: tournamentID)
            guard selectedTournamentID == tournamentID else { return }
            details = detail
        } catch {
            if selectedTournamentID == tournamentID { loadFailed = true }
            throw error
        }
    }

    /// Re-fetch the current selection (retry after a failed load).
    func reloadDetails() async throws {
        guard let id = selectedTournamentID else { return }
        loadFailed = false
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            details = try await api.tournament(id: id)
        } catch {
            loadFailed = true
            throw error
        }
    }

    /// `POST /evaluategame` then refetch the tournament so the game disappears from the
    /// pending list. A refetch failure is swallowed (the evaluation itself succeeded).
    /// Throws `.gone` (410) when the game was already processed.
    func evaluate(game: Game, homeScore: Int, awayScore: Int) async throws {
        isSubmitting = true
        defer { isSubmitting = false }
        try await api.evaluateGame(gameID: game.id, homeTeamScore: homeScore, awayTeamScore: awayScore)
        if let id = selectedTournamentID, let refreshed = try? await api.tournament(id: id) {
            details = refreshed
        }
    }
}
