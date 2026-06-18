import SwiftUI

/// Web `Game.vue` (default layout): kicker info row (LIVE badge or kickoff label), two
/// teams flanking the big `H - A` score, optional own-bet chip with awarded points
/// underneath it. Finished games dim to 45%.
struct TournamentGameCard: View {
    var game: Game
    var bets: [Bet] = []
    var onTap: ((Game) -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    private var homeTeam: Team? { env.teamStore.byID(game.homeTeamID) }
    private var awayTeam: Team? { env.teamStore.byID(game.awayTeamID) }

    private var ownBet: Bet? {
        BetOwnership.firstOwnBet(in: bets, gameID: game.id, userID: env.userStore.id)
    }

    /// Only for finished games with an own bet whose points were assigned.
    private var awardedPoints: Int? {
        guard game.isFinished else { return nil }
        return ownBet?.userPoints
    }

    var body: some View {
        VStack(spacing: Space.s) {
            infoRow
            HStack(alignment: .center, spacing: Space.xs) {
                teamColumn(homeTeam)
                VStack(spacing: Space.xxs) {
                    scoreRow
                    if let bet = ownBet { betChip(bet) }
                    if let points = awardedPoints {
                        Text("\(points)P")
                            .font(.bettyKicker)
                            .kerning(1.4)
                            .foregroundStyle(points > 0 ? theme.colors.accentPositive : theme.colors.textSecondary)
                    }
                }
                teamColumn(awayTeam)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity)
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
        .opacity(game.isFinished ? 0.45 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onTap?(game) }
    }

    private var infoRow: some View {
        HStack {
            if game.isLive() {
                LiveBadge()
            } else {
                Text(TournamentSchedule.dateLabel(for: game))
                    .kicker(theme.colors.textMuted)
            }
            Spacer()
        }
    }

    private var scoreRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(scoreText(game.homeTeamScore))
                .font(.bettyScore)
                .displayKerning(28)
                .foregroundStyle(theme.colors.textPrimary)
            Text("-")
                .font(.betty(18))
                .foregroundStyle(theme.colors.textSecondary)
            Text(scoreText(game.awayTeamScore))
                .font(.bettyScore)
                .displayKerning(28)
                .foregroundStyle(theme.colors.textPrimary)
        }
    }

    private func betChip(_ bet: Bet) -> some View {
        Text("\(bet.homeTeamScore) - \(bet.awayTeamScore)")
            .font(.bettyKicker)
            .kerning(0.4)
            .foregroundStyle(Palette.orange)
            .padding(.vertical, 3)
            .padding(.horizontal, Space.xs)
            .background(Palette.orangeTint15, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private func teamColumn(_ team: Team?) -> some View {
        VStack(spacing: Space.xs) {
            TeamLogoView(team: team, size: 56)
            Text((team?.name ?? "").uppercased())
                .font(.bettyCaption)
                .kerning(0.6)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }

    /// Web renders blank strings for nil scores.
    private func scoreText(_ score: Int?) -> String {
        score.map(String.init) ?? " "
    }
}

/// Web `Pools.vue`: day-grouped schedule. Header kicker is orange, prefixed with "● "
/// on the next-upcoming day; each day's games render as `TournamentGameCard`s.
struct TournamentScheduleView: View {
    var pools: [PoolGames]
    var bets: [Bet] = []
    var onGameTap: ((Game) -> Void)?

    var body: some View {
        let days = TournamentSchedule.days(pools: pools)
        LazyVStack(alignment: .leading, spacing: Space.xl) {
            ForEach(days) { day in
                VStack(alignment: .leading, spacing: Space.s) {
                    Text((day.isNextUpcoming ? "● " : "") + day.headerText)
                        .kicker(Palette.orange)
                        .accessibilityIdentifier("tournaments.schedule.day.\(day.id)")
                    ForEach(day.entries) { entry in
                        TournamentGameCard(game: entry.game, bets: bets, onTap: onGameTap)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("tournaments.schedule.game.\(entry.game.id)")
                    }
                }
                .id(day.id)
            }
        }
    }
}
