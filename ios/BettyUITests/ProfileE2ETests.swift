import XCTest

/// Shared plumbing for the Profile-area suites. No test methods here — subclasses below
/// cover the profile tab, the global leaderboard, the static screens, and admin gating.
class ProfileAreaTestCase: BettyUITestCase {
    // MARK: - Navigation

    @discardableResult
    func openProfileTab() -> ProfileEditScreen {
        let tabs = TabBarScreen(app: app)
        waitFor(tabs.profile, timeout: 30)
        tabs.profile.tap()
        let profile = ProfileEditScreen(app: app)
        waitFor(profile.title, timeout: 15)
        return profile
    }

    @discardableResult
    func openLeaderboardTab() -> GlobalLeaderboardPage {
        let tabs = TabBarScreen(app: app)
        waitFor(tabs.leaderboard, timeout: 30)
        tabs.leaderboard.tap()
        let board = GlobalLeaderboardPage(app: app)
        waitFor(board.navigationBar, timeout: 15)
        return board
    }

    /// Profile tab → pushed Support screen.
    func openSupport(from profile: ProfileEditScreen) -> SupportPage {
        scrollTo(profile.supportLink)
        profile.supportLink.tap()
        let support = SupportPage(app: app)
        waitFor(support.navigationBar, timeout: 15)
        return support
    }

    // MARK: - Generic waits

    /// Polls `condition` until true (XCTFails on timeout) — for backend-request and
    /// computed-state assertions that have no single element to wait on.
    @discardableResult
    func waitUntil(_ message: String, timeout: TimeInterval = 10,
                   file: StaticString = #filePath, line: UInt = #line,
                   _ condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in condition() }, object: nil
        )
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("Timed out waiting until \(message)", file: file, line: line)
        }
        return result == .completed
    }

    // MARK: - Backend request assertions

    func apiRequests(method: String, exactPath: String) -> [MockHTTPRequest] {
        backend.recordedRequests.filter { $0.method == method && $0.path == exactPath }
    }

    @discardableResult
    func waitForRequest(method: String, exactPath: String, timeout: TimeInterval = 15,
                        file: StaticString = #filePath, line: UInt = #line) -> MockHTTPRequest? {
        waitUntil("\(method) \(exactPath) reaches the mock backend",
                  timeout: timeout, file: file, line: line) {
            !self.apiRequests(method: method, exactPath: exactPath).isEmpty
        }
        return apiRequests(method: method, exactPath: exactPath).last
    }

    // MARK: - Element helpers

    /// Any element (static text, button, link, ...) whose label contains the fragment.
    func anyElement(containing fragment: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    /// Taps near the trailing edge (cursor lands after the text), deletes the current
    /// value, then types `text`. Append "\n" to dismiss the keyboard afterwards.
    func clearAndType(_ field: XCUIElement, text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        if !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        if !text.isEmpty {
            field.typeText(text)
        }
    }

    /// Name field already prefilled with the loaded profile (proves GET /user/me landed).
    func waitForNamePrefill(_ name: String) {
        waitFor(app.textFields.matching(NSPredicate(
            format: "identifier == 'profile.edit.nameField' AND value == %@", name
        )).firstMatch, timeout: 15)
    }
}

// MARK: - Profile tab: identity, edit form, photo, account actions, links

final class ProfileE2ETests: ProfileAreaTestCase {
    /// §3.9: avatar + name + email header, name/country prefilled from GET /user/me.
    func testProfileShowsUserIdentityAndPrefilledForm() {
        launchApp()
        let profile = openProfileTab()

        waitFor(app.staticTexts["Alex Tester"])
        XCTAssertTrue(app.staticTexts["alex@betty.test"].exists)
        XCTAssertTrue(app.staticTexts["★ ACCOUNT"].exists)

        waitForNamePrefill("Alex Tester")
        waitFor(profile.countryPicker)
        waitUntil("country picker prefills Sweden (country SE)", timeout: 15) {
            let picker = element(self.app, id: "profile.edit.countryPicker")
            let combined = "\(picker.label) \((picker.value as? String) ?? "")"
            return combined.contains("Sweden")
        }
        // No custom photo seeded → no revert button.
        XCTAssertFalse(profile.revertPhotoButton.exists)
    }

