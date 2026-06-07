import XCTest

// E2E coverage for the auth area: signed-out landing, email/password sign-in and
// sign-up through the mock Identity Toolkit, error mapping, the blocking
// complete-profile gate, session restore/expiry, sign-out, and the Apple/Google
// federated buttons up to the OS-process boundary.
//
// KNOWN LIMIT (covered in BettyTests with mocked transport instead): ASAuthorization
// (Apple) and ASWebAuthenticationSession (Google) present out-of-process sheets that
// XCUITest cannot drive, so federated tests stop at the tap → boundary reaction.

// MARK: - Landing: email/password sign-in + sign-up + federated boundaries

final class AuthLandingE2ETests: BettyUITestCase {
    override var seedsAuthentication: Bool { false }

    private var landing: AuthLandingScreen { AuthLandingScreen(app: app) }

    /// Scrolls the auth card into view and opens the collapsed email form.
    private func openEmailForm() {
        scrollTo(landing.showEmailFormButton)
        landing.showEmailFormButton.tap()
        waitFor(landing.emailField)
    }

    private func submitSignIn(email: String, password: String) {
        openEmailForm()
        landing.fillEmailForm(email: email, password: password)
        scrollTo(landing.signInSubmitButton)
        landing.signInSubmitButton.tap()
    }

    private func submitSignUp(email: String, password: String) {
        scrollTo(landing.toggleToSignUp)
        landing.toggleToSignUp.tap()
        openEmailForm()
        landing.fillEmailForm(email: email, password: password)
        scrollTo(landing.createAccountSubmitButton)
        landing.createAccountSubmitButton.tap()
    }

    // MARK: Landing layout

