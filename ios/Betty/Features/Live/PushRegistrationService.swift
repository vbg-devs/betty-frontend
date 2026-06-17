import Foundation
import Observation
import UIKit
import UserNotifications
import FirebaseMessaging

/// Firebase Messaging registration + `POST /user/me/add_push_token`.
///
/// Flow: triggered post-onboarding → notification authorization prompt →
/// APNs registration → BettyAppDelegate forwards the APNs token to FCM →
/// FCM issues an FCM registration token → MessagingDelegate fires →
/// token delivered to `handleFCMToken(_:)` → POSTed once per distinct token.
/// Registration failures (simulators without push support, missing
/// `aps-environment` entitlement) degrade silently to `.unavailable`.
@Observable
final class PushRegistrationService: NSObject, MessagingDelegate {
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
        super.init()
        // FirebaseApp.configure() may not have been called yet at init time
        // (e.g. plist missing). Setting the delegate on the singleton is safe
        // either way — if Messaging isn't configured, the delegate never
        // fires.
        Messaging.messaging().delegate = self
    }

    /// Post-onboarding trigger. Repeat calls retry an unsent token; iOS
    /// only shows the system prompt once per install.
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

    /// MessagingDelegate entrypoint exposed for tests. Production code
    /// receives this via `messaging(_:didReceiveRegistrationToken:)`.
    @MainActor
    func handleFCMToken(_ token: String?) async {
        guard let token, !token.isEmpty else { return }
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

    // MARK: - MessagingDelegate

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            await self.handleFCMToken(fcmToken)
        }
    }

    // MARK: - Helpers

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