    /// PUT /user/me carries ONLY name + country — email is never sent (spec-pinned).
    func testSaveProfileSendsOnlyNameAndCountry() {
        launchApp()
        let profile = openProfileTab()
        waitForNamePrefill("Alex Tester")

        clearAndType(profile.nameField, text: "Alex Updated\n")
        scrollTo(profile.countryPicker)
        profile.pickCountry(containing: "France")
        scrollTo(profile.saveButton)
        profile.saveButton.tap()

        waitFor(app.staticTexts["Profile updated"])

        let puts = apiRequests(method: "PUT", exactPath: "/api/v1/user/me")
        XCTAssertEqual(puts.count, 1, "exactly one PUT /user/me")
        let body = puts.first?.bodyJSON ?? [:]
        XCTAssertEqual(Set(body.keys), ["name", "country"], "only name+country on the wire")
        XCTAssertEqual(body["name"] as? String, "Alex Updated")
        XCTAssertEqual(body["country"] as? String, "FR")

        // The header reflects the response payload.
        waitFor(app.staticTexts["Alex Updated"])
    }

    /// "— Not set —" country → the payload still has the country key, as JSON null.
    func testSaveProfileWithClearedCountrySendsNullCountry() {
        launchApp()
        let profile = openProfileTab()
        waitForNamePrefill("Alex Tester")

        scrollTo(profile.countryPicker)
        profile.pickCountry(containing: "Not set")
        scrollTo(profile.saveButton)
        profile.saveButton.tap()

        waitFor(app.staticTexts["Profile updated"])
        let body = apiRequests(method: "PUT", exactPath: "/api/v1/user/me").last?.bodyJSON ?? [:]
        XCTAssertEqual(Set(body.keys), ["name", "country"])
        XCTAssertEqual(body["name"] as? String, "Alex Tester")
        XCTAssertTrue(body["country"] is NSNull, "cleared country goes out as null")
    }

    /// Save is disabled while the (required) name is empty.
    func testSaveDisabledWhenNameEmpty() {
        launchApp()
        let profile = openProfileTab()
        waitForNamePrefill("Alex Tester")

        clearAndType(profile.nameField, text: "")
        waitUntil("save disables once the name is cleared") {
            !profile.saveButton.isEnabled
        }
        XCTAssertFalse(profile.saveButton.isEnabled)
    }

    /// A failing PUT shows the pinned error toast and no success toast.
    func testSaveProfileFailureShowsErrorToast() {
        backend.api("PUT", "/user/me") { _, _, _, _ in .empty(500) }
        launchApp()
        let profile = openProfileTab()
        waitForNamePrefill("Alex Tester")

        clearAndType(profile.nameField, text: "Alex Failing\n")
        scrollTo(profile.saveButton)
        profile.saveButton.tap()

        waitFor(app.staticTexts["Could not update profile"])
        XCTAssertFalse(app.staticTexts["Profile updated"].exists)
    }

    /// Boundary: tapping the avatar presents the (out-of-process) photo picker sheet.
    func testAvatarTapPresentsPhotoPicker() {
        launchApp()
        let profile = openProfileTab()
        waitFor(profile.avatarButton)
        profile.avatarButton.tap()

        let cancel = app.buttons["Cancel"]
        waitFor(cancel, timeout: 20)
        cancel.tap()
        waitFor(profile.title)
        // Cancelling never starts the upload flow.
        XCTAssertTrue(apiRequests(method: "POST", exactPath: "/api/v1/user/me/profile-image/upload-url").isEmpty)
    }

