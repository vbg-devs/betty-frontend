import Foundation
import Testing
@testable import Betty

private final class PushRecorder {
    var sentTokens: [String] = []
    var authorizationCalls = 0
    var registerCalls = 0
    var grantAuthorization = true
    var sendError: Error?
    /// Simulates the token returned by Messaging.messaging().token { } on the current install.
    var fcmTokenFromCache: String?
}

private struct StubError: Error {}

/// Pins the FCM registration flow: post-onboarding prompt, one POST per
/// distinct token, retry-after-failure, simulator fallback, sign-out reset.
@Suite struct PushRegistrationServiceTests {
    private let recorder = PushRecorder()
    private let defaults: UserDefaults
    private let suiteName = "betty-push-tests-\(UUID().uuidString)"
    private let service: PushRegistrationService

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let recorder = recorder
        service = PushRegistrationService(
            defaults: defaults,
            sendToken: { token in
                if let error = recorder.sendError { throw error }
                recorder.sentTokens.append(token)
            },
            requestAuthorization: {
                recorder.authorizationCalls += 1
                return recorder.grantAuthorization
            },
            registerWithAPNs: { recorder.registerCalls += 1 },
            fetchFCMToken: { recorder.fcmTokenFromCache }
        )
    }

    @Test func grantedAuthorizationRegistersWithAPNs() async {
        await service.registerIfNeeded()

        #expect(recorder.authorizationCalls == 1)
        #expect(recorder.registerCalls == 1)
        #expect(service.phase == .awaitingToken)
    }

    @Test func deniedAuthorizationNeverRegisters() async {
        recorder.grantAuthorization = false

        await service.registerIfNeeded()
        await service.registerIfNeeded() // denied is terminal — no second prompt

        #expect(recorder.authorizationCalls == 1)
        #expect(recorder.registerCalls == 0)
        #expect(service.phase == .denied)
    }

    @Test func fcmTokenIsSentOncePerValue() async {
        await service.handleFCMToken("fcm-token-A")
        await service.handleFCMToken("fcm-token-A") // same token — deduped

        #expect(recorder.sentTokens == ["fcm-token-A"])
        #expect(service.phase == .registered(token: "fcm-token-A"))
    }

    @Test func nilOrEmptyFCMTokenIgnored() async {
        await service.handleFCMToken(nil)
        await service.handleFCMToken("")

        #expect(recorder.sentTokens.isEmpty)
        #expect(service.phase == .idle)
    }

    @Test func changedTokenIsSentAgain() async {
        await service.handleFCMToken("fcm-1")
        await service.handleFCMToken("fcm-2")

        #expect(recorder.sentTokens == ["fcm-1", "fcm-2"])
    }

    @Test func failedSendStaysUnsentAndRetries() async {
        recorder.sendError = StubError()
        await service.handleFCMToken("fcm-X")
        #expect(recorder.sentTokens.isEmpty)

        recorder.sendError = nil
        await service.registerIfNeeded() // registered phase retries the unsent token

        #expect(recorder.sentTokens == ["fcm-X"])
        #expect(recorder.registerCalls == 0) // no re-registration needed
    }

    @Test func registrationFailureIsGracefulAndRetryable() async {
        await service.registerIfNeeded()
        service.handleRegistrationFailure(StubError()) // simulator / missing entitlement

        #expect(service.phase == .unavailable)

        await service.registerIfNeeded() // a later attempt may retry
        #expect(recorder.registerCalls == 2)
    }

    @Test func signOutResetResendsForTheNextAccount() async {
        recorder.fcmTokenFromCache = "fcm-X"
        await service.registerIfNeeded()   // user A: auth + APNs kick-off + cache fetch → POST
        service.resetForSignOut()
        #expect(service.phase == .idle)

        // User B signs in on the same install — same FCM token, but the sent
        // marker was cleared so registerIfNeeded must POST again.
        await service.registerIfNeeded()

        #expect(recorder.sentTokens == ["fcm-X", "fcm-X"])
    }

    /// Regression: same install, account switch — FCM delegate never re-fires
    /// because the token is unchanged. registerIfNeeded must fetch the cached
    /// token and POST it for the new user.
    @Test func sameInstallSignInTriggersTokenPostFromCache() async {
        // User A signs in and registers.
        recorder.fcmTokenFromCache = "fcm-A"
        await service.registerIfNeeded()
        #expect(recorder.sentTokens == ["fcm-A"])

        // Sign out — clears the sent-marker, resets phase to .idle.
        service.resetForSignOut()

        // User B signs in on the same device — FCM token is still "fcm-A"
        // (same install, same token identifier). The delegate will NOT fire.
        // registerIfNeeded must explicitly fetch and POST the cached token.
        recorder.fcmTokenFromCache = "fcm-A"
        await service.registerIfNeeded()

        #expect(recorder.sentTokens == ["fcm-A", "fcm-A"])
    }
}
