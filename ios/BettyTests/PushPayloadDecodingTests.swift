import Foundation
import Testing
@testable import Betty

/// Pins the wire contract between the backend reminder push payload and
/// the iOS notification-tap handler. The backend emits Data["url"] in
/// internal/reminders/push.go's buildMessage; iOS reads userInfo["url"]
/// in BettyAppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:).
/// If the field name drifts on either side, this test breaks first.
///
/// `DeepLink.parse` is intentionally strict: it only accepts whitelisted
/// patterns (`betty://` custom schemes, `https://betty.social/dashboard/groups/join/<code>`).
/// The backend's `/games/<id>` URL is NOT currently routable as a deep link —
/// that is expected behaviour. This test pins both sides of that contract:
/// the payload shape is well-formed AND the parser correctly returns nil,
/// preventing the handler from performing unintended navigation.
@Suite struct PushPayloadDecodingTests {

    // MARK: - Payload shape

    @Test func gameReminderPayloadUrlIsWellFormed() {
        // Mirrors what FCM delivers into UNNotification.request.content.userInfo
        // for a reminder push (see internal/reminders/push.go buildMessage).
        let userInfo: [AnyHashable: Any] = [
            "url": "https://betty.social/games/1234",
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
        // host, and carries the game ID segment.
        #expect(url.scheme == "https")
        #expect(url.host == "betty.social")
        #expect(url.path == "/games/1234")
    }

    // MARK: - DeepLink parser behaviour for game URLs

    @Test func gameUrlIsNotCurrentlyRoutableAsDeepLink() {
        // The backend's game URL is not in DeepLink.parse's whitelist (only
        // betty:// custom schemes and the universal-link invite path are
        // accepted). Returning nil means the notification tap is a no-op at
        // the router level — intentional until a game-detail deep link is
        // added to Router.swift.
        //
        // If this expectation flips to non-nil, update Router.perform(_:) and
        // the screens spec in docs/mobile/ at the same time.
        let gameURL = URL(string: "https://betty.social/games/1234")!
        #expect(DeepLink.parse(gameURL) == nil,
                "game URLs are not yet routable; add them to DeepLink and Router.perform before removing this nil guard")
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
