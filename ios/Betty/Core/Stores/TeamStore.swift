import Foundation
import Observation

/// Static reference data — team names + logo keys for game rows. Loaded once at boot;
/// refresh on foreground only if empty.
@Observable
final class TeamStore {
    private let api: APIClient

    private(set) var teams: [Team] = []
    private(set) var isLoaded = false
    /// When the teams were last fetched — drives the 24 h foreground staleness check.
    private(set) var loadedAt: Date?

    init(api: APIClient) {
        self.api = api
    }

    /// May return nil — views must degrade gracefully (blank name, neutral logo).
    func byID(_ id: Int) -> Team? {
        teams.first { $0.id == id }
    }

    func teams(tournamentID: Int) -> [Team] {
        teams.filter { $0.tournamentID == tournamentID }
    }

    func clear() {
        teams = []
        isLoaded = false
        loadedAt = nil
    }

    /// `GET /teams` — all tournaments (404 on empty table → []).
    func load() async throws {
        teams = try await api.teams()
        isLoaded = true
        loadedAt = Date()
    }
}
