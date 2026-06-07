import SwiftUI

// Web `ActivityFeed` row variants — kicker label + accent + per-type body
// (`GameBetListItem`, `GameMessageListItem`, `GroupVisibilityChangedListItem`, …).

nonisolated enum ActivityAccent: Equatable, Sendable {
    case orange, yellow, green, cream
}

nonisolated struct ActivityEventMeta: Equatable, Sendable {
    let label: String
    let accent: ActivityAccent
    let symbol: String?

    /// Web TYPE_META table; unknown types fall back to the uppercased raw type,
    /// cream accent, no icon.
    static func meta(for event: BettyEvent) -> ActivityEventMeta {
        switch event {
        case .betPlaced:
            ActivityEventMeta(label: "● NEW BET", accent: .orange, symbol: "person.crop.circle.badge.checkmark")
        case .betUpdated:
            ActivityEventMeta(label: "● BET UPDATED", accent: .orange, symbol: "person.crop.circle.badge.checkmark")
        case .gameStartingSoon:
            ActivityEventMeta(label: "● KICKING OFF", accent: .yellow, symbol: "clock")
        case .evaluateGame:
            ActivityEventMeta(label: "★ FULL TIME", accent: .cream, symbol: "flag.checkered")
        case .userExactScore:
            ActivityEventMeta(label: "★ EXACT SCORE", accent: .green, symbol: "star")
        case .groupJoined:
            ActivityEventMeta(label: "● JOINED GROUP", accent: .green, symbol: "person.crop.circle.badge.checkmark")
        case .groupLeft:
            ActivityEventMeta(label: "● LEFT GROUP", accent: .cream, symbol: "person.crop.circle.badge.xmark")
        case .groupCreated:
            ActivityEventMeta(label: "★ NEW GROUP", accent: .orange, symbol: "person.2")
        case .groupVisibilityChanged:
            ActivityEventMeta(label: "● VISIBILITY", accent: .yellow, symbol: "eye")
        case .userRegister:
            ActivityEventMeta(label: "★ WELCOME", accent: .green, symbol: "person.crop.circle.badge.plus")
        default:
            ActivityEventMeta(label: event.typeName.uppercased(), accent: .cream, symbol: nil)
        }
    }
}

nonisolated enum ActivityFeedText {
    static func exactScore(userIDs: [String], currentUserID: String?) -> String {
        let count = userIDs.count
        if let currentUserID, userIDs.contains(currentUserID) {
            return "You and \(count - 1) other(s) had the exact score"
        }
        return "\(count) players had the exact score!"
    }

    /// Empty/missing `who` falls back to "Someone" (web `||` semantics).
    static func joinedWho(_ who: String?) -> String {
        guard let who, !who.isEmpty else { return "Someone" }
        return who
    }

    /// "A group" unless the id resolves to a non-empty cached group name.
    static func visibilityGroupName(groupID: Int?, name: (Int) -> String?) -> String {
        guard let groupID, let resolved = name(groupID), !resolved.isEmpty else { return "A group" }
        return resolved
    }

    static func visibilityState(publicAt: Date?) -> String {
        publicAt != nil ? "public" : "private"
    }
}

extension ActivityAccent {
    func color(_ colors: ThemeColors) -> Color {
        switch self {
        case .orange: Palette.orange
        case .yellow: Palette.yellow
        case .green: colors.accentPositive
        case .cream: colors.textSecondary
        }
    }
}

/// One activity-feed entry: accent bar, icon circle, kicker, per-type body.
struct ActivityEventRow: View {
    let event: BettyEvent

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        let meta = ActivityEventMeta.meta(for: event)
        let accent = meta.accent.color(theme.colors)
        BettyInsetPanel(accent: accent, padding: Space.s) {
            HStack(alignment: .top, spacing: Space.s) {
                ZStack {
                    Circle().fill(theme.colors.overlay06)
                    if let symbol = meta.symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(meta.label)
                        .font(.bettyMicro)
                        .kerning(1.4)
                        .foregroundStyle(accent)
                        .accessibilityIdentifier("chat.activity.row.\(event.typeName).kicker")
                    eventBody
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.activity.row.\(event.typeName)")
    }

    @ViewBuilder
    private var eventBody: some View {
        switch event {
        case .betPlaced(let bet):
            FeedBetItem(gameID: bet.gameID, update: false)
        case .betUpdated(let bet):
            FeedBetItem(gameID: bet.gameID, update: true)
        case .gameStartingSoon(let payload):
            FeedKickoffItem(games: payload.games)
        case .evaluateGame(let payload):
            FeedResultItem(gameID: payload.gameID)
        case .userExactScore(let payload):
            FeedExactScoreItem(payload: payload)
        case .groupJoined(let payload):
            FeedGroupJoinedItem(data: payload)
        case .groupVisibilityChanged(let payload):
            FeedVisibilityItem(data: payload)
        case .userRegister(let profile):
            FeedWelcomeItem(name: profile.name)
        case .groupLeft:
            FeedPlainText("Someone just left a group")
        case .groupCreated:
            FeedPlainText("New group on Betty")
        default:
            FeedPlainText(event.typeName)
        }
    }
}

private struct FeedPlainText: View {
    let text: String

    @Environment(ThemeStore.self) private var theme

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.betty(13, .medium))
            .foregroundStyle(theme.colors.textPrimary)
    }
}

