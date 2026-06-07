import Foundation
import Testing
@testable import Betty

private final class PushRecorder {
    var sentTokens: [String] = []
    var authorizationCalls = 0
    var registerCalls = 0
    var grantAuthorization = true
    var sendError: Error?
}

private struct StubError: Error {}

/// Pins the APNs registration flow: post-onboarding prompt, hex token encoding, one POST
/// per distinct token, retry-after-failure, simulator fallback, sign-out reset.
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
            registerWithAPNs: { recorder.registerCalls += 1 }
        )
    }

    @Test func hexTokenEncoding() {
        #expect(PushRegistrationService.hexToken(from: Data([0x00, 0xAB, 0xFF])) == "00abff")
        #expect(PushRegistrationService.hexToken(from: Data()) == "")
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

    @Test func deviceTokenIsSentOncePerValue() async {
        await service.handleDeviceToken(Data([0x01, 0x02]))
        await service.handleDeviceToken(Data([0x01, 0x02])) // same token — deduped

        #expect(recorder.sentTokens == ["0102"])
        #expect(service.phase == .registered(token: "0102"))
    }

    @Test func changedTokenIsSentAgain() async {
        await service.handleDeviceToken(Data([0x01]))
        await service.handleDeviceToken(Data([0x02]))

        #expect(recorder.sentTokens == ["01", "02"])
    }

    @Test func failedSendStaysUnsentAndRetries() async {
        recorder.sendError = StubError()
        await service.handleDeviceToken(Data([0x0A]))
        #expect(recorder.sentTokens.isEmpty)

        recorder.sendError = nil
        await service.registerIfNeeded() // registered phase retries the unsent token

        #expect(recorder.sentTokens == ["0a"])
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
        await service.handleDeviceToken(Data([0x01]))
        service.resetForSignOut()
        #expect(service.phase == .idle)

        await service.handleDeviceToken(Data([0x01]))

        #expect(recorder.sentTokens == ["01", "01"])
    }
}
