import Foundation
import Observation
import UIKit
import UserNotifications

/// APNs registration + `POST /user/me/add_push_token`.
///
/// Flow: triggered post-onboarding (signed in WITH a completed profile — never at first
/// launch, per the screens spec) → notification authorization prompt → APNs registration
/// → token delivered through `BettyAppDelegate` → POSTed once per distinct token (resends
/// after sign-out). Registration failures (simulators without push support, missing
/// `aps-environment` entitlement) degrade silently to `.unavailable` — no UI, no retry
/// loop.
///
/// NOTE: the backend stores the token for FCM delivery, so a raw APNs token is accepted
/// but dormant until an FCM bridge exists server-side (api-contract 3.2). Registering
/// anyway is the agreed behavior.
@Observable
final class PushRegistrationService {
    enum Phase: Equatable {
        case idle
        case denied
        case awaitingToken
        case registered(token: String)
        /// APNs registration failed (e.g. simulator) — graceful no-op.
        case unavailable
    }

    static let sentTokenDefaultsKey = "betty:push-token-sent"

    private(set) var phase: Phase = .idle

    private let defaults: UserDefaults
    private let sendToken: @MainActor (String) async throws -> Void
    private let requestAuthorization: @MainActor () async -> Bool
    private let registerWithAPNs: @MainActor () -> Void

    init(defaults: UserDefaults = .standard,
         sendToken: @escaping @MainActor (String) async throws -> Void,
         requestAuthorization: @escaping @MainActor () async -> Bool = PushRegistrationService.systemRequestAuthorization,
         registerWithAPNs: @escaping @MainActor () -> Void = { UIApplication.shared.registerForRemoteNotifications() }) {
        self.defaults = defaults
        self.sendToken = sendToken
        self.requestAuthorization = requestAuthorization
        self.registerWithAPNs = registerWithAPNs
    }

    /// Post-onboarding trigger (every sign-in with a complete profile). Repeat calls
    /// retry an unsent token; iOS only shows the system prompt once per install.
    func registerIfNeeded() async {
        switch phase {
        case .denied, .awaitingToken:
            return
        case .registered(let token):
            await sendIfUnsent(token)
        case .idle, .unavailable:
            guard await requestAuthorization() else {
                phase = .denied
                return
            }
            phase = .awaitingToken
            registerWithAPNs()
        }
    }

    /// `didRegisterForRemoteNotificationsWithDeviceToken` — hex-encodes and POSTs the
    /// token. A failed send stays unsent so the next sign-in/registration retries.
    func handleDeviceToken(_ deviceToken: Data) async {
        let token = Self.hexToken(from: deviceToken)
        phase = .registered(token: token)
        await sendIfUnsent(token)
    }

    /// `didFailToRegisterForRemoteNotificationsWithError` — expected on simulators.
    func handleRegistrationFailure(_ error: Error) {
        phase = .unavailable
    }

    /// Sign-out wipes the sent marker so the next account re-POSTs its token.
    func resetForSignOut() {
        defaults.removeObject(forKey: Self.sentTokenDefaultsKey)
        phase = .idle
    }

    nonisolated static func hexToken(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private func sendIfUnsent(_ token: String) async {
        guard defaults.string(forKey: Self.sentTokenDefaultsKey) != token else { return }
        do {
            try await sendToken(token)
            defaults.set(token, forKey: Self.sentTokenDefaultsKey)
        } catch {
            // Offline / API failure: token stays unsent; retried on the next sign-in.
        }
    }

    private static func systemRequestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }
}