    /// Full presigned flow against the mock: presign → raw PUT → commit, in order.
    /// Skips (after the boundary assert) if this environment can't drive the picker grid.
    func testAvatarPickedPhotoRunsPresignedUploadFlow() throws {
        launchApp()
        let profile = openProfileTab()
        waitFor(profile.avatarButton)
        profile.avatarButton.tap()
        waitFor(app.buttons["Cancel"], timeout: 20)

        // PHPicker cells surface either as labelled images or collection cells.
        let labelled = app.images.matching(NSPredicate(format: "label CONTAINS[c] 'photo'")).firstMatch
        let cell: XCUIElement
        if labelled.waitForExistence(timeout: 8) {
            cell = labelled
        } else if app.collectionViews.cells.firstMatch.waitForExistence(timeout: 5) {
            cell = app.collectionViews.cells.firstMatch
        } else {
            app.buttons["Cancel"].tap()
            throw XCTSkip("PhotosPicker grid not driveable here — upload covered to the boundary + unit tests")
        }
        // The grid reports cells before the sheet settles — wait for hittability, then
        // coordinate-tap (which doesn't require it) so a slow picker can't fail the tap.
        _ = XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"),
                                            object: cell)],
            timeout: 10)
        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        waitUntil("presign → upload → commit completes", timeout: 45) {
            !self.apiRequests(method: "PUT", exactPath: "/api/v1/user/me/profile-image").isEmpty
        }

        let recorded = backend.recordedRequests
        let presignIndex = recorded.firstIndex {
            $0.method == "POST" && $0.path == "/api/v1/user/me/profile-image/upload-url"
        }
        let uploadIndex = recorded.firstIndex { $0.method == "PUT" && $0.path.hasPrefix("/_upload/") }
        let commitIndex = recorded.firstIndex { $0.method == "PUT" && $0.path == "/api/v1/user/me/profile-image" }
        XCTAssertNotNil(presignIndex, "POST /user/me/profile-image/upload-url observed")
        XCTAssertNotNil(uploadIndex, "raw presigned PUT observed")
        XCTAssertNotNil(commitIndex, "commit PUT /user/me/profile-image observed")
        if let presignIndex, let uploadIndex, let commitIndex {
            XCTAssertLessThan(presignIndex, uploadIndex)
            XCTAssertLessThan(uploadIndex, commitIndex)

            let presignBody = recorded[presignIndex].bodyJSON ?? [:]
            let contentType = presignBody["content_type"] as? String ?? ""
            XCTAssertTrue(["image/jpeg", "image/png", "image/webp", "image/gif"].contains(contentType))
            let contentLength = presignBody["content_length"] as? Int ?? 0
            XCTAssertGreaterThan(contentLength, 0)
            XCTAssertLessThanOrEqual(contentLength, 1_048_576, "client cap is 1 MiB")

            XCTAssertFalse(recorded[uploadIndex].body.isEmpty, "raw upload carries the bytes")

            let commitURL = recorded[commitIndex].bodyJSON?["image_url"] as? String ?? ""
            XCTAssertTrue(
                commitURL.hasPrefix("\(backend.publicAssetBase)/users/\(DefaultScenario.currentUserID)/profile/"),
                "commit uses the presign public_url, got \(commitURL)"
            )
        }

        // A committed custom photo (provider photo absent) reveals the revert button.
        waitFor(profile.revertPhotoButton, timeout: 15)
        XCTAssertFalse(profile.imageErrorPanel.exists)
    }

    /// Revert → DELETE /user/me/profile-image, falls back to the provider photo (none
    /// here) and the button disappears.
    func testRevertPhotoDeletesAndHidesButton() {
        withScenario {
            _ = $0.seedCustomAvatar(userID: DefaultScenario.currentUserID,
                                    publicAssetBase: backend.publicAssetBase)
        }
        launchApp()
        let profile = openProfileTab()

        waitFor(profile.revertPhotoButton)
        profile.revertPhotoButton.tap()

        waitForRequest(method: "DELETE", exactPath: "/api/v1/user/me/profile-image")
        waitForDisappearance(profile.revertPhotoButton)
        XCTAssertFalse(profile.imageErrorPanel.exists)
    }

    /// Appearance picker switches Dark → Light.
    func testAppearanceToggleSwitchesToLight() {
        launchApp()
        let profile = openProfileTab()
        scrollTo(profile.themePicker)

        let light = profile.themePicker.buttons["Light"]
        waitFor(light)
        XCTAssertTrue(profile.themePicker.buttons["Dark"].isSelected, "dark is the default")
        light.tap()
        waitUntil("Light segment becomes selected") { light.isSelected }
    }
}

