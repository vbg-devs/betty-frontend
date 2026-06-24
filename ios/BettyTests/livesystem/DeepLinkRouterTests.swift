import Foundation
import Testing
@testable import Betty

/// Pins deep-link parsing strictness (mirrors the web's `safeReturnUrl` — only known
/// patterns, validated invite codes) and the stash-while-signed-out / replay-once flow.
@Suite struct DeepLinkRouterTests {
    // MARK: - Parsing

    @Test func universalInviteLinkParses() {
        let url = URL(string: "https://betty.social/dashboard/groups/join/ab-12-CD")!
        #expect(DeepLink.parse(url) == .join(code: "ab-12-CD"))
    }

    @Test func wrongHostIsRejected() {
        let url = URL(string: "https://evil.com/dashboard/groups/join/abc")!
        #expect(DeepLink.parse(url) == nil)
    }

    @Test func customSchemeLinksParse() {
        #expect(DeepLink.parse(URL(string: "betty://join/abc123")!) == .join(code: "abc123"))
        #expect(DeepLink.parse(URL(string: "betty://group/12")!) == .group(id: 12))
        #expect(DeepLink.parse(URL(string: "betty://leaderboard/3")!) == .leaderboard(tournamentID: 3))
        #expect(DeepLink.parse(URL(string: "betty://dashboard")!) == .dashboard)
    }

    @Test func invalidInviteCodesAreRejected() {
        #expect(DeepLink.parse(URL(string: "betty://join/ab$c")!) == nil)
        #expect(DeepLink.parse(URL(string: "betty://join/ab_c")!) == nil)
        #expect(!DeepLink.isValidInviteCode(""))
        #expect(!DeepLink.isValidInviteCode("a b"))
        #expect(DeepLink.isValidInviteCode("A1-b2"))
    }

    @Test func nonNumericIDsAreRejected() {
        #expect(DeepLink.parse(URL(string: "betty://group/abc")!) == nil)
        #expect(DeepLink.parse(URL(string: "betty://leaderboard/x")!) == nil)
    }

    @Test func unknownPatternsAreIgnored() {
        #expect(DeepLink.parse(URL(string: "betty://settings")!) == nil)
        #expect(DeepLink.parse(URL(string: "https://betty.social/dashboard")!) == nil)
        #expect(DeepLink.parse(URL(string: "https://betty.social/dashboard/groups/join")!) == nil)
    }

    // MARK: - Stash & replay (completion after auth + profile)

    @Test func linkWhileNotReadyIsStashedAndReplayedOnce() {
        let router = Router()
        let url = URL(string: "betty://join/abc")!

        router.handle(url: url, isReady: false)
        #expect(router.activeSheet == nil) // nothing performed while signed out
        #expect(router.pendingDeepLink == .join(code: "abc"))

        router.replayPendingDeepLink()
        #expect(router.selectedTab == .home)
        #expect(router.activeSheet == .joinInvite(code: "abc"))
        #expect(router.pendingDeepLink == nil)

        router.activeSheet = nil
        router.replayPendingDeepLink() // second replay is a no-op
        #expect(router.activeSheet == nil)
    }

    @Test func linkWhileReadyPerformsImmediately() {
        let router = Router()
        router.handle(url: URL(string: "betty://group/9")!, isReady: true)

        #expect(router.selectedTab == .home)
        #expect(router.homePath == [.groupDetail(groupID: 9)])
        #expect(router.pendingDeepLink == nil)
    }

    @Test func leaderboardLinkSelectsTournamentAndTab() {
        let router = Router()
        router.handle(url: URL(string: "betty://leaderboard/4")!, isReady: true)

        #expect(router.selectedTab == .leaderboard)
        #expect(router.leaderboardTournamentID == 4)
    }

    @Test func invalidURLNeverStashes() {
        let router = Router()
        router.handle(url: URL(string: "https://evil.com/dashboard/groups/join/abc")!, isReady: false)
        #expect(router.pendingDeepLink == nil)
    }
}