    func testSignedOutLaunchShowsLandingWithAllAuthOptions() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        XCTAssertTrue(staticText(containing: "HOME FOR BRAGGING RIGHTS").exists)
        XCTAssertTrue(staticText(containing: "Free forever.").exists)
        waitFor(landing.appleButton)
        XCTAssertTrue(landing.appleButton.isEnabled)
        XCTAssertTrue(app.buttons["CONTINUE WITH GOOGLE"].exists)
        XCTAssertTrue(app.buttons["CONTINUE WITH EMAIL"].exists)
        // Sign-in copy is the default mode.
        XCTAssertTrue(staticText(containing: "WELCOME BACK").exists)
        XCTAssertTrue(staticText(containing: "Don't have an account?").exists)
        XCTAssertTrue(landing.toggleToSignUp.exists)
        // Email form is collapsed until requested.
        XCTAssertFalse(landing.emailField.exists)
    }

    func testToggleSwapsCopyBetweenSignInAndSignUp() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        scrollTo(landing.toggleToSignUp)
        landing.toggleToSignUp.tap()

        waitFor(app.buttons["SIGN UP WITH GOOGLE"])
        XCTAssertTrue(staticText(containing: "NEW HERE?").exists)
        XCTAssertTrue(staticText(containing: "Create account").exists)
        XCTAssertTrue(app.buttons["SIGN UP WITH EMAIL"].exists)
        XCTAssertTrue(staticText(containing: "Already have an account?").exists)

        waitFor(landing.toggleToSignIn)
        landing.toggleToSignIn.tap()
        waitFor(app.buttons["CONTINUE WITH GOOGLE"])
        XCTAssertTrue(staticText(containing: "WELCOME BACK").exists)
        XCTAssertTrue(app.buttons["CONTINUE WITH EMAIL"].exists)
    }

    // MARK: Email/password sign-in

    func testEmailSignInHappyPathLandsOnHome() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignIn(email: DefaultScenario.currentUserEmail,
                     password: DefaultScenario.currentUserPassword)

        waitFor(element(app, id: "root.main"), timeout: 25)
        waitFor(HomeScreen(app: app).navigationBar, timeout: 15)
        XCTAssertFalse(element(app, id: "root.completeProfile").exists)

        let signIns = backend.requests(method: "POST", pathPrefix: "/v1/accounts:signInWithPassword")
        XCTAssertEqual(signIns.count, 1)
        XCTAssertEqual(signIns.first?.bodyJSON?["email"] as? String, DefaultScenario.currentUserEmail)
        XCTAssertFalse(backend.requests(method: "GET", pathPrefix: "/api/v1/user/me").isEmpty)
    }

    func testEmailSignInWrongPasswordShowsInvalidCredentialsError() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignIn(email: DefaultScenario.currentUserEmail, password: "definitely-wrong")

        waitFor(staticText(containing: "Wrong email or password."), timeout: 15)
        XCTAssertTrue(landing.errorPanel.exists)
        XCTAssertTrue(landing.root.exists)
        XCTAssertFalse(element(app, id: "root.main").exists)
    }

    func testEmailSignInUnknownEmailShowsInvalidCredentialsError() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignIn(email: "ghost@betty.test", password: "secret123")

        // EMAIL_NOT_FOUND maps to the same collapsed copy as INVALID_LOGIN_CREDENTIALS.
        waitFor(staticText(containing: "Wrong email or password."), timeout: 15)
        XCTAssertTrue(landing.root.exists)
    }

    func testEmailSignInUserDisabledShowsDisabledError() {
        backend.http.route("POST", "/v1/accounts:signInWithPassword") { _, _ in
            MockWire.firebaseError("USER_DISABLED")
        }
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignIn(email: DefaultScenario.currentUserEmail,
                     password: DefaultScenario.currentUserPassword)

        waitFor(staticText(containing: "This account has been disabled."), timeout: 15)
        XCTAssertTrue(landing.root.exists)
    }

    func testEmailSignInTooManyAttemptsShowsThrottleError() {
        backend.http.route("POST", "/v1/accounts:signInWithPassword") { _, _ in
            MockWire.firebaseError("TOO_MANY_ATTEMPTS_TRY_LATER")
        }
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignIn(email: DefaultScenario.currentUserEmail,
                     password: DefaultScenario.currentUserPassword)

        waitFor(staticText(containing: "Too many attempts"), timeout: 15)
        XCTAssertTrue(landing.root.exists)
    }

    func testMalformedEmailFailsLocallyWithoutNetworkRequest() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignIn(email: "not-an-email", password: "whatever1")

        waitFor(staticText(containing: "Enter a valid email address."), timeout: 10)
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/v1/accounts:").isEmpty,
                      "local validation must short-circuit before any identity request")
        XCTAssertTrue(landing.root.exists)
    }

    func testEmailSubmitDisabledUntilBothFieldsFilled() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        openEmailForm()

        XCTAssertFalse(landing.signInSubmitButton.isEnabled)
        landing.emailField.tap()
        landing.emailField.typeText(DefaultScenario.currentUserEmail)
        XCTAssertFalse(landing.signInSubmitButton.isEnabled)
        landing.passwordField.tap()
        landing.passwordField.typeText("secret123")
        XCTAssertTrue(landing.signInSubmitButton.isEnabled)
    }

    // MARK: Email/password sign-up

    func testSignUpHappyPathOpensCompleteProfileGate() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignUp(email: AuthFixtures.freshSignupEmail,
                     password: AuthFixtures.freshSignupPassword)

        // New Firebase account has no profile row → GET /user/me 404 → blocking gate.
        let gate = CompleteProfileScreen(app: app)
        waitFor(gate.root, timeout: 25)
        waitFor(gate.title)

        let signUps = backend.requests(method: "POST", pathPrefix: "/v1/accounts:signUp")
        XCTAssertEqual(signUps.count, 1)
        XCTAssertEqual(signUps.first?.bodyJSON?["email"] as? String, AuthFixtures.freshSignupEmail)
    }

    func testSignUpExistingEmailShowsEmailExistsError() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignUp(email: DefaultScenario.currentUserEmail, password: "another-secret-1")

        waitFor(staticText(containing: "An account with this email already exists."), timeout: 15)
        XCTAssertTrue(landing.root.exists)
        XCTAssertFalse(element(app, id: "root.completeProfile").exists)
    }

    func testSignUpShortPasswordFailsLocallyWithoutNetworkRequest() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignUp(email: AuthFixtures.freshSignupEmail, password: "abc")

        waitFor(staticText(containing: "Password should be at least 6 characters."), timeout: 10)
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/v1/accounts:signUp").isEmpty,
                      "the 6-char minimum is enforced locally in sign-up mode")
    }

    func testSignUpServerWeakPasswordMapsToFriendlyCopy() {
        backend.http.route("POST", "/v1/accounts:signUp") { _, _ in
            MockWire.firebaseError("WEAK_PASSWORD : Password should be at least 6 characters")
        }
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignUp(email: AuthFixtures.freshSignupEmail, password: "long-enough-but-rejected")

        waitFor(staticText(containing: "Password should be at least 6 characters."), timeout: 15)
        XCTAssertEqual(backend.requests(method: "POST", pathPrefix: "/v1/accounts:signUp").count, 1,
                       "password passed local validation — the SERVER rejected it")
    }

    func testSignUpThenCompleteProfileFullJourneyLandsOnHome() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        submitSignUp(email: AuthFixtures.freshSignupEmail,
                     password: AuthFixtures.freshSignupPassword)

        let gate = CompleteProfileScreen(app: app)
        waitFor(gate.root, timeout: 25)
        dismissSavePasswordPromptIfPresent()
        waitFor(gate.nameField)
        // The sign-up form's keyboard can still cover the gate — scroll until hittable.
        scrollTo(gate.nameField, in: gate.root)
        gate.nameField.tap()
        gate.nameField.typeText(AuthFixtures.freshSignupName)

        scrollTo(gate.countryPicker, in: gate.root)
        gate.countryPicker.tap()
        waitFor(gate.countryOption("🇸🇪 Sweden"))
        gate.countryOption("🇸🇪 Sweden").tap()

        scrollTo(gate.saveButton, in: gate.root)
        waitFor(gate.saveButton)
        XCTAssertTrue(gate.saveButton.isEnabled)
        gate.saveButton.tap()

        waitForDisappearance(gate.root, timeout: 15)
        waitFor(element(app, id: "root.main"), timeout: 20)
        waitFor(HomeScreen(app: app).navigationBar, timeout: 15)

        let creates = backend.recordedRequests.filter { $0.method == "POST" && $0.path == "/api/v1/user" }
        XCTAssertEqual(creates.count, 1)
        XCTAssertEqual(creates.first?.bodyJSON?["name"] as? String, AuthFixtures.freshSignupName)
        XCTAssertEqual(creates.first?.bodyJSON?["email"] as? String, AuthFixtures.freshSignupEmail)
        let updates = backend.recordedRequests.filter { $0.method == "PUT" && $0.path == "/api/v1/user/me" }
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.bodyJSON?["country"] as? String, "SE")
    }

    // MARK: Federated buttons — OS-process boundary only

    func testAppleSignInButtonTappableToSystemBoundary() {
        launchApp()
        waitFor(landing.root, timeout: 20)
        scrollTo(landing.appleButton)
        XCTAssertTrue(landing.appleButton.isEnabled)
        XCTAssertTrue(landing.appleButton.isHittable)
        landing.appleButton.tap()

        // The ASAuthorization sheet (or its failure) lives in an OS process XCUITest
        // cannot drive. The app must stay alive on the landing screen, and no identity
        // request may fire without a completed authorization.
        XCTAssertTrue(landing.root.exists)
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/v1/accounts:signInWithIdp").isEmpty)
    }

    func testGoogleSignInTapShowsNotConfiguredAlertAtBoundary() {
        // Force the placeholder client ID: the shipped build has a real one, and the
        // configured path ends at the undrivable ASWebAuthenticationSession consent
        // sheet. The not-configured boundary is the in-app alert, pinned here.
        app.launchEnvironment["BETTY_GOOGLE_CLIENT_ID"] = "YOUR_IOS_OAUTH_CLIENT_ID.apps.googleusercontent.com"
        launchApp()
        waitFor(landing.root, timeout: 20)
        scrollTo(landing.googleButton)
        XCTAssertTrue(landing.googleButton.isEnabled)
        landing.googleButton.tap()

        let alert = app.alerts["Google sign-in isn't set up"]
        waitFor(alert, timeout: 10)
        alert.buttons["OK"].tap()
        waitForDisappearance(alert)
        XCTAssertTrue(landing.root.exists)
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/v1/accounts:signInWithIdp").isEmpty)
    }
}

