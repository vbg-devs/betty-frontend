import SwiftUI

/// Web `UserHistory`: one row per game — the member's bet if placed, else a "NO BET"
/// skipped row for games that have already started. Sorted by kickoff, scores hidden
/// pre-kickoff unless sneak peek, header counts only actual bets ("<N> BETS · <Σ> PTS").
struct UserHistorySheet: View {
    let groupID: Int
    let userID: String

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    private var group: Group? { env.groupStore.byID(groupID) }
    private var member: Member? { group?.member(withUserID: userID) }
    private var peek: Bool { group?.allowSneakPeek ?? false }

    private var games: [Game] {
        guard let group else { return [] }
        return env.tournamentStore.detailsByID(group.tournamentID)?.games ?? []
    }

    private var entries: [GroupUserHistoryEntry] {
        GroupUserHistoryLogic.entries(bets: env.betStore.bets, userID: userID, games: games)
    }

    var body: some View {
        // Web `.modal__inner` sits on the surface token, not the page background.
        ZStack(alignment: .topTrailing) {
            theme.colors.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        if entries.isEmpty {
                            Text("★ NO BETS YET")
                                .kicker(theme.colors.textMuted)
                                .padding(.vertical, Space.xl)
                                .frame(maxWidth: .infinity)
                        }
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            UserHistoryBetRow(
                                entry: entry,
                                peek: peek,
                                isMine: entry.bet.map { env.userStore.id == $0.userID } ?? false,
                                exactResultPoints: group?.exactResultPoints
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("groupDetail.userHistory.row.\(index)")
                            if entry.id != entries.last?.id {
                                Divider().overlay(theme.colors.overlay06)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, Space.l)
                }
            }
            closeButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groupDetail.userHistory.root")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            guard let group else { return }
            if env.betStore.loadedGroupID != groupID {
                try? await env.betStore.load(groupID: groupID)
            }
            _ = try? await env.tournamentStore.loadDetails(id: group.tournamentID)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.textSecondary)
                .padding(Space.s)
        }
        .padding(.top, Space.s)
        .padding(.trailing, Space.xs)
        .accessibilityLabel("Close")
    }

    private var header: some View {
        HStack(spacing: Space.m) {
            if let member {
                AvatarView(member: member, size: .medium)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("★ BET HISTORY").kicker(Palette.orange)
                Text((member?.displayName ?? "").uppercased())
                    .font(.bettyTitle2)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: Space.xs) {
                    Text("\(GroupUserHistoryLogic.betsCount(entries)) BETS")
                        .kicker(theme.colors.textSecondary)
                    Text("·").foregroundStyle(theme.colors.textMuted)
                    Text("\(GroupUserHistoryLogic.totalPoints(entries)) PTS")
                        .kicker(theme.colors.accentPositive)
                }
            }
            Spacer()
        }
        .padding([.top, .horizontal], Space.xl)
        .padding(.bottom, Space.l)
    }
}

/// Web `UserBetListItem`: team flags, the bet's score (hidden pre-kickoff unless peek —
/// but you always see your own), and a points chip once processed; result coloring uses
/// the group's exact points (legacy 3-or-4 heuristic when unknown). A `nil` entry.bet
/// renders a muted "NO BET" skipped row for games the member sat out.
struct UserHistoryBetRow: View {
    let entry: GroupUserHistoryEntry
    let peek: Bool
    let isMine: Bool
    let exactResultPoints: Int?

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    private var showScore: Bool {
        guard let bet = entry.bet else { return false }
        return GroupBetRowLogic.showScore(bet: bet, gameStart: entry.game.startDate, peek: peek)
    }

    private var result: GroupBetRowLogic.Result {
        guard let bet = entry.bet else { return .pending }
        return GroupBetRowLogic.result(bet: bet, showScore: showScore, exactResultPoints: exactResultPoints)
    }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                TeamLogoView(team: env.teamStore.byID(entry.game.homeTeamID), size: 28)
                Text("–")
                    .font(.betty(14, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
                TeamLogoView(team: env.teamStore.byID(entry.game.awayTeamID), size: 28)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let bet = entry.bet {
                    if showScore || isMine {
                        Text("\(bet.homeTeamScore)")
                        Text("–")
                            .font(.betty(14, .regular))
                            .foregroundStyle(theme.colors.textSecondary)
                        Text("\(bet.awayTeamScore)")
                    } else {
                        HiddenScoreView()
                    }
                } else {
                    Text("NO BET").kicker(theme.colors.textSecondary)
                }
            }
            .font(.betty(18, .black))
            .monospacedDigit()
            .foregroundStyle(theme.colors.textPrimary)
            .frame(maxWidth: .infinity)

            pointsColumn
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .opacity(entry.bet == nil ? 0.55 : 1)
    }

    @ViewBuilder
    private var pointsColumn: some View {
        // Points stay pending until visible AND processed (your own pre-kickoff bet shows
        // its score but no points — isMine does not unlock points; web pin).
        if entry.bet == nil {
            Text("—")
                .font(.betty(18, .heavy))
                .foregroundStyle(theme.colors.textSecondary)
        } else if showScore, let bet = entry.bet, bet.isProcessed {
            let points = bet.userPoints ?? 0
            Text(points > 0 ? "+\(points)P" : "0P")
                .font(.bettyKicker)
                .kerning(0.8)
                .monospacedDigit()
                .foregroundStyle(chipColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(chipColor.opacity(0.15), in: RoundedRectangle(cornerRadius: Radius.sharp))
        } else {
            Text("·")
                .font(.betty(18, .heavy))
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var chipColor: Color {
        switch result {
        case .exact: theme.colors.accentPositive
        case .win: Palette.yellow
        case .miss: Palette.orange
        case .pending: theme.colors.textSecondary
        }
    }
}
