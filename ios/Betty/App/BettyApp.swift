import SwiftUI
import UIKit
import UserNotifications

@main
struct BettyApp: App {
    @UIApplicationDelegateAdaptor(BettyAppDelegate.self) private var delegate
    @State private var env = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .environment(env.theme)
                .environment(env.router)
                .onOpenURL { url in
                    env.router.handle(url: url, isReady: env.isReadyForDeepLinks)
                }
                // Universal links (https://betty.social/dashboard/groups/join/<code>).
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    env.router.handle(url: url, isReady: env.isReadyForDeepLinks)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        Task { await env.onScenePhaseActive() }
                    case .background:
                        env.onScenePhaseBackground()
                    default:
                        break
                    }
                }
                .task {
                    delegate.environment = env
                }
        }
    }
}

/// UIKit bridge: APNs token callbacks and notification-tap deep links. `environment`
/// is wired by `BettyApp` on first render (before any push registration can happen —
/// registration only starts post-onboarding).
final class BettyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var environment: AppEnvironment?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard let push = environment?.push else { return }
        Task { await push.handleDeviceToken(deviceToken) }
    }

    /// Expected on simulators without push support and when the `aps-environment`
    /// entitlement is missing — degrade silently.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        environment?.push.handleRegistrationFailure(error)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Notification tap: honor an embedded deep link, but ONLY through `DeepLink.parse`
    /// (mirrors the web's `safeReturnUrl` strictness — never open arbitrary URLs from
    /// payloads).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let env = environment,
              let raw = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: raw) else { return }
        env.router.handle(url: url, isReady: env.isReadyForDeepLinks)
    }
}
