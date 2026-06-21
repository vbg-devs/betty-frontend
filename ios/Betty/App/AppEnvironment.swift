import Foundation
import Observation
import UIKit

/// Composition root — constructs and owns every shared service/store. Injected once at
/// the app root via `.environment(env)` (plus `theme`/`router` individually) and read
/// with `@Environment(AppEnvironment.self) private var env`.
@Observable
final class AppEnvironment {
    let auth: AuthService
    let api: APIClient
    let socket: WebSocketService
    let theme: ThemeStore
    let router: Router
    let toasts: ToastCenter
    let preferences: Preferences

    let userStore: UserStore
    let groupStore: GroupStore
    let tournamentStore: TournamentStore
    let teamStore: TeamStore
    let gameStore: GameStore
    let betStore: BetStore
    let activityFeed: ActivityFeedStore
    let countries: CountriesProvider

    let live: LiveUpdateCoordinator
    let push: PushRegistrationService

    /// Admin-only live pending-proposal count for the FIFA review badge + toast.
    let adminProposals: AdminProposalsStore

    /// True under BETTY_UITEST=1 (DEBUG only) — views may disable OS affordances that
    /// XCUITest cannot drive (e.g. the Automatic Strong Password cover view).
    let isUITest: Bool

    /// True once teams + tournaments + groups loaded after sign-in.
    private(set) var isBootstrapped = false
    /// Set when the parallel boot fan-out failed — RootView swaps in `BootFailedView`,
    /// whose retry re-runs `onSignedIn()`. Cleared only by a successful bootstrap.
    private(set) var bootFailed = false

    init(auth: AuthService? = nil) {
        // Hermetic UI-test seams (no-ops in release — see LaunchOverrides).
        let overrides = LaunchOverrides.read()
        self.isUITest = overrides.isUITest
        #if DEBUG
        if overrides.isUITest {
            Self.resetPersistentState(seeding: overrides)
        }
        if overrides.disableAnimations {
            UIView.setAnimationsEnabled(false)
        }
        #endif
        let auth = auth ?? AuthService(
            identityBaseURL: overrides.identityBaseURL ?? AuthService.defaultIdentityBaseURL,
            secureTokenBaseURL: overrides.secureTokenBaseURL ?? AuthService.defaultSecureTokenBaseURL
        )
        self.auth = auth
        let api = APIClient(tokens: auth, baseURL: overrides.apiBaseURL ?? APIClient.defaultBaseURL)
        self.api = api
        self.socket = WebSocketService(url: overrides.webSocketURL ?? WebSocketService.defaultURL)
        self.theme = ThemeStore()
        self.router = Router()
        self.toasts = ToastCenter()
        self.preferences = Preferences()
        let userStore = UserStore(api: api)
        self.userStore = userStore
        self.groupStore = GroupStore(api: api)
        let tournamentStore = TournamentStore(api: api)
        self.tournamentStore = tournamentStore
        self.teamStore = TeamStore(api: api)
        let gameStore = GameStore(api: api)
        self.gameStore = gameStore
        let betStore = BetStore(api: api)
        self.betStore = betStore
        // Web keeps only 5 events; a native screen affords a longer scrollback.
        self.activityFeed = ActivityFeedStore(capacity: 50)
        self.countries = CountriesProvider(api: api)
        self.live = LiveUpdateCoordinator(
            tournamentStore: tournamentStore,
            gameStore: gameStore,
            betStore: betStore
        )
        // UI tests must never trigger the system notification-permission dialog (it
        // would hang XCUITest behind an OS alert) — deny authorization up front so
        // registration short-circuits to `.denied`.
        if overrides.isUITest {
            self.push = PushRegistrationService(
                sendToken: { token in try await userStore.addPushToken(token) },
                requestAuthorization: { false }
            )
        } else {
            self.push = PushRegistrationService(sendToken: { token in
                try await userStore.addPushToken(token)
            })
        }
        self.adminProposals = AdminProposalsStore(fetchCount: { [api] in
            try await api.fifaPendingProposalsCount()
        })
    }

    #if DEBUG
    /// `BETTY_UITEST=1`: wipe the Keychain session + UserDefaults for a deterministic
    /// launch, then seed the mock session when the test runner provided one.
    private static func resetPersistentState(seeding overrides: LaunchOverrides) {
        let keychain = KeychainStore()
        keychain.delete(AuthService.refreshTokenKey)
        keychain.delete(AuthService.uidKey)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        if let token = overrides.seededRefreshToken, let uid = overrides.seededUID {
            try? keychain.write(AuthService.refreshTokenKey, value: token)
            try? keychain.write(AuthService.uidKey, value: uid)
        }
    }
    #endif

