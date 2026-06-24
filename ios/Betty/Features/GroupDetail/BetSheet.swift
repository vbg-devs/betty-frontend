import SwiftUI

/// Web `BetModal`: "Your bet" / "Placed bets" tabs, stepper score inputs prefilled from
/// the existing bet, the pinned universal-edit submit rule, kickoff lock (input tab
/// removed + placed bets forced), sneak-peek score hiding, and 423 "betting closed".
struct BetSheet: View {
    let gameID: Int
    let groupID: Int

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    enum Tab: Hashable { case yourBet, placed }

    @State private var homeScore = ""
    @State private var awayScore = ""
    @State private var placeInAllGroups = true // default ON (web pin)
    @State private var boosted = false
    @State private var selectedTab: Tab = .yourBet
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successCount = 0

    // MARK: - Derived

    private var group: Group? { env.groupStore.byID(groupID) }

    private var peek: Bool { group?.allowSneakPeek ?? false }

    private var game: Game? {
        if let group,
           let details = env.tournamentStore.detailsByID(group.tournamentID),
           let match = details.games?.first(where: { $0.id == gameID }) {
            return match
        }
        return env.gameStore.byID(gameID)
    }

    private var homeTeam: Team? { game.flatMap { env.teamStore.byID($0.homeTeamID) } }
    private var awayTeam: Team? { game.flatMap { env.teamStore.byID($0.awayTeamID) } }

    private var gameBets: [Bet] { env.betStore.betsForGame(gameID) }

    private var myBet: Bet? { env.betStore.myBet(gameID: gameID, userID: env.userStore.id) }

    private var lockInput: Bool {
        guard let game else { return false }
        return GroupBetLogic.lockInput(start: game.startDate)
    }

    private var showScores: Bool {
        guard let game else { return peek }
        return GroupBetLogic.showScores(start: game.startDate, peek: peek)
    }

    private var canSave: Bool {
        guard let game else { return false }
        return GroupBetLogic.canSave(start: game.startDate, home: homeScore, away: awayScore)
    }

    private var currentTab: Tab { lockInput ? .placed : selectedTab }

    // MARK: - Boosters

    /// Group has boosters turned on (`boost_count > 0`).
    private var boostersEnabled: Bool {
        (group?.boostCount ?? 0) > 0
    }

    private var boostMultiplier: Int {
        group?.boostMultiplier ?? 2
    }

    /// Spec §1.6: `remaining = max(0, boost_count - usage)` where `usage` counts the
    /// user's boosted bets in this group EXCLUDING the bet currently being edited
    /// (so toggling off-then-on doesn't drain capacity — matches `BetModal.vue:213-249`).
    private var boostersUsedExcludingCurrent: Int {
        guard let me = env.userStore.id else { return 0 }
        return env.betStore.bets.count { bet in
            bet.userID == me
                && bet.groupID == groupID
                && bet.boosted
                && bet.gameID != gameID
        }
    }

    private var remainingBoosters: Int {
        let cap = group?.boostCount ?? 0
        return max(0, cap - boostersUsedExcludingCurrent)
    }

    /// True iff this user's current bet for this game in this group is already boosted.
    /// Lets us keep the un-boost path open even when remaining=0.
    private var myBetIsBoosted: Bool {
        guard let me = env.userStore.id else { return false }
        return env.betStore.bets.contains {
            $0.userID == me && $0.groupID == groupID && $0.gameID == gameID && $0.boosted
        }
    }

    /// Disabled when boosters enabled AND remaining=0 AND bet isn't already boosted.
    /// (We never disable when myBetIsBoosted — un-boost must always be available.)
    private var boosterDisabled: Bool {
        guard boostersEnabled else { return false }
        if myBetIsBoosted { return false }
        return remainingBoosters <= 0
    }

    private var boosterHelpText: String {
        guard boostersEnabled else { return "" }
        let cap = group?.boostCount ?? 0
        if boosterDisabled { return "No boosters remaining in this group" }
        if boosted { return "This bet's points will be ×\(boostMultiplier)" }
        // Show "N of M remaining" when off (the toggle is on/off but no capacity used yet).
        let used = boostersUsedExcludingCurrent
        let left = max(0, cap - used)
        return "\(boostMultiplier)× multiplier — \(left) of \(cap) remaining"
    }

