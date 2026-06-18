import SwiftUI

/// Web `/dashboard` — feedback pill, need-action games, Running/Ended tabs with
/// grouped/list group cards, hero (headline + first-kickoff countdown + create/browse
/// CTAs) below the list, per-tab and global empty states. Pull-to-refresh re-fetches
/// everything.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var viewModel: HomeViewModel?

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            if let viewModel {
                HomeContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .tint(theme.colors.textPrimary)
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    env.router.activeSheet = .createGroup
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New group")
            }
        }
        .task {
            if viewModel == nil {
                viewModel = HomeViewModel(
                    api: env.api,
                    userStore: env.userStore,
                    tournamentStore: env.tournamentStore
                )
            }
            await viewModel?.loadIfNeeded()
        }
        .onChange(of: env.groupStore.groups) {
            // Create/join/leave reload GroupStore — mirror into the rich placements list.
            guard let viewModel, viewModel.isLoaded else { return }
            Task { await viewModel.refresh(forceDetails: false) }
        }
        // Cold-start race: HomeView can appear (and run its initial refresh) before the
        // boot fan-out's `loadMe()` lands — without a uid the placements request is
        // skipped, leaving an empty dashboard. Re-run once the profile arrives.
        .onChange(of: env.userStore.id) {
            guard let viewModel, env.userStore.id != nil else { return }
            Task { await viewModel.refresh(forceDetails: false) }
        }
        // Live refresh: evaluated games and incoming bets re-derive the need-action
        // section (the coordinator already force-reloaded affected tournament details).
        .onChange(of: env.live.evaluationCount) {
            guard let viewModel, viewModel.isLoaded else { return }
            Task { await viewModel.refresh(forceDetails: false) }
        }
        .onChange(of: env.live.betActivityCount) {
            guard let viewModel, viewModel.isLoaded else { return }
            Task { await viewModel.refresh(forceDetails: false) }
        }
    }
}

private struct HomeContent: View {
    var viewModel: HomeViewModel

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.cardGap) {
                HomeFeedbackPill()
                HomeNeedActionSection(viewModel: viewModel)
                groupsSection
                if viewModel.isLoaded, !viewModel.placements.isEmpty {
                    HomeHeroCard(viewModel: viewModel)
                }
            }
            .padding(Space.m)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private var groupsSection: some View {
        if !viewModel.isLoaded {
            ProgressView()
                .tint(theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.xl)
        } else if viewModel.placements.isEmpty {
            if viewModel.loadFailed {
                loadFailedCard
            } else {
                HomeEmptyStateCard()
            }
        } else {
            let now = Date()
            HomeTabsRow(viewModel: viewModel, now: now)
            sectionHead
            let visible = viewModel.visibleItems(now: now)
            if visible.isEmpty {
                tabEmptyCard
            } else {
                ForEach(viewModel.cards(grouped: env.preferences.showGrouped, now: now)) { card in
                    switch card {
                    case .single(let item):
                        HomeGroupCardView(item: item)
                    case .stack(let tournament, let items, _, let recentlyEnded):
                        HomeStackedGroupCard(
                            tournament: tournament,
                            items: items,
                            recentlyEnded: recentlyEnded
                        )
                    }
                }
            }
        }
    }

    private var sectionHead: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(viewModel.selectedTab == .running ? "● ACTIVE" : "○ WRAPPED")
                .kicker(viewModel.selectedTab == .running ? Palette.orange : theme.colors.textMuted)
            Text(viewModel.selectedTab == .running ? "JUMP BACK IN." : "LOOK BACK.")
                .font(.bettyDisplayL)
                .displayKerning(40)
                .foregroundStyle(theme.colors.textPrimary)
        }
    }

    private var tabEmptyCard: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(viewModel.selectedTab == .running ? "○ NOTHING RUNNING" : "○ NOTHING WRAPPED")
                    .kicker(theme.colors.textMuted)
                Text(
                    viewModel.selectedTab == .running
                        ? "No active tournaments right now. Check the Ended tab to revisit past groups."
                        : "No tournaments have wrapped up yet. Recently-ended groups stay in Running for four weeks."
                )
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textBody)
                .accessibilityIdentifier("home.tabs.emptyCopy")
            }
        }
    }

    private var loadFailedCard: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("○ COULD NOT LOAD")
                    .kicker(theme.colors.textMuted)
                Text("Something went wrong while loading your groups. Please try again.")
                    .font(.bettyBody)
                    .foregroundStyle(theme.colors.textBody)
                Button("TRY AGAIN") {
                    Task { await viewModel.refresh() }
                }
                .buttonStyle(.bettyOutline)
                .accessibilityIdentifier("home.loadFailed.retry")
            }
        }
    }
}

