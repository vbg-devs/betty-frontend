import SwiftUI

/// 5 tabs (web header nav + bell + avatar): Home, Browse, Leaderboard, Activity, Profile.
/// Each tab owns a `NavigationStack` over the shared `Destination` enum; sheets present
/// from `Router.activeSheet`.
///
/// Branded chrome (design §5.10): every screen pins the nav + tab bars to
/// `theme.colors.background` (the header IS the indigo, never system material), and the
/// Home tab carries the template wordmark as a leading toolbar item.
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var router = env.router
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .navigationDestination(for: Destination.self) { destinationView($0) }
                    .modifier(BrandedBarChrome())
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            BrandWordmark()
                        }
                    }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack(path: $router.browsePath) {
                BrowseGroupsView()
                    .navigationDestination(for: Destination.self) { destinationView($0) }
                    .modifier(BrandedBarChrome())
            }
            .tabItem { Label("Browse", systemImage: "magnifyingglass") }
            .tag(AppTab.browse)

            NavigationStack(path: $router.leaderboardPath) {
                GlobalLeaderboardView()
                    .navigationDestination(for: Destination.self) { destinationView($0) }
                    .modifier(BrandedBarChrome())
            }
            .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }
            .tag(AppTab.leaderboard)

            NavigationStack(path: $router.activityPath) {
                ActivityFeedView()
                    .navigationDestination(for: Destination.self) { destinationView($0) }
                    .modifier(BrandedBarChrome())
            }
            .tabItem { Label("Activity", systemImage: "bell.fill") }
            .tag(AppTab.activity)

            NavigationStack(path: $router.profilePath) {
                ProfileView()
                    .navigationDestination(for: Destination.self) { destinationView($0) }
                    .modifier(BrandedBarChrome())
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
            .tag(AppTab.profile)
        }
        .tint(Palette.orange)
        .sheet(item: $router.activeSheet) { sheet in
            sheetView(sheet)
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: Destination) -> some View {
        SwiftUI.Group {
            switch destination {
            case .groupDetail(let groupID):
                GroupDetailView(groupID: groupID)
            case .groupChat(let groupID):
                GroupChatView(groupID: groupID)
            case .support:
                SupportView()
            case .about:
                AboutView()
            case .adminEvaluate:
                AdminEvaluateView()
            }
        }
        .modifier(BrandedBarChrome())
    }

    /// Every router sheet carries its own toast host — `ToastOverlay` on `RootView`
    /// renders beneath presented sheets, so toasts fired while a sheet is up would
    /// otherwise be invisible.
    @ViewBuilder
    private func sheetView(_ sheet: SheetDestination) -> some View {
        SwiftUI.Group {
            switch sheet {
            case .createGroup:
                CreateGroupSheet()
            case .joinInvite(let code):
                JoinInviteSheet(code: code)
            case .bet(let gameID, let groupID):
                BetSheet(gameID: gameID, groupID: groupID)
            case .userHistory(let groupID, let userID):
                UserHistorySheet(groupID: groupID, userID: userID)
            case .groupSettings(let groupID):
                GroupSettingsSheet(groupID: groupID)
            }
        }
        .overlay(alignment: .top) {
            ToastOverlay()
        }
    }
}

/// Design §5.10 — the bars render the page background itself (the indigo in dark mode),
/// never the system chrome material that turns near-black once content scrolls under it.
private struct BrandedBarChrome: ViewModifier {
    @Environment(ThemeStore.self) private var theme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(theme.colors.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

/// The script wordmark as a template image, tinted like the web header logo:
/// cream (`textPrimary`) on dark, brand indigo on light.
private struct BrandWordmark: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Image("BettyWordmark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: 30)
            .foregroundStyle(theme.mode == .light ? Palette.indigo : theme.colors.textPrimary)
            .accessibilityLabel("Betty")
    }
}
