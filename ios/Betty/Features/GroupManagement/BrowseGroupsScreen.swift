import SwiftUI

/// Web `/dashboard/groups/browse` — public-group discovery, fully featured:
/// 250 ms debounced search, running-tournament filter, shared Grouped/List toggle,
/// cursor pagination via infinite scroll (+ LOAD MORE fallback), optimistic join.
/// Rendered by the `BrowseGroupsView` tab root (Features/Tournaments).
struct BrowseGroupsScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var model: BrowseGroupsModel?
    @State private var searchDebounce: Task<Void, Never>?

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            if let model {
                content(model)
            } else {
                ProgressView()
                    .tint(theme.colors.textPrimary)
            }
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let created = BrowseGroupsModel(store: env.groupStore)
                model = created
                await reload(created)
            }
        }
    }

    private func content(_ model: BrowseGroupsModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.cardGap) {
                hero(model)
                resultsHeader(model)
                results(model)
            }
            .padding(Space.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await reload(model)
        }
    }

    // MARK: hero + filters

    private func hero(_ model: BrowseGroupsModel) -> some View {
        @Bindable var model = model
        return BettyCard {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("★ PUBLIC BOARD")
                    .kicker(Palette.orange)
                (Text("FIND A GROUP.\n").foregroundStyle(theme.colors.textPrimary)
                    + Text("PLACE A BET.").foregroundStyle(theme.colors.accentPositive))
                    .font(.bettyDisplayL)
                    .displayKerning(40)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Open public groups — no invite link needed.\nSearch by name, filter by tournament, jump in.")
                    .font(.betty(14, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: Space.s) {
                    GroupFormField(label: "Search") {
                        GroupFormTextField(placeholder: "Sunday Roast XI…", text: $model.query)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("browse.groups.searchField")
                    }
                    GroupFormField(label: "Tournament") {
                        tournamentFilter(model)
                    }
                }
                .padding(.top, Space.xs)
            }
        }
        .onChange(of: model.query) {
            searchDebounce?.cancel()
            searchDebounce = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await reload(model)
            }
        }
    }

    private func tournamentFilter(_ model: BrowseGroupsModel) -> some View {
        Menu {
            Button("All tournaments") {
                setTournamentFilter(model, id: nil)
            }
            ForEach(env.tournamentStore.running) { tournament in
                Button(tournament.name) {
                    setTournamentFilter(model, id: tournament.id)
                }
            }
        } label: {
            HStack {
                Text(selectedFilterName(model))
                    .font(.betty(15, .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .padding(Space.s)
            .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sharp)
                    .strokeBorder(theme.colors.overlay10, lineWidth: 1)
            }
        }
        .accessibilityIdentifier("browse.groups.tournamentFilter")
    }

    private func selectedFilterName(_ model: BrowseGroupsModel) -> String {
        guard let id = model.tournamentID else { return "All tournaments" }
        return env.tournamentStore.byID(id)?.name ?? "All tournaments"
    }

    private func setTournamentFilter(_ model: BrowseGroupsModel, id: Int?) {
        guard model.tournamentID != id else { return }
        model.tournamentID = id
        Task { await reload(model) }
    }

    // MARK: results header

    private func resultsHeader(_ model: BrowseGroupsModel) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("● LIVE")
                    .kicker(Palette.orange)
                Text(model.items.isEmpty && model.hasLoaded && !model.isLoading ? "NOTHING HERE." : "OPEN GROUPS.")
                    .font(.bettyTitle2)
                    .displayKerning(28)
                    .foregroundStyle(theme.colors.textPrimary)
            }
            Spacer()
            if !model.items.isEmpty {
                groupingToggle
            }
        }
    }

    private var groupingToggle: some View {
        let preferences = env.preferences
        return HStack(spacing: 2) {
            groupingButton("Grouped", isActive: preferences.showGrouped) { preferences.showGrouped = true }
            groupingButton("List", isActive: !preferences.showGrouped) { preferences.showGrouped = false }
        }
        .padding(3)
        .background(theme.colors.overlay04, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private func groupingButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.bettyKicker)
                .kerning(1.4)
                .foregroundStyle(isActive ? Palette.orange : theme.colors.textSecondary)
                .padding(.vertical, 7)
                .padding(.horizontal, Space.s)
                .background(isActive ? Palette.orangeTint18 : .clear, in: RoundedRectangle(cornerRadius: Radius.sharp))
        }
        .buttonStyle(.plain)
    }

    // MARK: results

    @ViewBuilder
    private func results(_ model: BrowseGroupsModel) -> some View {
        if model.isLoading && model.items.isEmpty {
            fetchingState
        } else if model.items.isEmpty && model.hasLoaded {
            emptyState
        } else {
            let cards = BrowseGrouping.cards(items: model.items, grouped: env.preferences.showGrouped)
            LazyVStack(alignment: .leading, spacing: Space.cardGap) {
                ForEach(cards) { card in
                    cardView(card, model: model)
                        .onAppear {
                            if card.id == cards.last?.id {
                                Task { await loadMore(model) }
                            }
                        }
                }
                if model.hasMore {
                    Button(model.isLoading ? "LOADING…" : "LOAD MORE ↓") {
                        Task { await loadMore(model) }
                    }
                    .buttonStyle(.bettyOutline)
                    .disabled(model.isLoading)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("browse.groups.loadMore")
                }
            }
        }
    }

    private var fetchingState: some View {
        BettyCard {
            VStack(spacing: Space.xs) {
                Text("★ FETCHING")
                    .kicker(Palette.orange)
                Text("Loading public groups…")
                    .font(.betty(15, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.xl)
        }
    }

    private var emptyState: some View {
        BettyCard {
            VStack(spacing: Space.xs) {
                Text("★ NO MATCHES")
                    .kicker(theme.colors.textMuted)
                Text("No public groups match your search.\nTry a different tournament — or start one of your own.")
                    .font(.betty(15, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Button("+ START A GROUP") {
                    env.router.activeSheet = .createGroup
                }
                .buttonStyle(.bettyOutline)
                .padding(.top, Space.s)
                .accessibilityIdentifier("browse.groups.createCTA")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.l)
        }
    }

    // MARK: cards

    @ViewBuilder
    private func cardView(_ card: BrowseCard, model: BrowseGroupsModel) -> some View {
        switch card {
        case .single(let group):
            singleCard(group, model: model)
        case .tournament(_, let name, let imageURL, let groups):
            tournamentCard(name: name, imageURL: imageURL, groups: groups, model: model)
        }
    }

    private func singleCard(_ group: PublicGroupItem, model: BrowseGroupsModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            cardImage(urlString: group.headerImageURL ?? group.tournamentImageURL)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("★ \(group.tournamentName.uppercased())")
                    .kicker(Palette.orange)
                Text(group.name)
                    .font(.bettyTitle2)
                    .displayKerning(28)
                    .foregroundStyle(theme.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let description = group.description {
                    Text(description)
                        .font(.betty(13, .regular))
                        .foregroundStyle(theme.colors.textSecondary)
                        .lineSpacing(3)
                        .lineLimit(3)
                }
                meta(for: group)
                actionButton(for: group, model: model, compact: false)
                    .padding(.top, Space.xs)
            }
            .padding(Space.l)
        }
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browse.groups.card.\(group.id)")
    }

    private func tournamentCard(name: String, imageURL: String?, groups: [PublicGroupItem], model: BrowseGroupsModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            cardImage(urlString: imageURL)
                .overlay(alignment: .bottom) {
                    HStack(alignment: .bottom) {
                        Text("★ \(name.uppercased())")
                            .kicker(Palette.orange)
                        Spacer()
                        Text("\(groups.count) GROUPS")
                            .font(.bettyKicker)
                            .kerning(1.4)
                            .foregroundStyle(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, Space.xs)
                            .background(Palette.pillDark, in: RoundedRectangle(cornerRadius: Radius.sharp))
                    }
                    .padding(Space.m)
                    .background {
                        LinearGradient(
                            colors: [Palette.ink.opacity(0), Palette.ink.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            VStack(spacing: 0) {
                ForEach(groups) { group in
                    stackRow(group, model: model)
                    if group.id != groups.last?.id {
                        Divider().overlay(theme.colors.overlay04)
                    }
                }
            }
            .padding(.vertical, Space.xxs)
        }
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private func stackRow(_ group: PublicGroupItem, model: BrowseGroupsModel) -> some View {
        HStack(spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(group.name)
                    .font(.betty(17, .heavy))
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                meta(for: group)
            }
            Spacer(minLength: Space.xs)
            actionButton(for: group, model: model, compact: true)
        }
        .padding(.vertical, Space.s)
        .padding(.horizontal, Space.l)
    }

    private func cardImage(urlString: String?) -> some View {
        ZStack {
            theme.colors.background
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        theme.colors.background
                    }
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
    }

    private func meta(for group: PublicGroupItem) -> some View {
        HStack(spacing: Space.xs) {
            Text("\(group.memberCount) \(group.memberCount == 1 ? "MEMBER" : "MEMBERS")")
                .kicker(theme.colors.textMuted)
            Text("·")
                .foregroundStyle(theme.colors.textMuted)
            Text("\(group.correctTeamPoints) / \(group.exactResultPoints) PTS")
                .kicker(theme.colors.textMuted)
            if group.isMember {
                Text("✓ MEMBER")
                    .kicker(theme.colors.accentPositive)
            }
        }
    }

    @ViewBuilder
    private func actionButton(for group: PublicGroupItem, model: BrowseGroupsModel, compact: Bool) -> some View {
        if group.isMember {
            Button(compact ? "OPEN →" : "OPEN GROUP →") {
                env.router.browsePath.append(.groupDetail(groupID: group.id))
            }
            .buttonStyle(compact
                ? BettyButtonStyle(variant: .ghost)
                : BettyButtonStyle(variant: .outline, isBlock: true))
            .accessibilityIdentifier("browse.groups.open.\(group.id)")
        } else {
            Button(joinLabel(for: group, model: model, compact: compact)) {
                Task { await join(group, model: model) }
            }
            .buttonStyle(compact
                ? BettyButtonStyle(variant: .primary)
                : BettyButtonStyle(variant: .primary, isBlock: true))
            .disabled(model.joiningID == group.id)
            .accessibilityIdentifier("browse.groups.join.\(group.id)")
        }
    }

    private func joinLabel(for group: PublicGroupItem, model: BrowseGroupsModel, compact: Bool) -> String {
        let joining = model.joiningID == group.id
        if compact {
            return joining ? "…" : "BET →"
        }
        return joining ? "PLACING…" : "BET HERE →"
    }

    // MARK: actions

    private func reload(_ model: BrowseGroupsModel) async {
        do {
            try await model.reload()
        } catch {
            env.toasts.alert(
                title: "Could not load groups",
                message: "Something went wrong while loading public groups. Please try again.",
                state: .error
            )
        }
    }

    private func loadMore(_ model: BrowseGroupsModel) async {
        do {
            try await model.loadMore()
        } catch {
            env.toasts.alert(
                title: "Could not load groups",
                message: "Something went wrong while loading public groups. Please try again.",
                state: .error
            )
        }
    }

    private func join(_ group: PublicGroupItem, model: BrowseGroupsModel) async {
        switch await model.join(group) {
        case .joined(let groupID, let name):
            env.toasts.confirm(question: "You are now a proud member of \(name). Go there now?") {
                env.router.browsePath.append(.groupDetail(groupID: groupID))
            }
        case .alreadyMember(let name):
            env.toasts.alert(message: "You are already a member of \(name).", state: .info)
        case .blocked(let name):
            env.toasts.alert(
                title: "Cannot bet here",
                message: "You have been blocked from \(name).",
                state: .warning
            )
        case .unavailable:
            env.toasts.alert(
                title: "Group unavailable",
                message: "This group is no longer public.",
                state: .warning
            )
        case .failed:
            env.toasts.alert(
                title: "Could not bet",
                message: "Something went wrong while joining the group. Please try again.",
                state: .error
            )
        }
    }
}