// MARK: - Session restore, expiry, sign-out

final class AuthSessionE2ETests: BettyUITestCase {
    func testSeededRefreshTokenRestoresSessionStraightToHome() {
        launchApp()

        waitFor(element(app, id: "root.main"), timeout: 25)
        waitFor(HomeScreen(app: app).navigationBar, timeout: 15)
        XCTAssertFalse(AuthLandingScreen(app: app).root.exists)
        XCTAssertFalse(element(app, id: "root.completeProfile").exists)

        // Restore = Keychain refresh token exchanged at securetoken; no interactive
        // sign-in endpoints involved.
        let exchanges = backend.requests(method: "POST", pathPrefix: "/v1/token")
        XCTAssertFalse(exchanges.isEmpty)
        XCTAssertEqual(exchanges.first?.bodyForm["refresh_token"],
                       backend.refreshToken(for: DefaultScenario.currentUserID))
        XCTAssertEqual(exchanges.first?.bodyForm["grant_type"], "refresh_token")
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/v1/accounts:").isEmpty)
    }

    func testSessionPersistsAcrossRelaunchWithoutReseeding() {
        // Incomplete profile keeps the post-onboarding push prompt away on the second,
        // non-BETTY_UITEST launch (the OS permission dialog would wedge XCUITest);
        // landing on the complete-profile gate still proves a restored session.
        withScenario { $0.markProfileIncomplete(DefaultScenario.currentUserID) }
        launchApp()
        let gate = CompleteProfileScreen(app: app)
        waitFor(gate.root, timeout: 25)
        let exchangesBefore = backend.requests(method: "POST", pathPrefix: "/v1/token").count

        // Relaunch WITHOUT the BETTY_UITEST wipe/seed: the only way back to a session is
        // the refresh token the app itself persisted in the Keychain.
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "BETTY_UITEST")
        app.launchEnvironment.removeValue(forKey: "BETTY_SEED_REFRESH_TOKEN")
        app.launchEnvironment.removeValue(forKey: "BETTY_SEED_UID")
        app.launch()