// MARK: - Profile tab: account actions, links, support, about, privacy

final class ProfileAccountE2ETests: ProfileAreaTestCase {
    /// SIGN OUT clears the session and lands on the auth landing screen.
    func testSignOutReturnsToAuthLanding() {
        launchApp()
        let profile = openProfileTab()
        scrollTo(profile.signOutButton)
        profile.signOutButton.tap()

        waitFor(element(app, id: "root.authLanding"), timeout: 15)
    }

    /// DELETE ACCOUNT asks first; CANCEL keeps the session and never calls the API.
    func testDeleteAccountCancelKeepsSession() {
        launchApp()
        let profile = openProfileTab()
        scrollTo(profile.deleteAccountButton)
        profile.deleteAccountButton.tap()

        waitFor(staticText(containing: "Delete your Betty account?"))
        app.buttons["CANCEL"].tap()
        waitForDisappearance(staticText(containing: "Delete your Betty account?"))

        XCTAssertTrue(profile.title.exists)
        XCTAssertTrue(apiRequests(method: "DELETE", exactPath: "/api/v1/user/me").isEmpty)
    }

    /// Confirming deletes the account (DELETE /user/me) and signs out.
    func testDeleteAccountConfirmDeletesAndSignsOut() {
        launchApp()
        let profile = openProfileTab()
        scrollTo(profile.deleteAccountButton)
        profile.deleteAccountButton.tap()

        waitFor(staticText(containing: "Delete your Betty account?"))
        app.buttons["YES, DO IT →"].tap()

        waitForRequest(method: "DELETE", exactPath: "/api/v1/user/me")
        waitFor(element(app, id: "root.authLanding"), timeout: 15)
    }

    /// Admin gating, negative side: no Admin row for a regular user.
    func testAdminLinkHiddenForNonAdmin() {
        launchApp()
        let profile = openProfileTab()
        scrollTo(profile.aboutLink)

        XCTAssertTrue(profile.supportLink.exists)
        XCTAssertTrue(profile.privacyLink.exists)
        XCTAssertFalse(profile.adminLink.exists, "Admin row must not render for is_admin=false")
    }

    // MARK: - Support

    /// §3.11 ported copy: hero, email card, feature-request form with counter.
    func testSupportScreenRendersPortedCopy() {
        launchApp()
        let profile = openProfileTab()
        let support = openSupport(from: profile)

        waitFor(app.staticTexts["GET IN"])
        XCTAssertTrue(app.staticTexts["TOUCH."].exists)
        XCTAssertTrue(staticText(containing: "Betty's listening").exists)
        XCTAssertTrue(anyElement(containing: "support@betty.social").exists)
        XCTAssertTrue(app.staticTexts["PITCH BETTY AN IDEA."].exists)
        XCTAssertTrue(app.staticTexts["LAST UPDATED · SEPTEMBER 24, 2022"].exists)

        waitFor(support.counter(equals: "5000 LEFT"))
        XCTAssertFalse(support.submitButton.isEnabled, "submit disabled while empty")
    }

