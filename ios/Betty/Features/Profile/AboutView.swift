import SwiftUI

/// Web `/about` rendered natively: hero, WHAT/WHO cards, the three steps, and the tips.
struct AboutView: View {
    @Environment(ThemeStore.self) private var theme

    private var bodyFont: Font { .betty(15, .medium) }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.cardGap) {
                    hero
                    whatCard
                    whoCard
                    howSection
                    tipsCard
                }
                .padding(Space.m)
            }
        }
        .navigationTitle("About")
    }

    private var hero: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("★ ABOUT BETTY")
                    .kicker(Palette.orange)
                VStack(alignment: .leading, spacing: 0) {
                    Text("HI, I'M")
                        .font(.bettyDisplayXL)
                        .displayKerning(64)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("BETTY.")
                        .font(.bettyDisplayXL)
                        .displayKerning(64)
                        .foregroundStyle(theme.colors.accentPositive)
                }
                mascot
                Text("I run the bets, count the points, and keep the receipts for tournament predictions between you and your friends. Pick a cup, gather your crew, and let the leaderboard sort out who actually knows their football.")
                    .font(bodyFont)
                    .foregroundStyle(theme.colors.textBody)
            }
        }
    }

    private var mascot: some View {
        Image("BettyMascot")
            .resizable()
            .scaledToFill()
            .frame(width: 180, height: 180)
            .background(Palette.surfaceWhite)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(theme.colors.overlay10, lineWidth: 6)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("★ HI, I'M BETTY")
                    .kicker(.white)
                    .padding(.vertical, Space.xs)
                    .padding(.horizontal, Space.s)
                    .background(Palette.orange, in: RoundedRectangle(cornerRadius: Radius.sharp))
                    .rotationEffect(.degrees(-3))
                    .offset(x: Space.xs, y: -Space.xs)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s)
    }

    private var whatCard: some View {
        BettyInsetPanel(accent: Palette.orange, padding: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("★ WHAT")
                    .kicker(Palette.orange)
                Text("A SOCIAL PREDICTIONS GAME.")
                    .font(.bettyTitle2)
                    .displayKerning(28)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("Betty is a free game for tournament predictions. Each group sets its own house rules, everyone bets on exact match results, and points roll in as games go final. No money, no spreadsheets — just bragging rights, settled in public.")
                    .font(bodyFont)
                    .foregroundStyle(theme.colors.textBody)
            }
        }
    }

    private var whoCard: some View {
        BettyInsetPanel(accent: theme.colors.accentPositive, padding: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("● WHO")
                    .kicker(theme.colors.accentPositive)
                Text("YOUR SCOREKEEPER.")
                    .font(.bettyTitle2)
                    .displayKerning(28)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("Betty was born in Varberg in 2021, out of one too many half-broken Excel sheets and a group chat that wouldn't stop arguing about whether Anna's bet \"really counted.\" She's the bookkeeper, the timekeeper, and the receipts. She handles the math. You handle the banter.")
                    .font(bodyFont)
                    .foregroundStyle(theme.colors.textBody)
            }
        }
    }

    private var howSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("★ HOW IT WORKS")
                .kicker(Palette.orange)
            Text("THREE STEPS. NO FINE PRINT.")
                .font(.bettyTitle1)
                .displayKerning(32)
                .foregroundStyle(theme.colors.textPrimary)
            stepCard(
                kicker: "★ SET",
                kickerColor: Palette.orange,
                number: "01",
                title: "Make a group",
                copy: "Pick a tournament, set your points-per-correct, share one invite link. Thirty seconds, tops."
            )
            stepCard(
                kicker: "● BET",
                kickerColor: theme.colors.accentPositive,
                number: "02",
                title: "Lock the bets",
                copy: "Predict exact scores for every match. Bets close at kickoff — no refunds, no edits, no excuses."
            )
            stepCard(
                kicker: "★ WIN",
                kickerColor: Palette.yellow,
                number: "03",
                title: "Climb the board",
                copy: "Live standings, group chat, a podium for the winner — and a permanent record once the tournament wraps."
            )
        }
    }

    private func stepCard(kicker: String, kickerColor: Color, number: String, title: String, copy: String) -> some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(kicker)
                    .kicker(kickerColor)
                Text(number)
                    .font(.bettyScoreXL)
                    .displayKerning(56)
                    .foregroundStyle(theme.colors.textMuted)
                Text(title)
                    .font(.bettyTitle3)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(copy)
                    .font(bodyFont)
                    .foregroundStyle(theme.colors.textBody)
            }
        }
    }

    private var tipsCard: some View {
        BettyInsetPanel(accent: Palette.yellow, padding: Space.l) {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("★ TIPS")
                    .kicker(Palette.orange)
                Text("GETTING THE MOST OUT OF BETTY.")
                    .font(.bettyTitle2)
                    .displayKerning(28)
                    .foregroundStyle(theme.colors.textPrimary)
                ForEach(Self.tips, id: \.self) { tip in
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                        Text("★")
                            .kicker(Palette.orange)
                        Text(bettyMarkdown: tip)
                            .font(bodyFont)
                            .foregroundStyle(theme.colors.textBody)
                    }
                }
            }
        }
    }

    private static let tips = [
        "**Invite early.** Bets lock at kickoff, so the sooner the group is full, the more matches everyone gets to call.",
        "**Set points that match the vibe.** Bigger exact-score bonuses = more chaos and bigger comebacks. Lower bonuses = a slower, steadier race.",
        "**Use the group chat.** The smack-talk is half the point. Betty doesn't judge.",
        "**Check the global leaderboard.** Curious how you stack up beyond your own crew? It's right in the menu.",
    ]
}
