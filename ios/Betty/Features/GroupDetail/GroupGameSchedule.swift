import SwiftUI

/// Web `Pools.vue`: the full schedule — games flattened across pools, sorted by kickoff,
/// grouped by calendar day with pool-name headers, the next-upcoming day marked with an
/// orange dot (and used as the parent's scroll anchor via `dayAnchorID`).
struct GroupGameSchedule: View {
    let pools: [PoolGames]
    let bets: [Bet]
    let showBets: Bool
    var onGameTap: (Game) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    static func dayAnchorID(_ key: String) -> String { "group-schedule-day-\(key)" }

    private var dayGroups: [GroupGameDayGroup] {
        GroupGameDaySchedule.build(pools: pools)
    }

    var body: some View {
        let userID = env.userStore.id
        LazyVStack(alignment: .leading, spacing: Space.xl) {
            ForEach(dayGroups) { group in
                VStack(alignment: .leading, spacing: 14) {
                    Text(((group.isNextUpcoming ? "● " : "") + group.headerText).uppercased())
                        .kicker(Palette.orange)
                    VStack(spacing: 14) {
                        ForEach(group.games) { entry in
                            let ownBet = BetOwnership.firstOwnBet(in: bets, gameID: entry.game.id, userID: userID)
                            GroupGameCard(
                                game: entry.game,
                                betted: ownBet != nil,
                                placedHome: ownBet?.homeTeamScore ?? 0,
                                placedAway: ownBet?.awayTeamScore ?? 0,
                                awardedPoints: GroupGameCardLogic.awardedPoints(
                                    game: entry.game,
                                    bets: bets,
                                    userID: userID
                                ),
                                awardedBoosted: GroupGameCardLogic.awardedBoosted(
                                    game: entry.game,
                                    bets: bets,
                                    userID: userID
                                ),
                                placedBoosted: ownBet?.boosted ?? false,
                                betCount: showBets ? BetOwnership.betCount(in: bets, gameID: entry.game.id) : nil,
                                onTap: { onGameTap(entry.game) }
                            )
                        }
                    }
                }
                .id(Self.dayAnchorID(group.key))
            }
        }
    }
}