    /// POST /feature-requests gets the TRIMMED description; success toast + form clears.
    func testSupportFeatureRequestSubmitsTrimmedTextAndClears() {
        launchApp()
        let profile = openProfileTab()
        let support = openSupport(from: profile)

        waitFor(support.descriptionField)
        // Single padding spaces — a double space would trip the ". " keyboard shortcut.
        support.descriptionField.tap()
        support.descriptionField.typeText(" Add a darts mode ")
        waitFor(support.counter(equals: "4982 LEFT"))
        XCTAssertTrue(support.submitButton.isEnabled)

        scrollTo(support.submitButton)
        support.submitButton.tap()

        waitFor(staticText(containing: "Your idea is in"))
        let posts = apiRequests(method: "POST", exactPath: "/api/v1/feature-requests")
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts.first?.bodyJSON?["description"] as? String, "Add a darts mode",
                       "payload is trimmed")

        waitFor(support.counter(equals: "5000 LEFT")) // cleared on success
    }

    /// A failing POST keeps the typed text and shows the error toast.
    func testSupportFeatureRequestFailureKeepsText() {
        backend.api("POST", "/feature-requests") { _, _, _, _ in .empty(500) }
        launchApp()
        let profile = openProfileTab()
        let support = openSupport(from: profile)

        waitFor(support.descriptionField)
        support.descriptionField.tap()
        support.descriptionField.typeText("Make Betty purr")
        waitFor(support.counter(equals: "4985 LEFT"))

        scrollTo(support.submitButton)
        support.submitButton.tap()

        waitFor(staticText(containing: "Couldn't send that just now"))
        waitFor(support.counter(equals: "4985 LEFT")) // text retained on failure
    }

    // MARK: - About / Privacy

    /// §3.12 ported copy: hero, WHAT/WHO cards, the three steps, the tips.
    func testAboutScreenRendersPortedCopy() {
        launchApp()
        let profile = openProfileTab()
        scrollTo(profile.aboutLink)
        profile.aboutLink.tap()

        waitFor(AboutPage(app: app).navigationBar, timeout: 15)
        waitFor(app.staticTexts["HI, I'M"])
        XCTAssertTrue(app.staticTexts["BETTY."].exists)
        XCTAssertTrue(app.staticTexts["A SOCIAL PREDICTIONS GAME."].exists)
        XCTAssertTrue(app.staticTexts["YOUR SCOREKEEPER."].exists)
        XCTAssertTrue(staticText(containing: "born in Varberg in 2021").exists)
        XCTAssertTrue(app.staticTexts["THREE STEPS. NO FINE PRINT."].exists)
        XCTAssertTrue(app.staticTexts["Make a group"].exists)
        XCTAssertTrue(app.staticTexts["Lock the bets"].exists)
        XCTAssertTrue(app.staticTexts["Climb the board"].exists)
        XCTAssertTrue(app.staticTexts["GETTING THE MOST OUT OF BETTY."].exists)
        XCTAssertTrue(staticText(containing: "Invite early.").exists)
    }

    /// Privacy renders the ported policy in a sheet; Done dismisses back to the form.
    func testPrivacySheetRendersPolicyAndDismisses() {
        launchApp()
        let profile = openProfileTab()
        scrollTo(profile.privacyLink)
        profile.privacyLink.tap()

        let privacy = PrivacyPage(app: app)
        waitFor(privacy.navigationBar, timeout: 15)
        waitFor(app.staticTexts["PRIVACY"])
        XCTAssertTrue(app.staticTexts["POLICY."].exists)
        XCTAssertTrue(app.staticTexts["★ THE FINE PRINT"].exists)
        XCTAssertTrue(app.staticTexts["LAST UPDATED · SEPTEMBER 24, 2022"].exists)
        XCTAssertTrue(app.staticTexts["INTERPRETATION AND DEFINITIONS"].exists)
        XCTAssertTrue(staticText(containing: "Country refers to: Sweden").exists)
        XCTAssertTrue(staticText(containing: "named Betty Social").exists)
        XCTAssertTrue(staticText(containing: "privacy@betty.social").exists)

        privacy.doneButton.tap()
        waitForDisappearance(privacy.navigationBar)
        waitFor(profile.title)
    }
}

// MARK: - Global leaderboard (incl. per-tournament)

