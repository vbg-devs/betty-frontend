import SwiftUI

/// Web `NeedAction` aggregated across the user's running groups: a yellow warning
/// banner with up to 3 un-bet games starting within 24h, else today's games, else
/// nothing. Rows open the bet sheet in the surfaced group.
struct HomeNeedActionSection: View {
    var viewModel: HomeViewModel

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        switch viewModel.needActionDisplay() {
        case .urgent(let entries):
            panel(
                accent: Palette.yellow,
                header: "Make sure to bet on these games before it's too late!",
                headerColor: Palette.yellow,
                entries: entries
            )
        case .today(let entries):
            panel(
                accent: theme.colors.overlay10,
                header: "Todays games",
                headerColor: theme.colors.textMuted,
                entries: entries
            )
        case .hidden:
            EmptyView()
        }
    }

    private func panel(
        accent: Color,
        header: String,
        headerColor: Color,
        entries: [HomeNeedActionEntry]
    ) -> some View {
        BettyInsetPanel(accent: accent) {
            VStack(alignment: .leading, spacing: Space.s) {
                (
                    Text("★ ").foregroundStyle(Palette.orange)
                        + Text(header).foregroundStyle(headerColor)
                )
                .font(.bettyKicker)
                .kerning(1.6)
                .textCase(.uppercase)
                .accessibilityIdentifier("home.needAction.header")
                ForEach(entries) { entry in
                    HomeGameRow(entry: entry)
                }
            }
        }
    }
}

/// Compact game row: team logos + names, kickoff time, and a trailing status
/// (score / LIVE / your bet / time-left nudge). Tapping opens the bet sheet.
private struct HomeGameRow: View {
    let entry: HomeNeedActionEntry

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Button {
            env.router.activeSheet = .bet(gameID: entry.game.id, groupID: entry.groupID)
        } label: {
            HStack(spacing: Space.s) {
                HStack(spacing: -6) {
                    TeamLogoView(team: env.teamStore.byID(entry.game.homeTeamID), size: 32)
                    TeamLogoView(team: env.teamStore.byID(entry.game.awayTeamID), size: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(matchupTitle)
                        .font(.bettySubhead)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                    Text(entry.game.startDate.formatted(date: .abbreviated, time: .shortened))
                        .kicker(theme.colors.textMuted)
                }
                Spacer(minLength: Space.xs)
                trailing
            }
            .padding(.vertical, Space.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.needAction.row.\(entry.game.id)")
    }

    private var matchupTitle: String {
        let home = env.teamStore.byID(entry.game.homeTeamID)?.name ?? "TBD"
        let away = env.teamStore.byID(entry.game.awayTeamID)?.name ?? "TBD"
        return "\(home) – \(away)"
    }

    @ViewBuilder
    private var trailing: some View {
        let game = entry.game
        if game.isFinished, let home = game.homeTeamScore, let away = game.awayTeamScore {
            Text("\(home) – \(away)")
                .font(.betty(17, .black).monospacedDigit())
                .foregroundStyle(theme.colors.textSecondary)
        } else if game.isLive() {
            LiveBadge()
        } else if let bet = entry.ownBet {
            Text("YOUR BET \(bet.homeTeamScore)–\(bet.awayTeamScore)")
                .font(.bettyKicker)
                .kerning(1.2)
                .foregroundStyle(Palette.orange)
                .padding(.vertical, 3)
                .padding(.horizontal, Space.xs)
                .background(Palette.orangeTint15, in: RoundedRectangle(cornerRadius: Radius.sharp))
        } else {
            Text(timeLeftLabel)
                .kicker(Palette.orange)
        }
    }

    private var timeLeftLabel: String {
        let hoursLeft = GameClock.fractionalHoursUntilStart(of: entry.game)
        if hoursLeft <= 0 { return "STARTED" }
        if hoursLeft < 1 { return "IN \(max(1, Int(hoursLeft * 60))) MIN" }
        return "IN \(Int(hoursLeft))H"
    }
}