        waitFor(gate.root, timeout: 25)
        XCTAssertGreaterThan(backend.requests(method: "POST", pathPrefix: "/v1/token").count,
                             exchangesBefore,
                             "the relaunch must run the securetoken exchange again")
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/v1/accounts:").isEmpty,
                      "no interactive sign-in may happen on restore")
    }

    func testInvalidPersistedRefreshTokenLandsSignedOut() {
        // Seed a refresh token securetoken rejects (INVALID_REFRESH_TOKEN) — the app
        // must wipe the dead session and land on the auth landing screen.
        app.launchEnvironment["BETTY_SEED_REFRESH_TOKEN"] = AuthFixtures.ghostRefreshToken
        app.launchEnvironment["BETTY_SEED_UID"] = AuthFixtures.ghostUID
        app.launch()

        waitFor(AuthLandingScreen(app: app).root, timeout: 25)
        XCTAssertFalse(element(app, id: "root.main").exists)
        XCTAssertFalse(backend.requests(method: "POST", pathPrefix: "/v1/token").isEmpty,
                       "the restore path must have attempted the exchange")
    }

    func testSignOutReturnsToLandingAndClearsKeychain() {
        launchApp()
        let tabs = TabBarScreen(app: app)
        waitFor(tabs.profile, timeout: 25)
        tabs.profile.tap()
        waitFor(ProfileScreen(app: app).navigationBar, timeout: 15)

        let signOutButton = app.buttons["SIGN OUT"]
        scrollTo(signOutButton, maxSwipes: 8)
        signOutButton.tap()
        waitFor(AuthLandingScreen(app: app).root, timeout: 15)

        // Keychain proof: relaunch WITHOUT the BETTY_UITEST wipe/seed. A surviving
        // refresh token would restore the session — landing again proves it was cleared.
        let exchangesBefore = backend.requests(method: "POST", pathPrefix: "/v1/token").count
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "BETTY_UITEST")
        app.launchEnvironment.removeValue(forKey: "BETTY_SEED_REFRESH_TOKEN")
        app.launchEnvironment.removeValue(forKey: "BETTY_SEED_UID")
        app.launch()

        waitFor(AuthLandingScreen(app: app).root, timeout: 25)
        XCTAssertFalse(element(app, id: "root.main").exists)
        XCTAssertEqual(backend.requests(method: "POST", pathPrefix: "/v1/token").count,
                       exchangesBefore,
                       "an empty Keychain must not produce a securetoken exchange")
    }

    func testSignOutThenSignInAsDifferentUserShowsTheirProfile() {
        launchApp() // seeded as Alex
        let tabs = TabBarScreen(app: app)
        waitFor(tabs.profile, timeout: 25)
        tabs.profile.tap()
        waitFor(ProfileScreen(app: app).navigationBar, timeout: 15)
        let signOutButton = app.buttons["SIGN OUT"]
        scrollTo(signOutButton, maxSwipes: 8)
        signOutButton.tap()

        let landing = AuthLandingScreen(app: app)
        waitFor(landing.root, timeout: 15)
        scrollTo(landing.showEmailFormButton)
        landing.showEmailFormButton.tap()
        waitFor(landing.emailField)
        landing.fillEmailForm(email: "casey@betty.test", password: "secret123")
        scrollTo(landing.signInSubmitButton)
        landing.signInSubmitButton.tap()

        waitFor(element(app, id: "root.main"), timeout: 25)
        dismissSavePasswordPromptIfPresent()
        waitFor(tabs.profile, timeout: 15)
        tabs.profile.tap()
        waitFor(app.staticTexts["Casey Friend"], timeout: 15)
    }
}