/// Subtle right-aligned pill linking to Support — quieter entry point than the
/// old full-width banner so the dashboard leads with content, not chrome.
private struct HomeFeedbackPill: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            NavigationLink(value: Destination.support) {
                HStack(spacing: Space.xs) {
                    Circle()
                        .fill(theme.colors.accentPositive)
                        .frame(width: 6, height: 6)
                    Text("Feedback? Betty's listening")
                        .font(.bettyKicker)
                        .foregroundStyle(theme.colors.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.bettyKicker)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, Space.s)
                .background(theme.colors.overlay08, in: Capsule())
                .overlay(Capsule().stroke(theme.colors.overlay08, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.feedback.pill")
        }
    }
}

/// Hero card: kicker, headline, ticking first-kickoff countdown, create/browse CTAs.
private struct HomeHeroCard: View {
    var viewModel: HomeViewModel

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("★ YOUR GROUPS")
                    .kicker(Palette.orange)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: Space.m) {
                        headlineText(now: context.date)
                        if let kickoff = viewModel.nextKickoff(now: context.date) {
                            HomeCountdownView(kickoff: kickoff, now: context.date)
                        }
                    }
                }
                Button("+ NEW GROUP") {
                    env.router.activeSheet = .createGroup
                }
                .buttonStyle(.bettyPrimaryBlock)
                .accessibilityIdentifier("home.hero.newGroup")
                Button {
                    env.router.selectedTab = .browse
                } label: {
                    Text("OR BROWSE PUBLIC GROUPS →")
                        .kicker(theme.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.hero.browsePublic")
            }
        }
    }

    private func headlineText(now: Date) -> some View {
        let headline = viewModel.headline(now: now)
        let display: Text
        if case .groups = headline {
            // "N GROUPS." (count plain, word green) + orange "ONE CHAMPION." below.
            display = Text(headline.leadText).foregroundStyle(theme.colors.textPrimary)
                + Text(headline.accentText).foregroundStyle(theme.colors.accentPositive)
                + Text("\n")
                + Text(headline.trailingText ?? "").foregroundStyle(Palette.orange)
        } else {
            // "NO RUNNING/ENDED/GROUPS" plain + green "GROUPS."/"YET." below.
            display = Text(headline.leadText).foregroundStyle(theme.colors.textPrimary)
                + Text("\n")
                + Text(headline.accentText).foregroundStyle(theme.colors.accentPositive)
        }
        return display
            .font(.bettyDisplayL)
            .displayKerning(40)
            .accessibilityIdentifier("home.hero.headline")
    }
}

/// DD : HH : MM : SS cells, seconds in green, tournament name beneath.
private struct HomeCountdownView: View {
    let kickoff: HomeKickoff
    let now: Date

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        let countdown = HomeCountdown.until(kickoff.startDate, now: now)
        BettyInsetPanel {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("● FIRST KICKOFF IN")
                    .kicker(theme.colors.accentPositive)
                HStack(spacing: Space.xs) {
                    cell(HomeCountdown.pad(countdown.days), "DAYS")
                    cell(HomeCountdown.pad(countdown.hours), "HRS")
                    cell(HomeCountdown.pad(countdown.minutes), "MIN")
                    cell(HomeCountdown.pad(countdown.seconds), "SEC", accent: true)
                }
                Text("★ \(kickoff.tournament.name)")
                    .kicker(Palette.orange)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.hero.countdown")
    }

