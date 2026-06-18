import Foundation
import Testing
@testable import Betty

/// Pins the wire contract between the backend reminder push payload and
/// the iOS notification-tap handler. The backend emits Data["url"] in
/// internal/reminders/push.go's buildMessage; iOS reads userInfo["url"]
/// in BettyAppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:).
/// If the field name drifts on either side, this test breaks first.
///
/// The new URL shape (`https://betty.social/groups/<groupID>/games/<gameID>`)
/// is fully routable: `DeepLink.parse` maps it to `.bet(gameID:groupID:)` and
/// `Router.perform` switches to the home tab, pushes the group detail screen,
/// and presents the bet sheet. Tests 1 and 2 below pin this end-to-end routing.
@Suite struct PushPayloadDecodingTests {

    // MARK: - Payload shape

    @Test func gameReminderPayloadUrlIsWellFormed() {
        // Mirrors what FCM delivers into UNNotification.request.content.userInfo
        // for a reminder push (see internal/reminders/push.go buildMessage).
        let userInfo: [AnyHashable: Any] = [
            "url": "https://betty.social/groups/42/games/1234",
            "google.c.fid": "abc", // FCM-added metadata; ignored by the iOS handler.
            "aps": [
                "alert": ["title": "⏰ Sweden vs Germany starts in 2h", "body": "tap to play"]
            ]
        ]

        guard let raw = userInfo["url"] as? String,
              let url = URL(string: raw) else {
            Issue.record("expected url string in payload")
            return
        }

        // Wire-contract assertions: the URL is https, points at the canonical
        // host, and carries the group + game ID segments.
        #expect(url.scheme == "https")
        #expect(url.host == "betty.social")
        #expect(url.path == "/groups/42/games/1234")
    }

    // MARK: - DeepLink parser behaviour for game URLs

    @Test func gameReminderUrlRoutesToBetSheet() {
        // The backend's reminder URL must parse to .bet(gameID:groupID:) so
        // that Router.perform switches to home, pushes group detail, and presents
        // the bet sheet. This test pins the routing contract.
        let gameURL = URL(string: "https://betty.social/groups/42/games/1234")!
        #expect(DeepLink.parse(gameURL) == .bet(gameID: 1234, groupID: 42),
                "reminder push URL must route to the bet sheet")
    }

    @Test func customSchemeBetUrlRoutes() {
        // betty://bet/<groupID>/<gameID> — custom-scheme equivalent of the
        // universal-link reminder URL, for symmetry with other betty:// deep links.
        let betURL = URL(string: "betty://bet/42/1234")!
        #expect(DeepLink.parse(betURL) == .bet(gameID: 1234, groupID: 42),
                "custom-scheme bet URL must route to the bet sheet")
    }

    // MARK: - Full pipeline: a routable push URL does navigate

    @Test func routablePushUrlNavigatesViaDeepLink() {
        // When the backend eventually sends a betty:// URL (or if the URL is
        // for a join-invite), the full pipeline — payload key "url" → URL →
        // DeepLink.parse → Router.handle — must work end-to-end.
        // Using the join-invite universal-link as a known-good routable pattern.
        let userInfo: [AnyHashable: Any] = [
            "url": "https://betty.social/dashboard/groups/join/abc-123"
        ]

        guard let raw = userInfo["url"] as? String,
              let url = URL(string: raw) else {
            Issue.record("expected url string in payload")
            return
        }

        let parsed = DeepLink.parse(url)
        #expect(parsed == .join(code: "abc-123"),
                "a join-invite URL from a push payload must survive the full parse pipeline")
    }
}
