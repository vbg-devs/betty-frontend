import PhotosUI
import SwiftUI

/// Web `/dashboard/groups/[id]` — the core screen: hero with rank/champion stats +
/// author cover upload, Group / Games / Leaderboard tabs, the NeedAction urgent-games
/// strip, dense-ranked standings, day-grouped schedule, bet placement, nickname editor,
/// member history drilldowns, 10 s bet polling and WS-driven refresh.
struct GroupDetailView: View {
    let groupID: Int

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    enum Tab: Hashable { case group, games, leaderboard }

    @State private var selectedTab: Tab = .group
    @State private var copiedInvite = false
    @State private var warnedBetsFailure = false
    @State private var nicknameDraft = ""
    @State private var nicknameLoadedFor: Int?
    @State private var isSavingNickname = false
    @State private var coverItem: PhotosPickerItem?
    @State private var isUploadingCover = false
    @State private var isSavingVisibility = false

    private var group: Group? { env.groupStore.byID(groupID) }

    private var isAuthor: Bool {
        group?.member(withUserID: env.userStore.id)?.isAuthor ?? false
    }

    private var tournament: Tournament? {
        guard let group else { return nil }
        return env.tournamentStore.byID(group.tournamentID)
    }

    /// Web pin: no tournament counts as ended; missing end_date means running.
    private var tournamentEnded: Bool {
        guard let tournament else { return true }
        guard let endDate = tournament.endDate else { return false }
        return endDate < Date()
    }

    private var tournamentDetails: Tournament? {
        guard let group else { return nil }
        return env.tournamentStore.detailsByID(group.tournamentID)
    }

    private var allGames: [Game] { tournamentDetails?.games ?? [] }
    private var completeGames: [Game] { allGames.filter(\.isFinished) }

    private var ranked: [DenseRanking.Ranked<Member>] {
        GroupStandings.ranked(group?.members ?? [])
    }