final class ProfileLeaderboardE2ETests: ProfileAreaTestCase {
    /// §3.7: defaults to the running tournament, dense-ranks best normalized score per
    /// user across all its groups, highlights YOU, ignores nicknames, asks for limit=100.
    func testDefaultsToRunningTournamentStandings() {
        launchApp()
        let board = openLeaderboardTab()

        waitFor(app.staticTexts["EURO CUP"], timeout: 15)
        XCTAssertTrue(app.staticTexts["2026"].exists, "3-word title splits ceil(n/2)/rest")
        XCTAssertTrue(staticText(containing: "Normalized score:").exists)

        waitFor(board.playerCount(equals: "3"), timeout: 15)
        XCTAssertTrue(app.staticTexts["PLAYERS · CHASING"].exists)

        // Best per user: robin 7 (Sunday Legends) > alex 5 > casey 4 (Office Royale).
        waitFor(board.row(userID: DefaultScenario.rivalUserID))
        XCTAssertEqual(board.rowOrder(), [
            DefaultScenario.rivalUserID,
            DefaultScenario.currentUserID,
            DefaultScenario.friendUserID,
        ])

        // Global rows use the account name, never the group nickname.
        XCTAssertTrue(app.staticTexts["Robin Rival"].exists)
        XCTAssertFalse(app.staticTexts["The Oracle"].exists)

        XCTAssertTrue(board.row(userID: DefaultScenario.currentUserID).staticTexts["YOU"].exists)
        XCTAssertFalse(board.row(userID: DefaultScenario.rivalUserID).staticTexts["YOU"].exists)

        XCTAssertTrue(board.row(userID: DefaultScenario.rivalUserID).staticTexts["01"].exists)
        XCTAssertTrue(board.row(userID: DefaultScenario.rivalUserID).staticTexts["7"].exists)
        XCTAssertTrue(board.row(userID: DefaultScenario.currentUserID).staticTexts["02"].exists)
        XCTAssertTrue(board.row(userID: DefaultScenario.friendUserID).staticTexts["03"].exists)

        let requests = backend.requests(method: "GET", pathPrefix: "/api/v1/tournament/1/leaderboard")
        XCTAssertFalse(requests.isEmpty)
        XCTAssertEqual(requests.last?.query["limit"], "100")
    }

    /// Per-tournament: the picker (ended → "· ENDED") swaps the standings and refetches.
    func testSwitchesToEndedTournamentViaPicker() {
        launchApp()
        let board = openLeaderboardTab()
        waitFor(board.playerCount(equals: "3"), timeout: 15)

        board.pickTournament(containing: "Legacy League · ENDED")

        waitFor(app.staticTexts["LEGACY LEAGUE"], timeout: 15)
        waitFor(board.playerCount(equals: "2"))
        XCTAssertEqual(board.rowOrder(), [
            DefaultScenario.currentUserID,  // 9 in Wrapped Winners
            DefaultScenario.friendUserID,   // 6
        ])
        XCTAssertTrue(board.row(userID: DefaultScenario.currentUserID).staticTexts["YOU"].exists)
        XCTAssertTrue(board.row(userID: DefaultScenario.currentUserID).staticTexts["9"].exists)

        let requests = backend.requests(method: "GET", pathPrefix: "/api/v1/tournament/2/leaderboard")
        XCTAssertFalse(requests.isEmpty)
        XCTAssertEqual(requests.last?.query["limit"], "100")
    }

    /// Fetch failure → error copy + RETRY, which reloads once the backend recovers.
    func testErrorStateOffersWorkingRetry() {
        backend.api("GET", "/tournament/:id/leaderboard") { _, _, _, _ in .empty(500) }
        launchApp()
        let board = openLeaderboardTab()

        waitFor(board.errorText, timeout: 15)
        waitFor(board.retryButton)

        backend.api("GET", "/tournament/:id/leaderboard") { _, _, _, _ in
            .json([[
                "user_id": DefaultScenario.currentUserID,
                "name": "Alex Tester",
                "nickname": NSNull(),
                "image_url": NSNull(),
                "score": 0,
                "normalized_score": 5,
                "access_level": 0,
            ] as [String: Any]])
        }
        board.retryButton.tap()

        waitFor(board.row(userID: DefaultScenario.currentUserID), timeout: 15)
        waitFor(board.playerCount(equals: "1"))
        XCTAssertFalse(board.errorText.exists)
    }

