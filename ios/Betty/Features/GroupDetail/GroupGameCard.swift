import SwiftUI

/// Web `Game.vue` (default layout): info row (LIVE badge or date label + awarded points)
/// above two teams flanking the big score, optional placed-bet chip, urgency/bet-done
/// border, 45% dim when finished, optional bet-count chip overlay.
struct GroupGameCard: View {
    let game: Game
    let betted: Bool
    let placedHome: Int
    let placedAway: Int
    let awardedPoints: Int?
    /// True iff the user's own bet on this game is `boosted` AND scored > 0 (spec §2.5
    /// suppression). Set by the caller from `GroupGameCardLogic.awardedBoosted(...)`.
    var awardedBoosted: Bool = false
    /// nil hides the chip (web `showBets == false`).
    let betCount: Int?
    var onTap: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Space.s) {
                infoRow
                teamsRow
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sharp)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if let betCount {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(betCount)")
                            .font(.bettyKicker)
                            .kerning(0.6)
                    }
                    .foregroundStyle(theme.colors.textSecondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(theme.colors.overlay08, in: RoundedRectangle(cornerRadius: Radius.sharp))
                    .padding(10)
                }
            }
            .opacity(game.isFinished ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("groupDetail.games.card.\(game.id)")
    }

    private var borderColor: Color {
        switch GroupGameCardLogic.border(game: game, betted: betted) {
        case .urgent: Palette.orange
        case .betDone: theme.colors.accentPositive
        case .none: .clear
        }
    }

    private var infoRow: some View {
        HStack {
            if game.isLive() {
                LiveBadge()
            } else {
                Text(GroupGameDateLabel.text(for: game).uppercased())
                    .kicker(theme.colors.textMuted)
            }
            Spacer()
            if let awardedPoints {
                HStack(spacing: 4) {
                    Text("\(awardedPoints)P")
                        .kicker(awardedPoints > 0 ? theme.colors.accentPositive : theme.colors.textSecondary)
                    if awardedBoosted && awardedPoints > 0 {
                        // Post-eval rocket (spec §3.4, §2.5 — suppress on 0-point bets).
                        Text("🚀")
                            .font(.betty(12, .regular))
                            .accessibilityLabel("Boosted")
                    }
                }
            }
        }
    }

    private var teamsRow: some View {
        HStack(alignment: .top, spacing: Space.xs) {
            teamColumn(env.teamStore.byID(game.homeTeamID))
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    scoreLabel(game.homeTeamScore)
                    Text("-")
                        .font(.betty(18, .regular))
                        .foregroundStyle(theme.colors.textSecondary)
                    scoreLabel(game.awayTeamScore)
                }
                if betted {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(placedHome)")
                        Text("-")
                        Text("\(placedAway)")
                    }
                    .font(.bettyKicker)
                    .kerning(0.4)
                    .monospacedDigit()
                    .foregroundStyle(Palette.orange)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Palette.orangeTint15, in: RoundedRectangle(cornerRadius: Radius.sharp))
                    .accessibilityLabel("Your bet \(placedHome) to \(placedAway)")
                }
            }
            .padding(.top, Space.m)
            teamColumn(env.teamStore.byID(game.awayTeamID))
        }
    }

    private func teamColumn(_ team: Team?) -> some View {
        VStack(spacing: 8) {
            TeamLogoView(team: team, size: 56)
            Text((team?.name ?? "").uppercased())
                .font(.betty(12, .heavy))
                .kerning(0.6)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreLabel(_ score: Int?) -> some View {
        Text(score.map(String.init) ?? "")
            .font(.bettyScore)
            .foregroundStyle(theme.colors.textPrimary)
    }
}