/// `bet_placed` / `bet_updated` — renders nothing until the game is cached; loads it
/// lazily, never re-fetching (web `GameBetListItem`).
struct FeedBetItem: View {
    let gameID: Int
    var update = false

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        // The fallback branch must render a real node: `.task` on a view that renders
        // nothing never fires, so the lazy load would deadlock on "not cached yet".
        SwiftUI.Group {
            if let game = env.gameStore.byID(gameID) {
                HStack(spacing: Space.xxs) {
                    Text(update ? "Someone updated their bet on" : "Someone placed a bet on")
                        .font(.betty(13, .medium))
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer(minLength: Space.xxs)
                    FeedTeamLogos(homeTeamID: game.homeTeamID, awayTeamID: game.awayTeamID)
                }
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .task(id: gameID) {
            guard gameID != 0, env.gameStore.byID(gameID) == nil else { return }
            _ = try? await env.gameStore.load(id: gameID)
        }
    }
}

/// `game_starting_soon` — uses the FIRST entry of the capital-G `Games` payload
/// (web `GameStartSoonListItem`); skips entirely when empty.
struct FeedKickoffItem: View {
    let games: [WSGameRef]

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    private var gameID: Int? { games.first?.id }

    var body: some View {
        // See FeedBetItem: the empty branch must render a node or `.task` never fires.
        SwiftUI.Group {
            if let gameID, let game = env.gameStore.byID(gameID) {
                HStack(spacing: Space.xxs) {
                    Text("Match is about to start")
                        .font(.betty(13, .medium))
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer(minLength: Space.xxs)
                    FeedTeamLogos(homeTeamID: game.homeTeamID, awayTeamID: game.awayTeamID)
                }
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .task(id: gameID) {
            guard let gameID, gameID != 0, env.gameStore.byID(gameID) == nil else { return }
            _ = try? await env.gameStore.load(id: gameID)
        }
    }
}

/// `evaluate_game` — "Game evaluated" + the GAME's final score from the cache, blanks
/// when scores are null (web `GameMessageListItem`).
struct FeedResultItem: View {
    let gameID: Int

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        // See FeedBetItem: the empty branch must render a node or `.task` never fires.
        SwiftUI.Group {
            if let game = env.gameStore.byID(gameID) {
                HStack(spacing: Space.xxs) {
                    Text("Game evaluated")
                        .font(.betty(13, .medium))
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer(minLength: Space.xxs)
                    FeedTeamLogo(teamID: game.homeTeamID)
                    Text("\(score(game.homeTeamScore)) - \(score(game.awayTeamScore))")
                        .font(.betty(13, .heavy))
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textPrimary)
                    FeedTeamLogo(teamID: game.awayTeamID)
                }
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .task(id: gameID) {
            guard gameID != 0, env.gameStore.byID(gameID) == nil else { return }
            _ = try? await env.gameStore.load(id: gameID)
        }
    }

    private func score(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }
}

/// `group_joined` — "{who|Someone} just joined {group name}".
struct FeedGroupJoinedItem: View {
    let data: WSGroupJoined

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        (Text(ActivityFeedText.joinedWho(data.who)).font(.betty(13, .heavy))
            + Text(" just joined ").font(.betty(13, .medium))
            + Text(data.group?.name ?? "").font(.betty(13, .heavy)))
            .foregroundStyle(theme.colors.textPrimary)
    }
}

/// `group_visibility_changed` — group name from the (reactive) group store, falling
/// back to "A group".
struct FeedVisibilityItem: View {
    let data: WSVisibilityChanged

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        let name = ActivityFeedText.visibilityGroupName(groupID: data.groupID) { env.groupStore.byID($0)?.name }
        return (Text(name).font(.betty(13, .heavy))
            + Text(" is now ").font(.betty(13, .medium))
            + Text(ActivityFeedText.visibilityState(publicAt: data.publicAt)).font(.betty(13, .heavy)))
            .foregroundStyle(theme.colors.textPrimary)
    }
}

/// `user_exact_score` — "You and N other(s)…" when the signed-in user is among them.
struct FeedExactScoreItem: View {
    let payload: WSExactScore

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Text(ActivityFeedText.exactScore(userIDs: payload.userIDs, currentUserID: env.userStore.id))
            .font(.betty(13, .medium))
            .foregroundStyle(theme.colors.textPrimary)
    }
}

/// `user_register` — "{name} just joined Betty".
struct FeedWelcomeItem: View {
    let name: String

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        (Text(name).font(.betty(13, .heavy))
            + Text(" just joined Betty").font(.betty(13, .medium)))
            .foregroundStyle(theme.colors.textPrimary)
    }
}

private struct FeedTeamLogos: View {
    let homeTeamID: Int
    let awayTeamID: Int

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        HStack(spacing: Space.xxs) {
            FeedTeamLogo(teamID: homeTeamID)
            Text("-")
                .font(.betty(13, .medium))
                .foregroundStyle(theme.colors.textSecondary)
            FeedTeamLogo(teamID: awayTeamID)
        }
    }
}

/// Tiny inline flag — rendered only when the team is cached (web parity: text shows
/// even with zero logos).
private struct FeedTeamLogo: View {
    let teamID: Int

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        if let team = env.teamStore.byID(teamID) {
            TeamLogoView(team: team, size: 18)
        }
    }
}
