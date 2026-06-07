import Foundation
import Observation

/// Central WebSocket → store wiring (web: the `evaluate_game` window event plus the
/// per-page refetches it triggers).
///
/// Store mutations driven by events:
/// - `evaluate_game` (the web's ONLY event-driven mutation): force-reloads every cached
///   tournament detail containing the game, refreshes the game in `GameStore` (live
///   scores), and reloads the loaded group's bet matrix (evaluated `user_points`).
/// - `bet_placed` / `bet_updated` (native improvement over the web's 10 s poll): reloads
///   the bet matrix when the bet targets the loaded group (or is universal).
///
/// There are NO message-board events on the wire — chat stays on its 10 s poll.
///
/// `evaluationCount` is the leaderboard refresh trigger: leaderboards are never cached,
/// so screens observe the counter (`onChange`) and refetch.
@Observable
final class LiveUpdateCoordinator {
    private let tournamentStore: TournamentStore
    private let gameStore: GameStore
    private let betStore: BetStore

    /// Bumped on EVERY `evaluate_game` (even for unknown games) — observe to refetch
    /// leaderboards / force-reload the visible tournament.
    private(set) var evaluationCount = 0
    private(set) var lastEvaluatedGameID: Int?

    /// Bumped on EVERY `bet_placed`/`bet_updated` — Home observes it to refresh the
    /// need-action section (its per-group bet matrices live outside `BetStore`).
    private(set) var betActivityCount = 0

    private var consumeTask: Task<Void, Never>?

    init(tournamentStore: TournamentStore, gameStore: GameStore, betStore: BetStore) {
        self.tournamentStore = tournamentStore
        self.gameStore = gameStore
        self.betStore = betStore
    }

    /// Starts consuming the socket's event stream (replaces any previous attachment).
    /// Reconnects are transparent — attach once per sign-in.
    func attach(to socket: WebSocketService) {
        consumeTask?.cancel()
        consumeTask = Task { [weak self] in
            let stream = socket.events()
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                await self.handle(event)
            }
        }
    }

    func detach() {
        consumeTask?.cancel()
        consumeTask = nil
    }

    /// Applies one event. All refresh failures are swallowed — the feed is broadcast-only
    /// and every refresh is recovered by polling / foreground reloads.
    func handle(_ event: BettyEvent) async {
        switch event {
        case .evaluateGame(let payload):
            await applyEvaluation(payload)
        case .betPlaced(let bet), .betUpdated(let bet):
            await refreshBetMatrix(for: bet)
            betActivityCount += 1
        default:
            break // informational only (feed renders them; no store state changes)
        }
    }

    private func applyEvaluation(_ payload: WSEvaluateGame) async {
        if gameStore.byID(payload.gameID) != nil {
            try? await gameStore.reload(id: payload.gameID)
        }
        let affectedTournaments = tournamentStore.details
            .filter { _, detail in (detail.games ?? []).contains { $0.id == payload.gameID } }
            .map(\.key)
        for id in affectedTournaments {
            try? await tournamentStore.loadDetails(id: id, force: true)
        }
        if let groupID = betStore.loadedGroupID {
            try? await betStore.load(groupID: groupID)
        }
        lastEvaluatedGameID = payload.gameID
        evaluationCount += 1
    }

    private func refreshBetMatrix(for bet: Bet) async {
        guard let loadedGroupID = betStore.loadedGroupID,
              bet.groupID == loadedGroupID || bet.isUniversal else { return }
        try? await betStore.load(groupID: loadedGroupID)
    }
}
