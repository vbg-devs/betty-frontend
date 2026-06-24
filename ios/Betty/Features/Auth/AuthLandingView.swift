import AuthenticationServices
import SwiftUI

/// Signed-out landing — the web landing page identity (`app/pages/index.vue`) condensed:
/// wordmark, "HOME FOR BRAGGING RIGHTS" hero, the three value props, then the auth modal
/// options. Apple FIRST (App Store 4.8), then Google, then collapsed email/password with
/// a sign-in/sign-up toggle (web parity: the toggle only changes copy + email endpoint).
struct AuthLandingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var showEmailForm = false
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showGoogleNotConfigured = false
    @State private var appleNonce = ""
    @State private var googleFlow = GoogleOAuthFlow()

    private var copy: Copy { Copy.mode(isSignUp: isSignUpMode) }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    hero
                    valuePropsSection
                    authCard
                }
                .padding(Space.m)
                .padding(.bottom, Space.xxl)
            }
        }
        .alert("Google sign-in isn't set up", isPresented: $showGoogleNotConfigured) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This build has no Google OAuth client ID yet — use Apple or email for now. See ios/README.md to configure Google sign-in.")
        }
    }

    // MARK: - Landing identity (web hero + "what is Betty")

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Image("BettyWordmark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .foregroundStyle(theme.mode == .light ? Palette.indigo : theme.colors.textPrimary)
                .padding(.top, Space.xl)

            Text("★ HOME FOR BRAGGING RIGHTS")
                .kicker(Palette.orange)
                .padding(.top, Space.s)

            VStack(alignment: .leading, spacing: 0) {
                (Text("BET WITH\n").foregroundStyle(theme.colors.textPrimary)
                    + Text("FRIENDS.").foregroundStyle(theme.colors.accentPositive))
                    .font(.bettyDisplayL)
                    .displayKerning(40)
                // Web hero outline treatment (`-webkit-text-stroke`).
                OutlinedDisplayText("KEEP SCORE.", size: 40, color: theme.colors.textPrimary)
            }

            Text("Betty handles the math, you handle the banter.")
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    /// Web `.what__points` — pinned by tests.
    struct ValueProp: Identifiable, Equatable {
        let lead: String
        let detail: String
        var id: String { lead }
    }

    static let valueProps: [ValueProp] = [
        ValueProp(lead: "Free forever.", detail: "No paywalls, no ads, no nonsense."),
        ValueProp(lead: "Your house rules.", detail: "Each group sets its own scoring."),
        ValueProp(lead: "Receipts forever.", detail: "Leaderboards remember every call."),
    ]

    private var valuePropsSection: some View {
        BettyInsetPanel {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("A SOCIAL PREDICTIONS GAME")
                    .kicker(theme.colors.textMuted)
                ForEach(Self.valueProps) { prop in
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                        Text("★")
                            .font(.bettyCaption)
                            .foregroundStyle(Palette.orange)
                        (Text(prop.lead + " ").fontWeight(.heavy).foregroundStyle(theme.colors.textPrimary)
                            + Text(prop.detail).foregroundStyle(theme.colors.textSecondary))
                            .font(.bettySubhead)
                    }
                }
            }
        }
    }

    // MARK: - Auth options (web auth modal)

    private var authCard: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.m) {
                Text(copy.pitchKicker)
                    .kicker(Palette.orange)
                Text(copy.pitchTitle)
                    .font(.bettyTitle2)
                    .displayKerning(28)
                    .foregroundStyle(theme.colors.textPrimary)

                SignInWithAppleButton(isSignUpMode ? .signUp : .continue) { request in
                    appleNonce = AppleSignInSupport.randomNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInSupport.sha256Hex(appleNonce)
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(theme.mode == .light ? .black : .white)
                .frame(height: 50)
                .disabled(isBusy)
                .accessibilityIdentifier("auth.landing.appleButton")

                Button(copy.googleTitle) {
                    signInWithGoogle()
                }
                .buttonStyle(.bettyPrimaryBlock)
                .disabled(isBusy)
                .accessibilityIdentifier("auth.landing.googleButton")

                if showEmailForm {
                    emailForm
                } else {
                    Button(copy.emailTitle) {
                        showEmailForm = true
                    }
                    .buttonStyle(BettyButtonStyle(variant: .outline, isBlock: true))
                    .disabled(isBusy)
                    .accessibilityIdentifier("auth.landing.showEmailButton")
                }

                if isBusy {
                    HStack(spacing: Space.xs) {
                        ProgressView()
                            .tint(theme.colors.textPrimary)
                        Text("SIGNING IN…")
                            .kicker(theme.colors.textMuted)
                    }
                }

                if let errorMessage {
                    BettyInsetPanel(accent: Palette.orange) {
                        Text(errorMessage)
                            .font(.bettySubhead)
                            .foregroundStyle(theme.colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("auth.landing.error")
                }

                HStack(spacing: Space.xxs) {
                    Text(copy.togglePrompt)
                        .font(.bettySubhead)
                        .foregroundStyle(theme.colors.textSecondary)
                    Button(copy.toggleAction) {
                        isSignUpMode.toggle()
                        errorMessage = nil
                    }
                    .buttonStyle(.bettyGhost)
                    .disabled(isBusy)
                    .accessibilityIdentifier("auth.landing.toggleModeButton")
                }
            }
        }
    }

    private var emailForm: some View {
        VStack(spacing: Space.s) {
            styledField(
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("auth.landing.emailField")
            )
            styledField(
                SecureField("Password", text: $password)
                    // .newPassword summons the Automatic Strong Password cover view,
                    // which swallows XCUITest typing — suppress it under UI test.
                    .textContentType(isSignUpMode ? (env.isUITest ? nil : .newPassword) : .password)
                    .accessibilityIdentifier("auth.landing.passwordField")
            )
            Button(copy.submitTitle) {
                submitEmail()
            }
            .buttonStyle(.bettyPrimaryBlock)
            .disabled(isBusy || email.isEmpty || password.isEmpty)
            .accessibilityIdentifier("auth.landing.submitButton")
        }
    }

    private func styledField(_ field: some View) -> some View {
        field
            .padding(Space.s)
            .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sharp)
                    .strokeBorder(theme.colors.overlay10, lineWidth: 1)
            }
            .foregroundStyle(theme.colors.textPrimary)
    }

    // MARK: - Actions

    private func submitEmail() {
        if let validation = Self.validationMessage(email: email, password: password, isSignUp: isSignUpMode) {
            errorMessage = validation
            return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        runAuth {
            if isSignUpMode {
                try await env.auth.signUp(email: trimmedEmail, password: password)
            } else {
                try await env.auth.signIn(email: trimmedEmail, password: password)
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Could not read the Apple sign-in response."
                return
            }
            // Apple supplies the full name only on FIRST authorization — capture it now.
            let fullName = credential.fullName.map {
                [$0.givenName, $0.familyName].compactMap(\.self).joined(separator: " ")
            }
            let nonce = appleNonce
            runAuth {
                try await env.auth.signInWithApple(
                    identityToken: identityToken,
                    rawNonce: nonce,
                    fullName: fullName?.isEmpty == false ? fullName : nil
                )
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                return // cancelled — no error surface (web parity)
            }
            errorMessage = "Could not sign you in with Apple. Please try again."
        }
    }

    private func signInWithGoogle() {
        runAuth {
            let idToken = try await googleFlow.signIn()
            try await env.auth.signInWithGoogle(idToken: idToken)
        }
    }

    private func runAuth(_ operation: @escaping @MainActor () async throws -> Void) {
        errorMessage = nil
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await operation()
                await env.onSignedIn()
            } catch AuthError.googleClientIDMissing {
                showGoogleNotConfigured = true
            } catch let error as AuthError {
                errorMessage = Self.friendlyMessage(for: error)
            } catch {
                errorMessage = "Something went wrong. Please try again."
            }
        }
    }

    // MARK: - Pure helpers (pinned by tests)

    /// Mode-dependent labels — the web toggle only swaps copy (and the email endpoint).
    struct Copy: Equatable {
        let pitchKicker: String
        let pitchTitle: String
        let googleTitle: String
        let emailTitle: String
        let submitTitle: String
        let togglePrompt: String
        let toggleAction: String

        static func mode(isSignUp: Bool) -> Copy {
            if isSignUp {
                Copy(
                    pitchKicker: "★ NEW HERE?",
                    pitchTitle: "Create account",
                    googleTitle: "SIGN UP WITH GOOGLE",
                    emailTitle: "SIGN UP WITH EMAIL",
                    submitTitle: "CREATE ACCOUNT →",
                    togglePrompt: "Already have an account?",
                    toggleAction: "Log in"
                )
            } else {
                Copy(
                    pitchKicker: "★ WELCOME BACK",
                    pitchTitle: "Sign in",
                    googleTitle: "CONTINUE WITH GOOGLE",
                    emailTitle: "CONTINUE WITH EMAIL",
                    submitTitle: "SIGN IN →",
                    togglePrompt: "Don't have an account?",
                    toggleAction: "Create one"
                )
            }
        }
    }

    /// Pre-flight form validation. Returns the message to show, or nil when the form may
    /// be submitted. The 6-character minimum mirrors Firebase's WEAK_PASSWORD rule so the
    /// copy matches whether caught locally or by the server (sign-in lets the server
    /// decide — old accounts may predate the rule).
    static func validationMessage(email: String, password: String, isSignUp: Bool) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPlausibleEmail(trimmedEmail) else {
            return "Enter a valid email address."
        }
        guard !password.isEmpty else {
            return "Enter your password."
        }
        if isSignUp && password.count < 6 {
            return "Password should be at least 6 characters."
        }
        return nil
    }

    static func isPlausibleEmail(_ email: String) -> Bool {
        guard !email.isEmpty, !email.contains(" ") else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    /// Identity Toolkit error code → friendly copy; nil = show nothing (user cancelled).
    static func friendlyMessage(for error: AuthError) -> String? {
        switch error {
        case .invalidCredentials: "Wrong email or password."
        case .emailExists: "An account with this email already exists. Try logging in."
        case .weakPassword: "Password should be at least 6 characters."
        case .userDisabled: "This account has been disabled."
        case .tooManyAttempts: "Too many attempts — please wait a moment and try again."
        case .accountExistsWithDifferentProvider: "This email is linked to a different sign-in method."
        case .googleClientIDMissing: "Google sign-in isn't configured yet (see ios/README.md)."
        case .userCancelled: nil
        default: "Could not sign you in. Please try again."
        }
    }
}