// MARK: - Complete-profile gate (GET /user/me 404)

final class CompleteProfileE2ETests: BettyUITestCase {
    private var gate: CompleteProfileScreen { CompleteProfileScreen(app: app) }

    /// Seeded launch as Alex with the profile row missing — the gate comes up over Home.
    private func launchIntoGate() {
        withScenario { $0.markProfileIncomplete(DefaultScenario.currentUserID) }
        launchApp()
        waitFor(gate.root, timeout: 25)
        waitFor(gate.title)
    }

    func testIncompleteProfileShowsBlockingGate() {
        launchIntoGate()
        XCTAssertTrue(staticText(containing: "ONE LAST STEP").exists)
        waitFor(gate.saveButton)
        XCTAssertFalse(gate.saveButton.isEnabled, "empty name must disable save")
        // Not user-dismissable (interactiveDismissDisabled).
        gate.root.swipeDown()
        XCTAssertTrue(gate.root.waitForExistence(timeout: 3))
        XCTAssertTrue(gate.title.exists)
    }

    func testSaveDisabledForWhitespaceOnlyName() {
        launchIntoGate()
        gate.nameField.tap()
        gate.nameField.typeText("   ")
        XCTAssertFalse(gate.saveButton.isEnabled, "whitespace-only name must disable save")
        gate.nameField.typeText("Alex")
        XCTAssertTrue(gate.saveButton.isEnabled)
    }