    /// An empty payload shows the empty-board copy (and a 0 player count).
    func testEmptyStandingsShowEmptyState() {
        backend.api("GET", "/tournament/:id/leaderboard") { _, _, _, _ in .json([Any]()) }
        launchApp()
        let board = openLeaderboardTab()

        waitFor(board.emptyText, timeout: 15)
        waitFor(board.playerCount(equals: "0"))
        XCTAssertFalse(board.errorText.exists)
    }

    /// Scores print the raw JSON number: 7.5 keeps the fraction, 5 has no decimal point.
    func testScoresRenderRawNumbers() {
        withScenario {
            $0.profileSetNormalizedScore(groupID: DefaultScenario.groupSundayLegendsID,
                                  userID: DefaultScenario.rivalUserID, to: 7.5)
        }
        launchApp()
        let board = openLeaderboardTab()

        waitFor(board.playerCount(equals: "3"), timeout: 15)
        XCTAssertTrue(board.row(userID: DefaultScenario.rivalUserID).staticTexts["7.5"].exists)
        XCTAssertTrue(board.row(userID: DefaultScenario.currentUserID).staticTexts["5"].exists)
        XCTAssertFalse(board.row(userID: DefaultScenario.currentUserID).staticTexts["5.0"].exists)
    }

    /// Server-side score changes re-rank the board on the next load (tournament
    /// round-trip forces the refetch deterministically).
    func testReflectsServerSideChangeAfterReload() {
        launchApp()
        let board = openLeaderboardTab()
        waitFor(board.playerCount(equals: "3"), timeout: 15)
        XCTAssertEqual(board.rowOrder(), [
            DefaultScenario.rivalUserID,
            DefaultScenario.currentUserID,
            DefaultScenario.friendUserID,
        ])

        // Casey's Office Royale score jumps to 6 server-side → new best beats Alex's 5.
        withScenario {
            $0.profileSetNormalizedScore(groupID: DefaultScenario.groupOfficeRoyaleID,
                                  userID: DefaultScenario.friendUserID, to: 6)
        }
        board.pickTournament(containing: "Legacy League · ENDED")
        waitFor(board.playerCount(equals: "2"), timeout: 15)
        board.pickTournament(containing: "Euro Cup 2026")
        waitFor(board.playerCount(equals: "3"), timeout: 15)

        waitUntil("standings re-rank after the server-side change") {
            board.rowOrder() == [
                DefaultScenario.rivalUserID,
                DefaultScenario.friendUserID,
                DefaultScenario.currentUserID,
            ]
        }
    }
}

// MARK: - Admin gating (positive side — launched as the admin user)

final class ProfileAdminE2ETests: ProfileAreaTestCase {
    override var seededUserID: String { DefaultScenario.adminUserID }

    /// §3.10: the Admin row renders for is_admin=true and opens the evaluate screen,
    /// which lists only RUNNING tournaments.
    func testAdminLinkVisibleAndOpensEvaluateScreen() {
        launchApp()
        let profile = openProfileTab()

        waitFor(app.staticTexts["Betty Admin"])
        XCTAssertTrue(app.staticTexts["admin@betty.test"].exists)

        scrollTo(profile.adminLink)
        profile.adminLink.tap()

        let admin = AdminPage(app: app)
        waitFor(admin.navigationBar, timeout: 15)
        waitFor(admin.heroTitle)
        XCTAssertTrue(app.staticTexts["PICK A TOURNAMENT."].exists)
        waitFor(app.staticTexts["Euro Cup 2026"], timeout: 15)
        XCTAssertFalse(app.staticTexts["Legacy League"].exists, "ended tournaments are not evaluable")
    }
}