    var body: some View {
        // Web `.modal__inner` sits on the surface token, not the page background.
        ZStack(alignment: .topTrailing) {
            theme.colors.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                tabBar
                ScrollView {
                    switch currentTab {
                    case .yourBet: yourBetTab
                    case .placed: placedBetsTab
                    }
                }
                if currentTab == .yourBet {
                    footer
                }
            }
            closeButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groupDetail.betSheet.root")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: successCount)
        .task {
            if env.betStore.loadedGroupID != groupID {
                try? await env.betStore.load(groupID: groupID)
            }
            if game == nil, let group {
                _ = try? await env.tournamentStore.loadDetails(id: group.tournamentID)
            }
            if game == nil {
                _ = try? await env.gameStore.load(id: gameID)
            }
        }
        .onChange(of: myBet, initial: true) { _, bet in
            // Reactive prefill (web watches myBet): value-equality keeps polling
            // refreshes from clobbering in-progress edits.
            if let bet {
                homeScore = String(bet.homeTeamScore)
                awayScore = String(bet.awayTeamScore)
                boosted = bet.boosted
            }
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("★ PLACE YOUR BET").kicker(Palette.orange)
            (
                Text((homeTeam?.name ?? "").uppercased())
                + Text(" vs ").font(.betty(20, .regular)).foregroundStyle(theme.colors.textMuted)
                + Text((awayTeam?.name ?? "").uppercased())
            )
            .font(.bettyTitle1)
            .foregroundStyle(theme.colors.textPrimary)
            .minimumScaleFactor(0.6)
            .lineLimit(2)

            if let game {
                BetDistributionHeader(bets: gameBets, game: game, homeTeam: homeTeam, awayTeam: awayTeam)
                    .padding(.top, Space.xs)
            }
        }
        .padding([.top, .horizontal], Space.xl)
        .padding(.bottom, Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: Space.l) {
            // After kickoff the "Your bet" tab is REMOVED (web pin), not just disabled.
            if !lockInput {
                tabButton("YOUR BET", tab: .yourBet)
            }
            tabButton("PLACED BETS", tab: .placed)
            Spacer()
        }
        .padding(.horizontal, Space.xl)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.overlay06).frame(height: 1)
        }
    }

    private func tabButton(_ title: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.betty(12, .heavy))
                .kerning(1.6)
                .foregroundStyle(currentTab == tab ? theme.colors.textPrimary : theme.colors.textMuted)
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) {
                    if currentTab == tab {
                        Rectangle().fill(Palette.orange).frame(height: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab == .yourBet ? "groupDetail.betSheet.tab.yourBet" : "groupDetail.betSheet.tab.placed")
    }

    // MARK: - Your bet

    private var yourBetTab: some View {
        VStack(spacing: Space.l) {
            HStack(alignment: .bottom, spacing: 14) {
                scoreInput("HOME", id: "home", text: $homeScore)
                Text("–")
                    .font(.betty(36, .regular))
                    .foregroundStyle(theme.colors.textMuted)
                    .padding(.bottom, 18)
                scoreInput("AWAY", id: "away", text: $awayScore)
            }
            if boostersEnabled {
                boosterRow
            }
            if let errorMessage {
                BettyInsetPanel(accent: Palette.alertRed) {
                    Text(errorMessage)
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                .accessibilityIdentifier("groupDetail.betSheet.error")
            }
        }
        .padding(Space.xl)
    }

    /// Spec §3.3 booster row. Hidden entirely when `boost_count == 0` (caller gates).
    /// Visible & disabled when remaining=0 and bet not already boosted (un-boost is
    /// always allowed). Universal-bet caveat shows when the universal toggle AND the
    /// booster switch are both on.
    private var boosterRow: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Toggle(isOn: $boosted) {
                HStack(spacing: Space.xs) {
                    Text("🚀")
                        .font(.betty(16, .regular))
                    Text("Apply booster")
                        .font(.betty(13, .bold))
                        .foregroundStyle(theme.colors.textPrimary)
                }
            }
            .tint(Palette.orange)
            .disabled(boosterDisabled)
            .opacity(boosterDisabled ? 0.55 : 1)
            .accessibilityIdentifier("groupDetail.betSheet.boostToggle")

            Text(boosterHelpText)
                .font(.betty(12, .regular))
                .foregroundStyle(theme.colors.textSecondary)
                .lineSpacing(2)
                .accessibilityIdentifier("groupDetail.betSheet.boostHelp")

            if placeInAllGroups && boosted {
                Text("Booster applies to this group only — the bet's copies in your other groups aren't boosted.")
                    .font(.betty(12, .regular))
                    .foregroundStyle(Palette.orange)
                    .lineSpacing(2)
                    .accessibilityIdentifier("groupDetail.betSheet.boostUniversalCaveat")
            }
        }
        .padding(Space.s)
        .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sharp)
                .strokeBorder(theme.colors.overlay10, lineWidth: 1)
        }
    }

    private func scoreInput(_ label: String, id: String, text: Binding<String>) -> some View {
        VStack(spacing: 8) {
            Text(label).kicker(theme.colors.textSecondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.bettyScoreXL)
                .foregroundStyle(theme.colors.textPrimary)
                .disabled(lockInput)
                .padding(.vertical, 18)
                .padding(.horizontal, 8)
                .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sharp)
                        .strokeBorder(theme.colors.overlay10, lineWidth: 1)
                }
                .accessibilityIdentifier("groupDetail.betSheet.\(id)Field")
            HStack(spacing: Space.xs) {
                stepButton("minus") { step(text, by: -1) }
                    .accessibilityIdentifier("groupDetail.betSheet.\(id).minus")
                stepButton("plus") { step(text, by: 1) }
                    .accessibilityIdentifier("groupDetail.betSheet.\(id).plus")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(theme.colors.overlay08, in: RoundedRectangle(cornerRadius: Radius.sharp))
        }
        .buttonStyle(.plain)
        .disabled(lockInput)
    }

    private func step(_ text: Binding<String>, by delta: Int) {
        let current = Int(text.wrappedValue) ?? 0
        text.wrappedValue = String(max(0, current + delta))
    }

    // MARK: - Placed bets

    private var placedBetsTab: some View {
        let visibleBets = gameBets.filter { group?.member(withUserID: $0.userID) != nil }
        return VStack(spacing: 2) {
            ForEach(Array(GroupBetLogic.orderedBets(visibleBets).enumerated()), id: \.element.id) { index, bet in
                placedBetRow(bet)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("groupDetail.betSheet.placedRow.\(index)")
            }
            if visibleBets.isEmpty {
                Text("★ NO BETS YET")
                    .kicker(theme.colors.textMuted)
                    .padding(.vertical, Space.xl)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, Space.s)
    }

    private func placedBetRow(_ bet: Bet) -> some View {
        let isYou = env.userStore.id == bet.userID
        let member = group?.member(withUserID: bet.userID)
        return HStack {
            Text(member?.displayName ?? "")
                .font(.betty(14, .bold))
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: Space.xs)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if showScores {
                    Text("\(bet.homeTeamScore) – \(bet.awayTeamScore)")
                        .font(.betty(14, .heavy))
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textPrimary)
                    if bet.isProcessed {
                        let points = bet.userPoints ?? 0
                        Text(points > 0 ? "+\(points)P" : "0P")
                            .font(.bettyKicker)
                            .kerning(0.8)
                            .monospacedDigit()
                            // Web hard-codes 1 → semi (yellow), 3 → full (green) here,
                            // independent of the group's configured points.
                            .foregroundStyle(
                                points == 3 ? theme.colors.accentPositive
                                    : points == 1 ? Palette.yellow
                                    : theme.colors.textSecondary
                            )
                        // Post-evaluation rocket: only show when the bet scored > 0
                        // (spec §2.5 suppression rule).
                        if bet.boosted && points > 0 {
                            Text("🚀")
                                .font(.betty(13, .regular))
                                .accessibilityLabel("Boosted")
                        }
                    } else if bet.boosted {
                        // Pre-kickoff own-bet (or sneak-peek visible) rocket: standalone
                        // indicator next to the score, no point value yet.
                        Text("🚀")
                            .font(.betty(13, .regular))
                            .accessibilityLabel("Boosted")
                    }
                } else {
                    HiddenScoreView()
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isYou ? AnyShapeStyle(Palette.orangeTint12) : AnyShapeStyle(.clear))
        .overlay(alignment: .leading) {
            if isYou {
                Rectangle().fill(Palette.orange).frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $placeInAllGroups) {
                Text("Place this bet in all my groups")
                    .font(.betty(13, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .tint(Palette.orange)
            .accessibilityIdentifier("groupDetail.betSheet.universalToggle")

            Button {
                submit()
            } label: {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(myBet != nil ? "UPDATE BET" : "PLACE BET")
                }
            }
            .buttonStyle(.bettyPrimaryBlock)
            .disabled(!canSave || isSaving)
            .accessibilityIdentifier("groupDetail.betSheet.submit")
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, 14)
        .padding(.bottom, Space.l)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.colors.overlay06).frame(height: 1)
        }
    }

    // MARK: - Submit

    private func submit() {
        guard let home = Int(homeScore), let away = Int(awayScore), !isSaving else { return }
        let existing = myBet
        let route = GroupBetLogic.submitRoute(existing: existing, placeInAllGroups: placeInAllGroups)
        // Spec §2.6 invariant: when the group has boosters disabled (`boost_count == 0`)
        // but the existing bet has `boosted: true`, preserve it. Matches web
        // BetModal.vue:344 — `boostersEnabled ? boosted : !!existing?.boosted`.
        let outgoingBoosted = boostersEnabled ? boosted : (existing?.boosted ?? false)
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                switch route {
                case .update(let betID):
                    try await env.betStore.update(betID: betID, homeTeamScore: home,
                                                  awayTeamScore: away, boosted: outgoingBoosted)
                    try? await env.betStore.load(groupID: groupID)
                case .place(let isUniversal):
                    try await env.betStore.place(
                        gameID: gameID,
                        groupID: groupID,
                        homeTeamScore: home,
                        awayTeamScore: away,
                        isUniversal: isUniversal,
                        boosted: outgoingBoosted
                    )
                }
                successCount += 1
                dismiss()
            } catch APIError.locked {
                errorMessage = "Betting is closed — this game has already started."
            } catch {
                errorMessage = "Your bet could not be placed, please try again."
            }
        }
    }
}

