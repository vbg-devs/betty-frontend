import SwiftUI

/// Auth gate: restoring → splash, signedOut → AuthLandingView, signedIn → MainTabView
/// (with the blocking complete-profile cover when `GET /user/me` 404'd).
struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        // NOTE: the wire model `Group` shadows SwiftUI.Group module-wide — always
        // qualify the SwiftUI container as `SwiftUI.Group` in this codebase.
        SwiftUI.Group {
            // App-level container identifiers for UI tests ("<area>.<screen>.<element>"
            // convention; feature-level identifiers belong to the feature suites).
            switch env.auth.phase {
            case .restoring:
                SplashView()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("root.splash")
            case .signedOut:
                AuthLandingView()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("root.authLanding")
            case .signedIn:
                if env.bootFailed && !env.isBootstrapped {
                    BootFailedView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("root.bootFailed")
                } else {
                    MainTabView()
                        .fullScreenCover(isPresented: needsProfileBinding) {
                            CompleteProfileView()
                                .interactiveDismissDisabled()
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("root.completeProfile")
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("root.main")
                }
            }
        }
        .preferredColorScheme(env.theme.colorScheme)
        .task {
            await env.start()
        }
        // CompleteProfile finished — replay the stashed deep link + push prompt.
        .onChange(of: env.userStore.needsProfile) { wasNeeded, isNeeded in
            if wasNeeded && !isNeeded {
                Task { await env.onProfileReady() }
            }
        }
        .overlay(alignment: .top) {
            ToastOverlay()
        }
    }

    private var needsProfileBinding: Binding<Bool> {
        Binding(
            get: { env.userStore.needsProfile },
            set: { _ in } // not user-dismissable; cleared by createProfile success
        )
    }
}

struct SplashView: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: Space.l) {
                Image("BettyWordmark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .foregroundStyle(theme.mode == .light ? Palette.indigo : theme.colors.textPrimary)
                ProgressView()
                    .tint(theme.colors.textPrimary)
            }
        }
    }
}

/// Toast host — kept under its scaffold name; the full alert/confirm design lives in
/// `LiveToastHost` (Features/Live).
struct ToastOverlay: View {
    var body: some View {
        LiveToastHost()
    }
}

/// Full-screen recovery when the signed-in bootstrap failed (offline launch, API down):
/// without it, deep links stay stashed and Home is an empty dashboard until relaunch.
/// Retry re-runs the whole `onSignedIn()` boot (idempotent attach/connect).
struct BootFailedView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var isRetrying = false

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: Space.l) {
                Image("BettyWordmark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                    .foregroundStyle(theme.mode == .light ? Palette.indigo : theme.colors.textPrimary)
                Text("Could not load your data")
                    .font(.betty(22, .black))
                    .foregroundStyle(theme.colors.textPrimary)
                Text("Something went wrong while loading Betty. Check your connection and try again.")
                    .font(.betty(15, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    guard !isRetrying else { return }
                    isRetrying = true
                    Task {
                        await env.onSignedIn()
                        isRetrying = false
                    }
                } label: {
                    if isRetrying {
                        ProgressView().tint(.white)
                    } else {
                        Text("Try again")
                    }
                }
                .buttonStyle(BettyButtonStyle(variant: .primary))
                .disabled(isRetrying)
            }
            .padding(.horizontal, Space.xl)
        }
    }
}
