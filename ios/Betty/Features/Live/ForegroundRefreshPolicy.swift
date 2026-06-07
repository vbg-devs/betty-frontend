import Foundation

/// Foreground (`scenePhase == .active`) refresh rules from the data-layer spec:
/// groups + tournament summaries reload every time; teams only when never loaded or
/// stale for more than 24 hours.
nonisolated enum ForegroundRefreshPolicy {
    static let teamsMaxAge: TimeInterval = 24 * 60 * 60

    static func shouldReloadTeams(isLoaded: Bool, loadedAt: Date?, now: Date = Date()) -> Bool {
        guard isLoaded, let loadedAt else { return true }
        return now.timeIntervalSince(loadedAt) > teamsMaxAge
    }
}