/// Web `BetHistory.vue`: home/tie/away distribution bar (largest-remainder percentages)
/// over the two team logos around "VS"; finished games show the final score.
struct BetDistributionHeader: View {
    let bets: [Bet]
    let game: Game
    let homeTeam: Team?
    let awayTeam: Team?

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        let split = GroupBetLogic.distribution(bets)
        VStack(spacing: Space.s) {
            VStack(spacing: 4) {
                Text("\(split.tie)% TIE")
                    .font(.betty(11, .bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.textSecondary)
                HStack(spacing: Space.xs) {
                    Text("\(split.home)%")
                        .font(.betty(12, .bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textSecondary)
                    SplitProgressBarView(
                        leftProgress: Double(split.home),
                        tieProgress: Double(split.tie),
                        rightProgress: Double(split.away)
                    )
                    Text("\(split.away)%")
                        .font(.betty(12, .bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            HStack(alignment: .top) {
                teamColumn(homeTeam)
                VStack(spacing: 4) {
                    Text("VS")
                        .font(.bettyKicker)
                        .kerning(1.4)
                        .foregroundStyle(theme.colors.textMuted)
                    if game.isFinished {
                        Text("FINISHED")
                            .font(.betty(11, .heavy))
                            .kerning(1.2)
                            .foregroundStyle(theme.colors.textMuted)
                        Text("\(game.homeTeamScore.map(String.init) ?? "") - \(game.awayTeamScore.map(String.init) ?? "")")
                            .font(.betty(18, .black))
                            .monospacedDigit()
                            .foregroundStyle(theme.colors.textPrimary)
                    }
                }
                .padding(.top, Space.s)
                .frame(maxWidth: .infinity)
                teamColumn(awayTeam)
            }
        }
    }

    private func teamColumn(_ team: Team?) -> some View {
        VStack(spacing: 5) {
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
}
