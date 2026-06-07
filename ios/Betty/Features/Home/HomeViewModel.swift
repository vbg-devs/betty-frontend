import Foundation
import Observation

/// Home/dashboard state. Groups come from the rich `GET /user/:id/groups` payload
/// (placement + member count per group); the need-action banner additionally pulls
/// tournament details (flat `games[]`) and each non-ended group's bet matrix.
@Observable
final class HomeViewModel {
    private let api: APIClient
    private let userStore: UserStore
    private let tournamentStore: TournamentStore

    private(set) var placements: [GroupPlacement] = []
    private(set) var needActionSources: [HomeNeedActionSource] = []
    private(set) var isLoaded = false
    private(set) var loadFailed = false

    var selectedTab: HomeTab = .running

    init(api: APIClient, userStore: UserStore, tournamentStore: TournamentStore) {
        self.api = api
        self.userStore = userStore
        self.tournamentStore = tournamentStore
    }

    var userID: String? { userStore.id }

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        await refresh(forceDetails: false)
    }

    /// Re-fetches tournaments + the rich groups payload (web pull-to-refresh re-fetches
    /// both), then the need-action inputs. A failed refresh keeps the last good list;
    /// `loadFailed` flags only the nothing-loaded case.
    func refresh(forceDetails: Bool = true) async {
        guard let uid = userStore.id else {
            isLoaded = true
            return
        }
        do {
            if tournamentStore.isLoaded {
                try? await tournamentStore.load()
            } else {
                try await tournamentStore.load()
            }
            let response = try await api.userGroups(userID: uid)
            placements = response.groups
            loadFailed = false
            isLoaded = true
        } catch {
            loadFailed = placements.isEmpty
            isLoaded = true
        }
        await loadNeedAction(forceDetails: forceDetails)
    }

    // MARK: derived state (pure pass-throughs to HomeDashboardLogic)

    func classified(now: Date = Date()) -> [HomeGroupItem] {
        HomeDashboardLogic.classify(placements, tournament: tournamentStore.byID, now: now)
    }

    func runningItems(now: Date = Date()) -> [HomeGroupItem] {
        HomeDashboardLogic.running(classified(now: now))
    }

    func endedItems(now: Date = Date()) -> [HomeGroupItem] {
        HomeDashboardLogic.ended(classified(now: now))
    }

    func visibleItems(now: Date = Date()) -> [HomeGroupItem] {
        selectedTab == .running ? runningItems(now: now) : endedItems(now: now)
    }

    func headline(now: Date = Date()) -> HomeHeadline {
        HomeDashboardLogic.headline(
            visibleCount: visibleItems(now: now).count,
            totalCount: placements.count,
            tab: selectedTab
        )
    }

    func nextKickoff(now: Date = Date()) -> HomeKickoff? {
        HomeDashboardLogic.nextKickoff(across: runningItems(now: now), now: now)
    }

    func cards(grouped: Bool, now: Date = Date()) -> [HomeCard] {
        HomeDashboardLogic.cards(visible: visibleItems(now: now), grouped: grouped)
    }

    func needActionDisplay(now: Date = Date(), calendar: Calendar = .current) -> HomeNeedActionDisplay {
        HomeDashboardLogic.needActionDisplay(
            sources: needActionSources,
            userID: userStore.id,
            now: now,
            calendar: calendar
        )
    }

    // MARK: private

    /// Need-action inputs cover only groups whose tournament is genuinely running —
    /// ended tournaments 404 on the detail route and have no bettable games anyway.
    /// A group whose bet matrix fails to load is excluded entirely (a missing matrix
    /// would otherwise mark every game falsely un-bet).
    private func loadNeedAction(forceDetails: Bool) async {
        let actionable = classified().filter { !$0.ended }

        var gamesByTournament: [Int: [Game]] = [:]
        for tournamentID in Set(actionable.compactMap { $0.tournament?.id }) {
            if let detail = try? await tournamentStore.loadDetails(id: tournamentID, force: forceDetails) {
                gamesByTournament[tournamentID] = detail.games ?? []
            }
        }

        var sources: [HomeNeedActionSource] = []
        for item in actionable {
            guard let tournamentID = item.tournament?.id,
                  let games = gamesByTournament[tournamentID], !games.isEmpty,
                  let bets = try? await api.bets(groupID: item.id) else { continue }
            sources.append(HomeNeedActionSource(
                groupID: item.id,
                groupName: item.placement.name,
                games: games,
                bets: bets
            ))
        }
        needActionSources = sources
    }
}