    /// Session readiness for deep-link routing — links arriving earlier are stashed and
    /// replayed by `onSignedIn()` / `onProfileReady()`.
    var isReadyForDeepLinks: Bool {
        auth.isSignedIn && isBootstrapped && !userStore.needsProfile
    }

    /// App-launch flow: restore the Keychain session, then run the signed-in boot.
    func start() async {
        await auth.restoreSession()
        if auth.isSignedIn {
            await onSignedIn()
        }
    }

    /// Post-sign-in flow (launch restore AND interactive sign-in): parallel bootstrap of
    /// teams/tournaments/groups (web boot fan-out), `GET /user/me` (404 → profile gate),
    /// live wiring + socket connect, then deep-link replay + push registration — the
    /// latter two only with a completed profile (else deferred to `onProfileReady()`).
    func onSignedIn() async {
        async let teams: Void = teamStore.load()
        async let tournaments: Void = tournamentStore.load()
        async let groups: Void = groupStore.load()
        do {
            _ = try await (teams, tournaments, groups)
            try await userStore.loadMe()
            isBootstrapped = true
            // Cleared only on success so the retry screen stays up while a retry runs.
            bootFailed = false
        } catch {
            bootFailed = true
        }
        // The boot fan-out can outlive the session — a signOut() mid-await already
        // disconnected the socket and detached consumers; don't undo it (and never
        // prompt a signed-out user for push permission).
        guard auth.isSignedIn else { return }
        live.attach(to: socket)
        activityFeed.attach(to: socket)
        socket.connect()
        if isBootstrapped && !userStore.needsProfile {
            router.replayPendingDeepLink()
            await push.registerIfNeeded()
        }
        syncAdminProposalsPolling()
    }

    /// CompleteProfile finished (`needsProfile` flipped false) — run the deferred
    /// post-onboarding work: stashed deep link + push prompt.
    func onProfileReady() async {
        guard auth.isSignedIn else { return }
        router.replayPendingDeepLink()
        await push.registerIfNeeded()
    }

    /// Sign-out: wipe Keychain tokens, close the socket, clear every store.
    func signOut() {
        auth.signOut()
        socket.disconnect()
        live.detach()
        activityFeed.detach()
        activityFeed.clearAll()
        push.resetForSignOut()
        userStore.set(nil)
        groupStore.clear()
        tournamentStore.clear()
        teamStore.clear()
        gameStore.clear()
        betStore.clear()
        router.reset()
        adminProposals.reset()
        isBootstrapped = false
        bootFailed = false
    }

    /// `scenePhase == .active`: validate the token (sign out on an expired session),
    /// reconnect the socket, reload shared data (teams only when empty/stale > 24 h —
    /// `ForegroundRefreshPolicy`). Per-screen data (group bets, messages, visible
    /// tournament details) refreshes in the screens' own scene-phase handlers.
    func onScenePhaseActive() async {
        guard auth.isSignedIn else { return }
        do {
            _ = try await auth.validIDToken()
        } catch let error as AuthError where error == .sessionExpired || error == .notSignedIn {
            signOut()
            return
        } catch {
            // Offline: keep the session — API calls refresh lazily when back online.
        }
        socket.connect()
        try? await groupStore.load()
        try? await tournamentStore.load()
        if ForegroundRefreshPolicy.shouldReloadTeams(isLoaded: teamStore.isLoaded, loadedAt: teamStore.loadedAt) {
            try? await teamStore.load()
        }
        syncAdminProposalsPolling()
    }

    /// Background: close the socket (broadcast-only — nothing is lost that a foreground
    /// refresh doesn't recover).
    func onScenePhaseBackground() {
        socket.disconnect()
        adminProposals.stopPolling()
    }

    /// Raise a toast when the FIFA poller stages new results for review, with a confirm
    /// action that opens the proposals screen.
    private func notifyNewProposals(_ count: Int) {
        toasts.confirm(
            title: "New FIFA results",
            question: "\(count) result\(count == 1 ? "" : "s") ready to review."
        ) { [weak self] in
            self?.router.selectedTab = .profile
            self?.router.profilePath.append(.adminFIFAProposals)
        }
    }

    /// Poll the pending-proposal count for admins (idempotent), or reset it for everyone
    /// else. The count endpoint is admin-guarded, so non-admins never poll it.
    private func syncAdminProposalsPolling() {
        guard auth.isSignedIn, userStore.isAdmin else {
            adminProposals.reset()
            return
        }
        adminProposals.onNewProposals = { [weak self] count in
            self?.notifyNewProposals(count)
        }
        adminProposals.startPolling()
    }
}
