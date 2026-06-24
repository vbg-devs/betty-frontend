import SwiftUI

/// Web `/leaderboard` + `/leaderboard/[id]` + `GlobalLeaderboard`/`Leaderboard` (global
/// mode), collapsed into one screen: hero with the split tournament title, scoring
/// notice, tournament picker (ended → "· ENDED"), player count, and the dense-ranked
/// standings with the YOU highlight.
///
/// Rendered by the `GlobalLeaderboardView` tab root (Features/Leaderboard).
struct GlobalLeaderboardScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var selectedTournamentID: Int?
    @State private var members: [Member] = []
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var hasSettled = false
    @State private var loadGeneration = 0

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.cardGap) {
                    heroCard
                    standingsSection
                }
                .padding(Space.m)
            }
            .refreshable { await reload() }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if env.tournamentStore.tournaments.isEmpty {
                try? await env.tournamentStore.load()
            }
            if selectedTournamentID == nil {
                // Setting the selection triggers the onChange reload.
                selectedTournamentID = env.router.leaderboardTournamentID
                    ?? env.tournamentStore.defaultLeaderboardTournament?.id
            } else if !hasSettled {
                await reload()
            }
        }
        .onChange(of: selectedTournamentID) {
            Task { await reload() }
        }
        .onChange(of: env.router.leaderboardTournamentID) { _, newValue in
            if let newValue { selectedTournamentID = newValue }
        }
    }

    private var selectedTournament: Tournament? {
        selectedTournamentID.flatMap { env.tournamentStore.byID($0) }
    }

    // MARK: - Hero

    private var heroCard: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.m) {
                BettyInsetPanel(accent: Palette.yellow) {
                    noticeText
                }
                Text("★ GLOBAL LEADERBOARD")
                    .kicker(Palette.orange)
                titleBlock
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("★ SWITCH TOURNAMENT")
                        .kicker(theme.colors.textSecondary)
                    tournamentPicker
                    Text("Every bet counts. Top players earn bragging rights across every group on Betty.")
                        .font(.bettySubhead)
                        .foregroundStyle(theme.colors.textSecondary)
                    if hasSettled {
                        playerStat
                    }
                }
            }
        }
    }

    private var noticeText: some View {
        (Text("Normalized score: ")
            + Text("1p").bold().foregroundStyle(theme.colors.accentPositive)
            + Text(" for a correct winner, ")
            + Text("3p").bold().foregroundStyle(Palette.orange)
            + Text(" for an exact score. Result may differ from your groups."))
            .font(.bettySubhead)
            .foregroundStyle(theme.colors.textSecondary)
    }

    private var titleBlock: some View {
        let parts = GlobalLeaderboardLogic.titleParts(selectedTournament?.name)
        return VStack(alignment: .leading, spacing: 0) {
            Text(parts.0)
                .font(.bettyDisplayL)
                .displayKerning(40)
                .foregroundStyle(theme.colors.accentPositive)
            if !parts.1.isEmpty {
                Text(parts.1)
                    .font(.bettyDisplayL)
                    .displayKerning(40)
                    .foregroundStyle(Palette.orange)
            }
        }
    }

    private var tournamentPicker: some View {
        Picker("Tournament", selection: $selectedTournamentID) {
            ForEach(env.tournamentStore.tournaments) { tournament in
                Text(GlobalLeaderboardLogic.pickerLabel(for: tournament))
                    .tag(Int?.some(tournament.id))
            }
        }
        .pickerStyle(.menu)
        .tint(theme.colors.textPrimary)
        .accessibilityIdentifier("leaderboard.global.tournamentPicker")
    }

    private var playerStat: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text("\(members.count)")
                .font(.betty(48, .black))
                .monospacedDigit()
                .displayKerning(48)
                .foregroundStyle(theme.colors.textPrimary)
                .accessibilityIdentifier("leaderboard.global.playerCount")
            Text("PLAYERS · CHASING")
                .kicker(theme.colors.textSecondary)
        }
        .padding(.top, Space.xxs)
    }

    // MARK: - Standings

    private var standingsSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("● STANDINGS")
                .kicker(Palette.orange)
            Text("WHO'S BETTING IT RIGHT.")
                .font(.bettyTitle1)
                .displayKerning(32)
                .foregroundStyle(theme.colors.textPrimary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xl)
            } else if loadFailed {
                VStack(spacing: Space.s) {
                    Text("Could not load the leaderboard.")
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textSecondary)
                    Button("RETRY") {
                        Task { await reload() }
                    }
                    .buttonStyle(.bettyOutline)
                    .accessibilityIdentifier("leaderboard.global.retry")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.l)
            } else if members.isEmpty && hasSettled {
                Text("No players on the board yet.")
                    .font(.bettyBody)
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.l)
                    .accessibilityIdentifier("leaderboard.global.empty")
            } else {
                VStack(spacing: 2) {
                    ForEach(DenseRanking.rank(members, score: { $0.normalizedScore })) { ranked in
                        row(ranked)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
            }
        }
    }

    private func row(_ ranked: DenseRanking.Ranked<Member>) -> some View {
        let isYou = ranked.item.userID == env.userStore.id
        return HStack(spacing: Space.s) {
            Text(String(format: "%02d", ranked.place))
                .font(.bettyTitle3)
                .monospacedDigit()
                .foregroundStyle(placeColor(ranked.place))
            // Global rows ignore nickname (always null on this wire payload anyway).
            AvatarView(name: ranked.item.name, nickname: nil, imageURL: ranked.item.imageURL, size: .regular)
            Text(ranked.item.name ?? "")
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
            if isYou {
                YouBadge()
            }
            Spacer(minLength: Space.xs)
            Text(GlobalLeaderboardLogic.scoreText(ranked.item.normalizedScore))
                .font(.bettyScoreRow)
                .foregroundStyle(ranked.place == 1 ? theme.colors.accentPositive : theme.colors.textPrimary)
            Text("P")
                .kicker(theme.colors.textSecondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, Space.m)
        .background(isYou ? Palette.orangeTint12 : theme.colors.surface)
        .overlay(alignment: .leading) {
            if isYou {
                Rectangle().fill(Palette.orange).frame(width: 3)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("leaderboard.global.row.\(ranked.item.userID)")
    }

    private func placeColor(_ place: Int) -> Color {
        switch place {
        case 1: Palette.orange
        case 2: Palette.yellow
        default: theme.colors.textSecondary
        }
    }

    // MARK: - Loading

    private func reload() async {
        guard let id = selectedTournamentID else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        loadFailed = false
        do {
            let rows = try await env.tournamentStore.leaderboard(id: id, limit: 100)
            guard generation == loadGeneration else { return }
            members = rows
        } catch {
            guard generation == loadGeneration else { return }
            members = []
            loadFailed = true
        }
        isLoading = false
        hasSettled = true
    }
}