    func testCompleteProfileWithNameAndCountryLandsOnHome() {
        launchIntoGate()
        gate.nameField.tap()
        gate.nameField.typeText("Fresh Alex")

        scrollTo(gate.countryPicker, in: gate.root)
        gate.countryPicker.tap()
        // DefaultScenario countries with the flag-emoji label rule.
        waitFor(gate.countryOption("🇸🇪 Sweden"))
        XCTAssertTrue(gate.countryOption("🇬🇧 United Kingdom").exists)
        XCTAssertTrue(gate.countryOption("🇫🇷 France").exists)
        XCTAssertTrue(gate.countryOption("— Not set —").exists)
        gate.countryOption("🇸🇪 Sweden").tap()

        scrollTo(gate.saveButton, in: gate.root)
        gate.saveButton.tap()
        waitForDisappearance(gate.root, timeout: 15)
        waitFor(element(app, id: "root.main"), timeout: 20)

        let creates = backend.recordedRequests.filter { $0.method == "POST" && $0.path == "/api/v1/user" }
        XCTAssertEqual(creates.count, 1)
        XCTAssertEqual(creates.first?.bodyJSON?["name"] as? String, "Fresh Alex")
        let updates = backend.recordedRequests.filter { $0.method == "PUT" && $0.path == "/api/v1/user/me" }
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.bodyJSON?["name"] as? String, "Fresh Alex")
        XCTAssertEqual(updates.first?.bodyJSON?["country"] as? String, "SE")
    }

    func testCompleteProfileWithoutCountrySkipsCountryUpdate() {
        launchIntoGate()
        gate.nameField.tap()
        gate.nameField.typeText("No Country Alex")
        scrollTo(gate.saveButton, in: gate.root)
        gate.saveButton.tap()

        waitForDisappearance(gate.root, timeout: 15)
        waitFor(element(app, id: "root.main"), timeout: 20)
        XCTAssertEqual(
            backend.recordedRequests.filter { $0.method == "POST" && $0.path == "/api/v1/user" }.count, 1)
        XCTAssertTrue(
            backend.recordedRequests.filter { $0.method == "PUT" && $0.path == "/api/v1/user/me" }.isEmpty,
            "no country picked → PUT /user/me must not fire")
    }

    func testCreateProfileServerErrorKeepsGateUp() {
        withScenario { $0.markProfileIncomplete(DefaultScenario.currentUserID) }
        backend.http.route("POST", "/api/v1/user") { _, _ in .empty(500) }
        launchApp()
        waitFor(gate.root, timeout: 25)

        gate.nameField.tap()
        gate.nameField.typeText("Doomed Save")
        scrollTo(gate.saveButton, in: gate.root)
        gate.saveButton.tap()

        waitFor(staticText(containing: "Something went wrong on our end"), timeout: 15)
        XCTAssertTrue(gate.errorPanel.exists)
        XCTAssertTrue(gate.root.exists, "a failed POST /user must keep the gate up")
    }

    func testCreateProfileAuthFailureShowsSessionExpiredCopy() {
        withScenario { $0.markProfileIncomplete(DefaultScenario.currentUserID) }
        backend.http.route("POST", "/api/v1/user") { _, _ in .empty(401) }
        launchApp()
        waitFor(gate.root, timeout: 25)

        gate.nameField.tap()
        gate.nameField.typeText("Expired Session")
        scrollTo(gate.saveButton, in: gate.root)
        gate.saveButton.tap()

        waitFor(staticText(containing: "Your session expired. Please sign in again."), timeout: 15)
        XCTAssertTrue(gate.root.exists)
    }

    func testCountryUpdateFailureWarnsButCompletesOnboarding() {
        withScenario { $0.markProfileIncomplete(DefaultScenario.currentUserID) }
        backend.http.route("PUT", "/api/v1/user/me") { _, _ in .empty(500) }
        launchApp()
        waitFor(gate.root, timeout: 25)

        gate.nameField.tap()
        gate.nameField.typeText("Warned Alex")
        scrollTo(gate.countryPicker, in: gate.root)
        gate.countryPicker.tap()
        waitFor(gate.countryOption("🇸🇪 Sweden"))
        gate.countryOption("🇸🇪 Sweden").tap()
        scrollTo(gate.saveButton, in: gate.root)
        gate.saveButton.tap()

        // The profile row exists (POST /user succeeded) — the gate comes down and the
        // failed country PUT degrades to a warning toast.
        waitForDisappearance(gate.root, timeout: 15)
        waitFor(element(app, id: "root.main"), timeout: 20)
        waitFor(staticText(containing: "country didn't stick"), timeout: 15)
    }
}