    /// Ended tournaments hide the Games tab (web pin).
    private var currentTab: Tab {
        if tournamentEnded && selectedTab == .games { return .group }
        return selectedTab
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            if let group {
                content(group)
            } else {
                ScreenPlaceholder(
                    kickerText: "GROUP",
                    title: "GROUP NOT FOUND",
                    note: "This group isn't in your list."
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: groupID) { await pollBets() }
        .task(id: groupID) { await observeSocket() }
        .refreshable { await reloadAll(force: true) }
    }

    // MARK: - Data

    private func pollBets() async {
        while !Task.isCancelled {
            if let group, env.tournamentStore.detailsByID(group.tournamentID) == nil {
                _ = try? await env.tournamentStore.loadDetails(id: group.tournamentID)
            }
            do {
                try await env.betStore.load(groupID: groupID)
            } catch is CancellationError {
                return // the poll task was torn down — not a user-facing failure
            } catch {
                if Task.isCancelled { return }
                if !warnedBetsFailure {
                    warnedBetsFailure = true
                    env.toasts.alert(
                        title: "Could not load bets",
                        message: "Please refresh to make sure all bets are loaded.",
                        state: .warning
                    )
                }
            }
            try? await Task.sleep(for: .seconds(10))
        }
    }

    private func observeSocket() async {
        for await event in env.socket.events() {
            if case .evaluateGame = event {
                await reloadAll(force: true)
            }
        }
    }

    private func reloadAll(force: Bool) async {
        if let group {
            _ = try? await env.tournamentStore.loadDetails(id: group.tournamentID, force: force)
        }
        try? await env.betStore.load(groupID: groupID)
    }

    // MARK: - Layout

    private func content(_ group: Group) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    hero(group)
                    tabBar
                    switch currentTab {
                    case .group:
                        groupTab(group)
                    case .games:
                        GroupGameSchedule(
                            pools: tournamentDetails?.poolsWithGames ?? [],
                            bets: env.betStore.bets,
                            showBets: true,
                            onGameTap: { openBetSheet(for: $0) }
                        )
                    case .leaderboard:
                        GroupLeaderboardList(members: group.members) { openHistory(for: $0) }
                    }
                }
                .padding(Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Suppress the horizontal rubber-band that SwiftUI's default ScrollView
            // shows when a child's intrinsic width occasionally pokes past the bounds.
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onChange(of: currentTab) { _, newTab in
                guard newTab == .games else { return }
                let groups = GroupGameDaySchedule.build(pools: tournamentDetails?.poolsWithGames ?? [])
                guard let key = GroupGameDaySchedule.nextUpcomingKey(in: groups) else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation {
                        proxy.scrollTo(GroupGameSchedule.dayAnchorID(key), anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private func hero(_ group: Group) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("★ YOUR GROUP\(tournament.map { " · \($0.name.uppercased())" } ?? "")")
                .kicker(Palette.orange)
            Text(group.name.uppercased())
                .font(.bettyDisplayL)
                .displayKerning(40)
                .foregroundStyle(heroTextPrimary(group))
                .lineLimit(3)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Space.xs) {
                Text("\(group.members.count) MEMBERS")
                    .kicker(heroTextSecondary(group))
                if !allGames.isEmpty {
                    Text("·").foregroundStyle(heroTextSecondary(group))
                    Text("\(completeGames.count) OF \(allGames.count) GAMES")
                        .kicker(heroTextSecondary(group))
                }
                Text("·").foregroundStyle(heroTextSecondary(group))
                Text(tournamentEnded ? "○ FINAL" : "● ACTIVE")
                    .kicker(tournamentEnded ? heroTextSecondary(group) : theme.colors.accentPositive)
            }

            HStack(spacing: Space.s) {
                if tournamentEnded {
                    championTile
                    finishTile(group)
                } else {
                    rankTile(group)
                    gamesPlayedTile
                }
            }

            if isAuthor {
                coverPicker(group)
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let imageURL = group.headerImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        theme.colors.surface
                    }
                }
                .overlay(heroScrim)
            } else {
                theme.colors.surface
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
    }

    /// Web pins the cover overlay to a dark indigo gradient regardless of theme, so text
    /// on it always uses the dark-surface values.
    private var heroScrim: LinearGradient {
        let indigoDeep = Color(hex: 0x141938)
        return LinearGradient(
            colors: [indigoDeep.opacity(0.55), indigoDeep.opacity(0.88)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func heroTextPrimary(_ group: Group) -> Color {
        group.headerImageURL != nil ? ThemeColors.dark.textPrimary : theme.colors.textPrimary
    }

    private func heroTextSecondary(_ group: Group) -> Color {
        group.headerImageURL != nil ? ThemeColors.dark.textSecondary : theme.colors.textSecondary
    }

    // MARK: - Cover upload (author only)

    private func coverPicker(_ group: Group) -> some View {
        let label = isUploadingCover
            ? "UPLOADING…"
            : (group.headerImageURL == nil ? "+ ADD COVER" : "CHANGE COVER →")
        let color = group.headerImageURL != nil ? ThemeColors.dark.textPrimary : Palette.orange
        return PhotosPicker(selection: $coverItem, matching: .images, photoLibrary: .shared()) {
            // `.kicker` is MainActor-isolated and the picker label closure is not —
            // apply the same modifiers inline.
            Text(label)
                .font(.bettyKicker)
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundStyle(color)
        }
        .accessibilityIdentifier("groupDetail.hero.coverCTA")
        .disabled(isUploadingCover)
        .onChange(of: coverItem) { _, item in
            guard let item else { return }
            Task { await uploadCover(item) }
        }
    }

    /// Web cover flow: jpeg/png/webp/gif ≤ 1 MB → presign → raw PUT → commit.
    /// Errors: 401 not author, 413 too large, 415 bad type, 503 uploads unavailable.
    private func uploadCover(_ item: PhotosPickerItem) async {
        defer { coverItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            env.toasts.alert(title: "Could not update cover", message: ProfileImagePolicy.genericUploadMessage, state: .error)
            return
        }
        let contentType = ProfileImagePolicy.sniffContentType(data) ?? ""
        if let message = ProfileImagePolicy.validationError(contentType: contentType, byteCount: data.count) {
            env.toasts.alert(title: "Could not update cover", message: message, state: .warning)
            return
        }
        isUploadingCover = true
        defer { isUploadingCover = false }
        do {
            try await env.groupStore.uploadHeaderImage(groupID: groupID, data: data, contentType: contentType)
            env.toasts.alert(message: "Cover updated.", state: .success)
        } catch let error as APIError {
            env.toasts.alert(title: "Could not update cover", message: GroupCoverPolicy.errorMessage(status: error.status), state: .error)
        } catch {
            env.toasts.alert(title: "Could not update cover", message: ProfileImagePolicy.genericUploadMessage, state: .error)
        }
    }

    private func rankTile(_ group: Group) -> some View {
        statTile(background: Palette.orange) {
            Text("YOUR RANK").kicker(.white.opacity(0.85))
            Text(GroupStandings.placeDisplay(GroupStandings.yourPlace(ranked, userID: env.userStore.id)))
                .font(.bettyDisplayXL)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
            Text("OF \(String(format: "%02d", group.members.count))")
                .kicker(.white.opacity(0.85))
        }
    }

    private var gamesPlayedTile: some View {
        let percent = GroupStandings.completionPercentage(
            completeGames: completeGames.count,
            allGames: allGames.count
        )
        return statTile(background: theme.colors.overlay06) {
            Text("GAMES PLAYED").kicker(theme.colors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(percent)")
                    .font(.bettyDisplayXL)
                    .foregroundStyle(theme.colors.textPrimary)
                    .minimumScaleFactor(0.5)
                Text("%")
                    .font(.betty(28, .heavy))
                    .foregroundStyle(theme.colors.textPrimary.opacity(0.75))
            }
            ProgressBarView(progress: Double(percent))
        }
    }

    private var championTile: some View {
        let champions = GroupStandings.champions(ranked)
        let champion = champions.first
        let youWon = env.userStore.id.map { id in champions.contains { $0.userID == id } } ?? false
        return statTile(background: Palette.orange) {
            Text(youWon ? "YOU WON" : "CHAMPION").kicker(.white.opacity(0.85))
            if let champion {
                AvatarView(member: champion, size: .medium)
                Text(champion.displayName)
                    .font(.betty(22, .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(champion.score) PTS").kicker(.white.opacity(0.85))
            } else {
                Text("–")
                    .font(.bettyDisplayXL)
                    .foregroundStyle(.white)
            }
        }
    }

    private func finishTile(_ group: Group) -> some View {
        statTile(background: theme.colors.overlay06) {
            Text("YOUR FINISH").kicker(theme.colors.textSecondary)
            Text(GroupStandings.placeDisplay(GroupStandings.yourPlace(ranked, userID: env.userStore.id)))
                .font(.bettyDisplayXL)
                .foregroundStyle(theme.colors.textPrimary)
                .minimumScaleFactor(0.5)
            Text("OF \(String(format: "%02d", group.members.count))")
                .kicker(theme.colors.textSecondary)
        }
    }

    private func statTile(background: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: Space.xl) {
            tabButton("GROUP", tab: .group)
            if !tournamentEnded {
                tabButton("GAMES", tab: .games)
            }
            tabButton("LEADERBOARD", tab: .leaderboard)
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.overlay08).frame(height: 1)
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
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    if currentTab == tab {
                        Rectangle().fill(Palette.orange).frame(height: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Group tab

    @ViewBuilder
    private func groupTab(_ group: Group) -> some View {
        welcomeCard(group)

        if tournamentEnded {
            podiumCard(group)
        }

        if !tournamentEnded {
            needActionStrip(group)
            sideCard("★ TOP 3") {
                GroupTopThree(members: group.members) { openHistory(for: $0) }
            }
            inviteCard(group)
        }

        if !tournamentEnded {
            nicknameCard(group) // web pin: hidden once the tournament ended
        }
        rosterCard(group)
        if !tournamentEnded {
            visibilityCard(group)
        }
        houseRulesCard(group)
        chatCard
        leaveButton(group)
    }

    // MARK: - Need action (web NeedAction.vue)

    /// Up to 3 urgent games (kickoff < 24 h, unfinished, un-bet by me), else today's
    /// games, else nothing — same rules as the Home strip, scoped to this group.
    @ViewBuilder
    private func needActionStrip(_ group: Group) -> some View {
        let bets = env.betStore.bets
        let source = HomeNeedActionSource(
            groupID: groupID,
            groupName: group.name,
            games: allGames,
            bets: bets
        )
        let display = HomeDashboardLogic.needActionDisplay(
            sources: [source],
            userID: env.userStore.id,
            now: Date()
        )
        switch display {
        case .urgent(let entries):
            needActionPanel(
                accent: Palette.yellow,
                header: "Make sure to bet on these games before it's too late!",
                headerColor: Palette.yellow,
                entries: entries,
                bets: bets
            )
        case .today(let entries):
            needActionPanel(
                accent: theme.colors.overlay10,
                header: "Todays games",
                headerColor: theme.colors.textMuted,
                entries: entries,
                bets: bets
            )
        case .hidden:
            EmptyView()
        }
    }

    private func needActionPanel(
        accent: Color,
        header: String,
        headerColor: Color,
        entries: [HomeNeedActionEntry],
        bets: [Bet]
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
                ForEach(entries) { entry in
                    let ownBet = BetOwnership.firstOwnBet(in: bets, gameID: entry.game.id, userID: env.userStore.id)
                    GroupGameCard(
                        game: entry.game,
                        betted: ownBet != nil,
                        placedHome: ownBet?.homeTeamScore ?? 0,
                        placedAway: ownBet?.awayTeamScore ?? 0,
                        awardedPoints: GroupGameCardLogic.awardedPoints(
                            game: entry.game,
                            bets: bets,
                            userID: env.userStore.id
                        ),
                        awardedBoosted: GroupGameCardLogic.awardedBoosted(
                            game: entry.game,
                            bets: bets,
                            userID: env.userStore.id
                        ),
                        placedBoosted: ownBet?.boosted ?? false,
                        betCount: BetOwnership.betCount(in: bets, gameID: entry.game.id),
                        onTap: { openBetSheet(for: entry.game) }
                    )
                }
            }
        }
    }

    // MARK: - Nickname (web NicknameCard)

    private func nicknameCard(_ group: Group) -> some View {
        sideCard("★ YOUR NICKNAME") {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("How your name shows in this group. Leave empty to use your real name.")
                    .font(.betty(13, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
                HStack(spacing: Space.xs) {
                    TextField("Your nickname", text: $nicknameDraft)
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textPrimary)
                        .autocorrectionDisabled()
                        .padding(Space.s)
                        .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
                        .onChange(of: nicknameDraft) { _, newValue in
                            // Web caps nicknames at 120 characters.
                            if newValue.count > 120 {
                                nicknameDraft = String(newValue.prefix(120))
                            }
                        }
                    Button(isSavingNickname ? "SAVING…" : "SAVE") {
                        saveNickname()
                    }
                    .buttonStyle(.bettyPrimary)
                    .disabled(isSavingNickname)
                }
            }
        }
        .onAppear {
            guard nicknameLoadedFor != groupID else { return }
            nicknameLoadedFor = groupID
            nicknameDraft = group.member(withUserID: env.userStore.id)?.nickname ?? ""
        }
    }

    /// `PUT /group/:id/nickname` — trimmed; empty clears (web sends null).
    private func saveNickname() {
        let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        isSavingNickname = true
        Task {
            defer { isSavingNickname = false }
            do {
                try await env.groupStore.setNickname(id: groupID, trimmed.isEmpty ? nil : trimmed)
                env.toasts.alert(message: trimmed.isEmpty ? "Nickname cleared." : "Nickname updated.", state: .success)
            } catch {
                env.toasts.alert(
                    title: "Could not update nickname",
                    message: "Something went wrong while saving your nickname. Please try again.",
                    state: .error
                )
            }
        }
    }

    @ViewBuilder
    private func welcomeCard(_ group: Group) -> some View {
        if let welcome = group.welcomeMessage, !welcome.isEmpty {
            BettyInsetPanel(accent: Palette.orange) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("★ WELCOME").kicker(Palette.orange)
                    Text(welcome)
                        .font(.betty(20, .semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                    if let description = group.description, !description.isEmpty {
                        Text(description)
                            .font(.bettyBody)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
            }
        } else if let description = group.description, !description.isEmpty {
            BettyInsetPanel(accent: theme.colors.overlay10) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("★ ABOUT THIS GROUP").kicker(theme.colors.textSecondary)
                    Text(description)
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func podiumCard(_ group: Group) -> some View {
        let slots = GroupStandings.podium(ranked)
        if !slots.isEmpty {
            let champions = GroupStandings.champions(ranked)
            let youWon = env.userStore.id.map { id in champions.contains { $0.userID == id } } ?? false
            BettyCard {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("★ FINAL PODIUM").kicker(Palette.orange)
                        Text(youWon ? "YOU TOOK IT." : "CHAMPION CROWNED.")
                            .font(.bettyTitle2)
                            .foregroundStyle(theme.colors.textPrimary)
                    }
                    GroupPodiumView(slots: slots) { openHistory(for: $0) }
                    Button("SEE FULL LEADERBOARD →") { selectedTab = .leaderboard }
                        .buttonStyle(.bettyGhost)
                        .foregroundStyle(Palette.orange)
                }
            }
        }
    }

    private func inviteCard(_ group: Group) -> some View {
        sideCard("★ INVITE LINK") {
            HStack(spacing: Space.xs) {
                Text(group.inviteLink?.absoluteString ?? group.inviteCode)
                    .font(.betty(12, .medium))
                    .foregroundStyle(theme.colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.s)
                    .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
                Button(copiedInvite ? "COPIED ✓" : "COPY →") {
                    UIPasteboard.general.string = group.inviteLink?.absoluteString ?? group.inviteCode
                    copiedInvite = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copiedInvite = false
                    }
                }
                .buttonStyle(.bettyPrimary)
                if let inviteLink = group.inviteLink {
                    ShareLink(item: inviteLink) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.orange)
                    }
                }
            }
        }
    }

    private func rosterCard(_ group: Group) -> some View {
        let rosterLimit = 6
        let visible = ranked.prefix(rosterLimit)
        return sideCard("★ GROUP ROSTER") {
            VStack(alignment: .leading, spacing: Space.xs) {
                (
                    Text("\(group.members.count) \(group.members.count == 1 ? "FRIEND" : "FRIENDS").\n")
                        .foregroundStyle(theme.colors.textPrimary)
                    + Text("ONE CHAMPION.")
                        .foregroundStyle(Palette.orange)
                )
                .font(.betty(26, .black))

                VStack(spacing: 2) {
                    ForEach(visible) { entry in
                        Button {
                            openHistory(for: entry.item)
                        } label: {
                            HStack(spacing: Space.s) {
                                Text("#\(entry.place)")
                                    .font(.betty(13, .black))
                                    .monospacedDigit()
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .frame(width: 32, alignment: .leading)
                                AvatarView(member: entry.item, size: .small)
                                Text(entry.item.displayName)
                                    .font(.betty(13, .bold))
                                    .foregroundStyle(theme.colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: Space.xs)
                                Text("\(entry.item.score)p")
                                    .font(.betty(13, .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if ranked.count > rosterLimit {
                    Button("SEE ALL \(ranked.count) →") { selectedTab = .leaderboard }
                        .buttonStyle(.bettyGhost)
                        .foregroundStyle(Palette.orange)
                }
            }
        }
    }

    // MARK: - Visibility (web side-card--visibility, shown to every member)

    private func visibilityCard(_ group: Group) -> some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    Text("★ VISIBILITY").kicker(Palette.orange)
                    Spacer()
                    Text(group.isPublic ? "● PUBLIC" : "○ PRIVATE")
                        .kicker(group.isPublic ? theme.colors.accentPositive : theme.colors.textMuted)
                }
                Text(group.isPublic
                    ? "Anyone can find this group on the public board and bet here."
                    : "Only people with the invite link can bet here.")
                    .font(.betty(13, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
                Button(isSavingVisibility ? "SAVING…" : (group.isPublic ? "MAKE PRIVATE" : "GO PUBLIC →")) {
                    toggleVisibility(to: !group.isPublic)
                }
                .buttonStyle(.bettyOutline)
                .disabled(isSavingVisibility)
            }
        }
    }

    /// `PUT /group/:id/visibility` — every member sees the button; the API rejects
    /// non-authors with 401/403.
    private func toggleVisibility(to isPublic: Bool) {
        isSavingVisibility = true
        Task {
            defer { isSavingVisibility = false }
            do {
                try await env.groupStore.setVisibility(id: groupID, isPublic: isPublic)
            } catch let error as APIError where error.status == 401 || error.status == 403 {
                env.toasts.alert(
                    title: "Not allowed",
                    message: "Only the group author can change visibility.",
                    state: .warning
                )
            } catch {
                env.toasts.alert(
                    title: "Could not update visibility",
                    message: "Something went wrong. Please try again.",
                    state: .error
                )
            }
        }
    }

    private func houseRulesCard(_ group: Group) -> some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    Text("★ HOUSE RULES").kicker(Palette.orange)
                    Spacer()
                    if isAuthor {
                        Button("EDIT →") {
                            env.router.activeSheet = .groupSettings(groupID: groupID)
                        }
                        .buttonStyle(.bettyGhost)
                        .foregroundStyle(Palette.orange)
                    }
                }
                VStack(spacing: 0) {
                    ruleRow("Winning team", value: "\(group.correctTeamPoints) pts", valueColor: theme.colors.textPrimary)
                    Divider().overlay(theme.colors.overlay06)
                    ruleRow("Exact score", value: "\(group.exactResultPoints) pts", valueColor: theme.colors.textPrimary)
                    Divider().overlay(theme.colors.overlay06)
                    ruleRow(
                        "Sneak peek",
                        value: group.allowSneakPeek ? "Allowed" : "Closed",
                        valueColor: group.allowSneakPeek ? theme.colors.accentPositive : Palette.orange
                    )
                    if group.boostCount > 0 {
                        Divider().overlay(theme.colors.overlay06)
                        boostRuleRow(count: group.boostCount, multiplier: group.boostMultiplier)
                    }
                }
            }
        }
    }

    private func ruleRow(_ label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.betty(13, .regular))
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
            Text(value)
                .font(.betty(13, .heavy))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 10)
    }

    /// Mirrors the web `boost-chip`: count, muted `×`, then an orange-tinted pill with the
    /// multiplier matching the placed-bet chip styling.
    private func boostRuleRow(count: Int, multiplier: Int) -> some View {
        HStack {
            Text("Boosters 🚀")
                .font(.betty(13, .regular))
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                Text("\(count)")
                    .font(.betty(13, .heavy))
                    .foregroundStyle(theme.colors.textPrimary)
                Text("×")
                    .font(.betty(13, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
                Text("\(multiplier)×")
                    .font(.bettyKicker)
                    .kerning(0.4)
                    .foregroundStyle(Palette.orange)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Palette.orangeTint15, in: RoundedRectangle(cornerRadius: Radius.sharp))
            }
        }
        .padding(.vertical, 10)
    }

    private var chatCard: some View {
        NavigationLink(value: Destination.groupChat(groupID: groupID)) {
            Text("OPEN MEME BOARD →")
        }
        .buttonStyle(.bettyOutline)
    }

    private func leaveButton(_ group: Group) -> some View {
        Button("LEAVE GROUP") {
            env.toasts.confirm(question: "Are you sure you want to leave \(group.name)?") {
                do {
                    try await env.groupStore.leave(id: groupID)
                    dismiss()
                } catch {
                    env.toasts.alert(
                        title: "Could not leave group",
                        message: "Something went wrong while leaving the group. Please try again.",
                        state: .error
                    )
                }
            }
        }
        .buttonStyle(.bettyDestructive)
    }

    private func sideCard(_ kickerText: String, @ViewBuilder content: () -> some View) -> some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(kickerText).kicker(Palette.orange)
                content()
            }
        }
    }

    // MARK: - Navigation

    private func openBetSheet(for game: Game) {
        env.router.activeSheet = .bet(gameID: game.id, groupID: groupID)
    }

    private func openHistory(for member: Member) {
        env.router.activeSheet = .userHistory(groupID: groupID, userID: member.userID)
    }
}