    private func cell(_ value: String, _ unit: String, accent: Bool = false) -> some View {
        VStack(spacing: Space.xxs) {
            Text(value)
                .font(.bettyScore)
                .displayKerning(28)
                .foregroundStyle(accent ? theme.colors.accentPositive : theme.colors.textPrimary)
            Text(unit)
                .font(.bettyMicro)
                .kerning(1.6)
                .foregroundStyle(theme.colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xs)
        .background(theme.colors.overlay04, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }
}

/// Tabs row: Running/Ended underline tabs with counts + the shared Grouped/List toggle.
private struct HomeTabsRow: View {
    var viewModel: HomeViewModel
    let now: Date

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        HStack(alignment: .bottom, spacing: Space.l) {
            tabButton("RUNNING", tab: .running, count: viewModel.runningItems(now: now).count)
            tabButton("ENDED", tab: .ended, count: viewModel.endedItems(now: now).count)
            Spacer()
            groupingToggle
                .padding(.bottom, Space.xs)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.overlay08)
                .frame(height: 1)
        }
    }

    private func tabButton(_ label: String, tab: HomeTab, count: Int) -> some View {
        let isActive = viewModel.selectedTab == tab
        return Button {
            viewModel.selectedTab = tab
        } label: {
            HStack(spacing: Space.xs) {
                Text(label)
                    .font(.bettyCaption)
                    .kerning(1.6)
                    .foregroundStyle(isActive ? theme.colors.textPrimary : theme.colors.textMuted)
                CountPill(count: count, isActive: isActive)
            }
            .padding(.vertical, Space.s)
            .overlay(alignment: .bottom) {
                if isActive {
                    Rectangle()
                        .fill(Palette.orange)
                        .frame(height: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab == .running ? "home.tabs.running" : "home.tabs.ended")
    }

    private var groupingToggle: some View {
        HStack(spacing: 0) {
            toggleSegment("GROUPED", isActive: env.preferences.showGrouped) {
                env.preferences.showGrouped = true
            }
            .accessibilityIdentifier("home.tabs.grouped")
            toggleSegment("LIST", isActive: !env.preferences.showGrouped) {
                env.preferences.showGrouped = false
            }
            .accessibilityIdentifier("home.tabs.list")
        }
        .padding(3)
        .background(theme.colors.overlay04, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private func toggleSegment(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.bettyKicker)
                .kerning(1.4)
                .foregroundStyle(isActive ? Palette.orange : theme.colors.textMuted)
                .padding(.vertical, 7)
                .padding(.horizontal, Space.s)
                .background(
                    isActive ? Palette.orangeTint18 : .clear,
                    in: RoundedRectangle(cornerRadius: Radius.sharp)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Global empty state — nudge to create a group or browse/join a public one.
private struct HomeEmptyStateCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        BettyCard {
            VStack(spacing: Space.m) {
                Text("★ GET STARTED")
                    .kicker(Palette.orange)
                (
                    Text("SIX FRIENDS.\n").foregroundStyle(theme.colors.textPrimary)
                        + Text("ONE GROUP.").foregroundStyle(Palette.orange)
                )
                .font(.bettyDisplayL)
                .displayKerning(40)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("home.empty.headline")
                Text("Invite a bunch of friends and start your first group for the next cup.")
                    .font(.bettyBody)
                    .foregroundStyle(theme.colors.textBody)
                    .multilineTextAlignment(.center)
                Button("+ START A GROUP") {
                    env.router.activeSheet = .createGroup
                }
                .buttonStyle(.bettyPrimaryBlock)
                .accessibilityIdentifier("home.empty.startGroup")
                Button {
                    env.router.selectedTab = .browse
                } label: {
                    Text("OR JOIN A PUBLIC GROUP →")
                        .kicker(theme.colors.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.empty.joinPublic")
            }
            .frame(maxWidth: .infinity)
        }
    }
}
