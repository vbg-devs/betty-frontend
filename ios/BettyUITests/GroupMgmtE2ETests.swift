import XCTest

// E2E coverage for the group-management area (Features/GroupManagement):
// public-group browse (cursor pagination, search, tournament filter, join outcomes),
// create-group full form, join-by-code via the betty://join/<code> deep link
// (happy / 404 / 409 / 403), author-only group settings, leave group, and the
// invite ShareLink.
//
// KNOWN LIMIT pinned here: the universal link (https://betty.social/...) requires
// associated-domain validation the simulator can't do — only the betty:// scheme is
// driven e2e; DeepLink.parse for the https form is unit-test territory.

// MARK: - Shared helpers

class GroupMgmtTestCase: BettyUITestCase {
    var tabs: TabBarScreen { TabBarScreen(app: app) }
    var toast: ToastBar { ToastBar(app: app) }

    /// Opens the Browse tab and waits for the public-groups screen to load.
    func openBrowse() {
        waitFor(tabs.browse, timeout: 30)
        tabs.browse.tap()
        waitFor(BrowseGroupsPage(app: app).openGroupsTitle, timeout: 15)
    }

    /// Taps a Home group card and waits for the group-detail hero.
    func openGroupDetail(named name: String) {
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        scrollTo(home.groupCard(named: name), maxSwipes: 8).tap()
        waitFor(staticText(containing: "YOUR GROUP"), timeout: 15)
    }

    /// Author path into the settings sheet: detail → house rules → EDIT →.
    func openSundayLegendsSettings() {
        openGroupDetail(named: "Sunday Legends")
        scrollTo(app.buttons["EDIT →"], maxSwipes: 14).tap()
        waitFor(GroupSettingsPage(app: app).editTitle, timeout: 10)
    }

    /// Fires the join deep link at the already-running app.
    func openJoinDeepLink(code: String) {
        XCUIDevice.shared.system.open(URL(string: "betty://join/\(code)")!)
    }

    /// Types into an empty field.
    func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    /// Replaces a short pre-filled value. The focus hand-off tap sometimes leaves the
    /// caret at index 0 (deletes clear nothing, typing prepends) and double-tap word
    /// selection misses just as unreliably — so clear-and-retype in a verify loop:
    /// park the caret at the trailing edge of the (now stably focused) field, delete
    /// everything, retype, and read the value back until it matches.
    func replaceText(in field: XCUIElement, with text: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        field.tap()
        for _ in 0..<3 {
            if (field.value as? String) == text { return }
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            let current = (field.value as? String) ?? ""
            if !current.isEmpty {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1))
            }
            field.typeText(text)
            if (field.value as? String) == text { return }
        }
        XCTAssertEqual(field.value as? String, text,
                       "replaceText never settled on the new value", file: file, line: line)
    }

    /// SwiftUI Toggle rows expose one full-row Switch whose center is the label — tap
    /// the nested switch control when present, else aim at the trailing edge.
    func tapToggle(_ toggle: XCUIElement) {
        let control = toggle.switches.firstMatch
        if control.exists, control.isHittable {
            control.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
    }

    /// Deadline-polled wait on backend-side state (recorded requests / scenario).
    @discardableResult
    func waitUntilBackend(timeout: TimeInterval = 10,
                          file: StaticString = #filePath, line: UInt = #line,
                          _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        if !condition() {
            XCTFail("Timed out waiting for backend condition", file: file, line: line)
            return false
        }
        return true
    }

    /// The UIActivityViewController sheet ("ActivityListView" container; the settings
    /// sheet's own Close button predates it, so look for share-sheet-only elements).
    func waitForShareSheet(timeout: TimeInterval = 15,
                           file: StaticString = #filePath, line: UInt = #line) {
        let activityList = app.otherElements["ActivityListView"]
        let copyAction = app.buttons["Copy"]
        let copyCell = app.cells.staticTexts["Copy"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if activityList.exists || copyAction.exists || copyCell.exists { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("Share sheet did not appear", file: file, line: line)
    }
}

// MARK: - Browse public groups

final class GroupBrowseE2ETests: GroupMgmtTestCase {
    override func makeScenario() -> MockScenario { GroupMgmtFixtures.browseScenario() }

    /// Spec 3.4: result cards carry tournament kicker, member count, points meta and a
    /// BET HERE → action; joining answers `{group_id}` and the confirm navigates into
    /// the group.
    func testJoinPublicGroupFromBrowse() {
        launchApp()
        openBrowse()
        let browse = BrowseGroupsPage(app: app)

        scrollTo(browse.joinButton(DefaultScenario.groupPublicID), maxSwipes: 8)
        XCTAssertTrue(browse.groupName("Open Arena").exists)
        XCTAssertTrue(staticText(containing: "EURO CUP 2026").exists)
        XCTAssertTrue(staticText(containing: "2 MEMBERS").exists)
        XCTAssertTrue(staticText(containing: "1 / 3 PTS").exists)

        browse.joinButton(DefaultScenario.groupPublicID).tap()
        waitFor(toast.message(containing: "You are now a proud member of Open Arena"), timeout: 10)
        toast.confirmYesButton.tap()

        waitFor(staticText(containing: "YOUR GROUP"), timeout: 15)
        XCTAssertTrue(staticText(containing: "OPEN ARENA").exists)
        let joins = backend.requests(method: "POST",
                                     pathPrefix: "/api/v1/group/\(DefaultScenario.groupPublicID)/join")
        XCTAssertEqual(joins.count, 1)
    }

    /// Spec 3.4 + contract: `GET /groups/public` cursor pagination — scrolling the list
    /// pulls page 2 (and 3) from the mock with the cursor echoed back.
    func testCursorPaginationLoadsNextPagesOnScroll() {
        backend.installPaginatedPublicGroups(pageSize: 4)
        launchApp()
        openBrowse()
        let browse = BrowseGroupsPage(app: app)

        // Page 3 content only exists after two cursor fetches.
        scrollTo(browse.groupName(GroupMgmtFixtures.arenaClubName(8)), maxSwipes: 16)

        let pages = backend.requests(method: "GET", pathPrefix: "/api/v1/groups/public")
        XCTAssertGreaterThanOrEqual(pages.count, 3)
        XCTAssertTrue(pages.contains { $0.query["cursor"] == "4" }, "missing page-2 cursor fetch")
        XCTAssertTrue(pages.contains { $0.query["cursor"] == "8" }, "missing page-3 cursor fetch")
    }

    /// Spec 3.4: debounced search narrows results server-side; no matches shows the
    /// NO MATCHES empty state whose CTA opens the create-group sheet.
    func testSearchFiltersAndEmptyStateOpensCreateSheet() {
        launchApp()
        openBrowse()
        let browse = BrowseGroupsPage(app: app)

        type("Open", into: browse.searchField)
        waitUntilBackend {
            backend.requests(method: "GET", pathPrefix: "/api/v1/groups/public")
                .contains { $0.query["q"] == "Open" }
        }
        waitFor(browse.card(DefaultScenario.groupPublicID), timeout: 10)
        waitForDisappearance(browse.groupName(GroupMgmtFixtures.arenaClubName(1)), timeout: 10)

        replaceText(in: browse.searchField, with: "zzz")
        waitFor(browse.nothingHereTitle, timeout: 10)
        scrollTo(browse.startGroupCTA, maxSwipes: 6).tap()
        waitFor(CreateGroupPage(app: app).formTitle, timeout: 10)
    }

    /// Spec 3.4: tournament filter (running tournaments) narrows the list and is sent
    /// as `tournament_id`.
    func testTournamentFilterNarrowsResults() {
        launchApp()
        openBrowse()
        let browse = BrowseGroupsPage(app: app)

        browse.tournamentFilter.tap()
        waitFor(browse.filterOption("Spring Invitational"), timeout: 10).tap()

        waitFor(browse.card(GroupMgmtFixtures.springGroupID), timeout: 10)
        waitForDisappearance(browse.card(DefaultScenario.groupPublicID), timeout: 10)
        waitUntilBackend {
            backend.requests(method: "GET", pathPrefix: "/api/v1/groups/public")
                .contains { $0.query["tournament_id"] == "\(GroupMgmtFixtures.springTournamentID)" }
        }
    }

    /// Spec 3.4 join errors: 409 already member → info toast and the row flips to
    /// member (OPEN GROUP →).
    func testJoinConflictMarksRowAsMember() {
        launchApp()
        openBrowse()
        let browse = BrowseGroupsPage(app: app)
        scrollTo(browse.joinButton(DefaultScenario.groupPublicID), maxSwipes: 8)

        // Server-side: someone joined us to the group after the list rendered.
        withScenario {
            $0.updateGroup(DefaultScenario.groupPublicID) {
                $0.members.append(MockMember(userID: DefaultScenario.currentUserID, accessLevel: 2))
            }
        }
        browse.joinButton(DefaultScenario.groupPublicID).tap()

        waitFor(toast.message(containing: "You are already a member of Open Arena"), timeout: 10)
        waitFor(browse.openButton(DefaultScenario.groupPublicID), timeout: 10)
        XCTAssertTrue(staticText(containing: "✓ MEMBER").exists)
    }

    /// Spec 3.4 join errors: 403 blocked → "You have been blocked from {name}".
    func testJoinBlockedShowsBlockedToast() {
        withScenario {
            $0.updateGroup(DefaultScenario.groupPublicID) {
                $0.members.append(MockMember(userID: DefaultScenario.currentUserID,
                                             accessLevel: 2, status: .blocked))
            }
        }
        launchApp()
        openBrowse()
        let browse = BrowseGroupsPage(app: app)

        scrollTo(browse.joinButton(DefaultScenario.groupPublicID), maxSwipes: 8).tap()
        waitFor(toast.message(containing: "You have been blocked from Open Arena"), timeout: 10)
        XCTAssertTrue(staticText(containing: "Cannot bet here").exists)
    }

    /// Spec 3.4 join errors: 404 no longer public → row removed from the list.
    func testJoinGoneRemovesRowFromList() {
        launchApp()
        openBrowse()
        let browse = BrowseGroupsPage(app: app)
        scrollTo(browse.joinButton(DefaultScenario.groupPublicID), maxSwipes: 8)

        withScenario {
            $0.updateGroup(DefaultScenario.groupPublicID) { $0.publicAt = nil }
        }
        browse.joinButton(DefaultScenario.groupPublicID).tap()

        waitFor(toast.message(containing: "This group is no longer public"), timeout: 10)
        waitForDisappearance(browse.card(DefaultScenario.groupPublicID), timeout: 10)
    }

    /// Spec 3.4: `is_member` rows show ✓ MEMBER and OPEN GROUP → navigates straight in.
    func testMemberRowOpensGroupDetail() {
        withScenario {
            $0.updateGroup(DefaultScenario.groupPublicID) {
                $0.members.append(MockMember(userID: DefaultScenario.currentUserID, accessLevel: 2))
            }
        }
        launchApp()
        openBrowse()
        let browse = BrowseGroupsPage(app: app)

        scrollTo(browse.openButton(DefaultScenario.groupPublicID), maxSwipes: 8)
        XCTAssertTrue(staticText(containing: "✓ MEMBER").exists)
        browse.openButton(DefaultScenario.groupPublicID).tap()
        waitFor(staticText(containing: "YOUR GROUP"), timeout: 15)
        XCTAssertTrue(staticText(containing: "OPEN ARENA").exists)
    }

    /// Spec 3.4 states: fetch failure surfaces the error alert.
    func testBrowseFetchFailureShowsErrorAlert() {
        backend.api("GET", "/groups/public") { _, _, _, _ in .empty(500) }
        launchApp()
        waitFor(tabs.browse, timeout: 30)
        tabs.browse.tap()
        waitFor(toast.message(containing: "Something went wrong while loading public groups"),
                timeout: 15)
        XCTAssertTrue(staticText(containing: "Could not load groups").exists)
    }
}

// MARK: - Create group

final class GroupCreateE2ETests: GroupMgmtTestCase {
    /// Spec 3.5: full form (running-tournaments-only picker, points config, sneak-peek
    /// + public toggles, gated CREATE), POST /group payload, success step with invite
    /// link, GO TO GROUP →, and the new group on Home.
    func testCreateGroupFullFormCreatesGroupAndShowsItOnHome() {
        launchApp()
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        home.newGroupButton.tap()

        let create = CreateGroupPage(app: app)
        waitFor(create.formTitle, timeout: 10)

        // Picker lists only RUNNING tournaments.
        create.tournamentPicker.tap()
        waitFor(create.tournamentOption("Euro Cup 2026"), timeout: 10)
        XCTAssertFalse(create.tournamentOption("Legacy League").exists)
        create.tournamentOption("Euro Cup 2026").tap()

        type("Garage League", into: create.nameField)
        type("Bring snacks.", into: create.welcomeField)

        // Tournament + name alone don't unlock CREATE — both point fields gate it.
        scrollTo(create.submitButton, maxSwipes: 8)
        XCTAssertFalse(create.submitButton.isEnabled)

        type("2", into: create.winPointsField)
        type("4", into: create.exactPointsField)
        // App-level swipes over the open number pad get typed as digits — drop the
        // keyboard with a content-band drag before scrolling on.
        dismissKeyboardIfPresent()
        scrollTo(create.sneakPeekToggle, maxSwipes: 6)
        tapToggle(create.sneakPeekToggle)              // default OFF → on
        scrollTo(create.publicToggle, maxSwipes: 4)
        tapToggle(create.publicToggle)                 // default OFF → on

        scrollTo(create.submitButton, maxSwipes: 6)
        XCTAssertTrue(create.submitButton.isEnabled)
        create.submitButton.tap()

        waitFor(create.successTitle, timeout: 15)
        let link = waitFor(create.inviteLinkText).label
        XCTAssertTrue(link.contains("betty.social/dashboard/groups/join/"), "got \(link)")

        let posts = backend.recordedRequests.filter { $0.method == "POST" && $0.path == "/api/v1/group" }
        XCTAssertEqual(posts.count, 1)
        let body = posts.first?.bodyJSON ?? [:]
        XCTAssertEqual(body["name"] as? String, "Garage League")
        XCTAssertEqual(body["tournament_id"] as? Int, DefaultScenario.runningTournamentID)
        XCTAssertEqual(body["correct_team_points"] as? Int, 2)
        XCTAssertEqual(body["exact_result_points"] as? Int, 4)
        XCTAssertEqual(body["allow_sneak_peek"] as? Bool, true)
        XCTAssertEqual(body["is_public"] as? Bool, true)
        XCTAssertEqual(body["mode"] as? Int, 0)
        XCTAssertEqual(body["welcome_message"] as? String, "Bring snacks.")
        XCTAssertFalse((body["group_play_deadline"] as? String ?? "").isEmpty,
                       "deadline must be the tournament kickoff")

        create.goToGroupButton.tap()
        waitFor(staticText(containing: "YOUR GROUP"), timeout: 15)
        XCTAssertTrue(staticText(containing: "GARAGE LEAGUE").exists)

        app.navigationBars.buttons.firstMatch.tap() // back to Home
        waitFor(home.navigationBar, timeout: 10)
        scrollTo(home.groupCard(named: "Garage League"), maxSwipes: 10)
    }

    /// Spec 3.5: on failure the form stays open with input preserved.
    func testCreateGroupFailureKeepsFormOpenWithInput() {
        backend.api("POST", "/group") { _, _, _, _ in .empty(500) }
        launchApp()
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        home.newGroupButton.tap()

        let create = CreateGroupPage(app: app)
        waitFor(create.formTitle, timeout: 10)
        create.tournamentPicker.tap()
        waitFor(create.tournamentOption("Euro Cup 2026"), timeout: 10).tap()
        type("Doomed FC", into: create.nameField)
        type("1", into: create.winPointsField)
        type("2", into: create.exactPointsField)
        dismissKeyboardIfPresent()
        scrollTo(create.submitButton, maxSwipes: 8).tap()

        waitFor(toast.message(containing: "Could not create group"), timeout: 10)
        XCTAssertTrue(create.formTitle.exists, "form must stay open on failure")
        XCTAssertEqual(create.nameField.value as? String, "Doomed FC")
    }
}

// MARK: - Join by code (deep link betty://join/<code>)

final class GroupJoinInviteE2ETests: GroupMgmtTestCase {
    /// Spec 3.6 happy path: deep link → invite preview (name/tournament/description) →
    /// I'M IN → POST /join/:code → confirm → GroupDetail on the Home stack.
    func testDeepLinkJoinHappyPath() {
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)
        openJoinDeepLink(code: "OPENAR")

        let invite = JoinInvitePage(app: app)
        waitFor(invite.groupNameTitle, timeout: 15)
        XCTAssertEqual(invite.groupNameTitle.label, "OPEN ARENA")
        XCTAssertTrue(staticText(containing: "INVITED TO BET").exists)
        XCTAssertTrue(staticText(containing: "EURO CUP 2026").exists)
        XCTAssertTrue(staticText(containing: "Anyone can join.").exists)

        invite.acceptButton.tap()
        waitFor(toast.message(containing: "You are now a proud member of Open Arena"), timeout: 10)
        toast.confirmYesButton.tap()

        waitFor(staticText(containing: "YOUR GROUP"), timeout: 15)
        XCTAssertTrue(staticText(containing: "OPEN ARENA").exists)
        XCTAssertEqual(backend.requests(method: "POST", pathPrefix: "/api/v1/join/OPENAR").count, 1)
    }

    /// Spec 3.6: NO THANKS dismisses without ever calling POST /join.
    func testDeepLinkJoinDeclineDismissesWithoutJoining() {
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)
        openJoinDeepLink(code: "OPENAR")

        let invite = JoinInvitePage(app: app)
        waitFor(invite.acceptButton, timeout: 15)
        invite.declineButton.tap()
        waitForDisappearance(invite.acceptButton, timeout: 10)
        XCTAssertTrue(backend.requests(method: "POST", pathPrefix: "/api/v1/join").isEmpty)
    }

    /// Spec 3.6: preview fetch 404 → "could not load this invite" + GO TO DASHBOARD.
    func testJoinInvalidCodeShowsInviteErrorState() {
        launchApp()
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        openJoinDeepLink(code: "NOSUCH")

        let invite = JoinInvitePage(app: app)
        waitFor(invite.errorTitle, timeout: 15)
        XCTAssertTrue(staticText(containing: "invalid or expired").exists)
        invite.dashboardButton.tap()
        waitForDisappearance(invite.errorTitle, timeout: 10)
        waitFor(home.navigationBar, timeout: 10)
    }

    /// Spec 3.6: join answers 409 → "already member… Go there now?" navigates.
    func testJoinAlreadyMemberOffersNavigation() {
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)
        openJoinDeepLink(code: "SUNLEG")

        let invite = JoinInvitePage(app: app)
        waitFor(invite.groupNameTitle, timeout: 15)
        XCTAssertEqual(invite.groupNameTitle.label, "SUNDAY LEGENDS")
        invite.acceptButton.tap()

        waitFor(toast.message(containing: "already member of Sunday Legends"), timeout: 10)
        toast.confirmYesButton.tap()
        waitFor(staticText(containing: "YOUR GROUP"), timeout: 15)
        XCTAssertTrue(staticText(containing: "SUNDAY LEGENDS").exists)
    }

    /// Spec 3.6: join answers 403 → blocked copy, distinct from 404/409.
    func testJoinBlockedShowsDistinctError() {
        withScenario {
            $0.updateGroup(DefaultScenario.groupPublicID) {
                $0.members.append(MockMember(userID: DefaultScenario.currentUserID,
                                             accessLevel: 2, status: .blocked))
            }
        }
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)
        openJoinDeepLink(code: "OPENAR")

        let invite = JoinInvitePage(app: app)
        waitFor(invite.acceptButton, timeout: 15)
        invite.acceptButton.tap()

        waitFor(toast.message(containing: "You have been blocked from Open Arena"), timeout: 10)
        XCTAssertTrue(staticText(containing: "Cannot bet here").exists)
        XCTAssertTrue(invite.acceptButton.exists, "blocked keeps the sheet open")
    }

    /// Spec 3.6: code rotated between preview and join → POST /join 404 → invalid
    /// invite copy (the sheet stays so the user can bail).
    func testJoinExpiredCodeAfterPreviewShowsInvalidInviteToast() {
        launchApp()
        waitFor(HomeScreen(app: app).navigationBar, timeout: 30)
        openJoinDeepLink(code: "OPENAR")

        let invite = JoinInvitePage(app: app)
        waitFor(invite.acceptButton, timeout: 15)
        withScenario {
            $0.updateGroup(DefaultScenario.groupPublicID) { $0.inviteCode = "ROTATED" }
        }
        invite.acceptButton.tap()

        waitFor(toast.message(containing: "This invite link is invalid or has expired"), timeout: 10)
        XCTAssertTrue(staticText(containing: "Could not join group").exists)
    }
}

// MARK: - Group settings / leave / invite share

final class GroupSettingsE2ETests: GroupMgmtTestCase {
    /// Spec 3.3 GROUP SETTINGS: author edits points + sneak peek, save sends the
    /// partial PUT and the detail house-rules card reflects the new values.
    func testAuthorEditsHouseRulesAndSaves() {
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)

        scrollTo(settings.saveButton, maxSwipes: 8)
        XCTAssertFalse(settings.saveButton.isEnabled, "save must stay disabled until dirty")

        replaceText(in: settings.winPointsField, with: "2")
        replaceText(in: settings.exactPointsField, with: "6")
        // App-level swipes over the still-open number pad get typed as digits — drop
        // the keyboard with a content-band drag before scrolling on.
        dismissKeyboardIfPresent()
        scrollTo(settings.sneakPeekToggle, maxSwipes: 6)
        tapToggle(settings.sneakPeekToggle)              // allowed → closed

        scrollTo(settings.saveButton, maxSwipes: 6)
        XCTAssertTrue(settings.saveButton.isEnabled)
        settings.saveButton.tap()
        waitForDisappearance(settings.editTitle, timeout: 10)

        let puts = backend.requests(method: "PUT",
                                    pathPrefix: "/api/v1/group/\(DefaultScenario.groupSundayLegendsID)/settings")
        XCTAssertEqual(puts.count, 1)
        let body = puts.first?.bodyJSON ?? [:]
        XCTAssertEqual(body["correct_team_points"] as? Int, 2)
        XCTAssertEqual(body["exact_result_points"] as? Int, 6)
        XCTAssertEqual(body["allow_sneak_peek"] as? Bool, false)
        XCTAssertEqual(body["welcome_message"] as? String, "Bring your A-game.")
        XCTAssertEqual(body["description"] as? String, "The original crew.")

        // Detail house rules reflect the update.
        waitFor(staticText(containing: "6 pts"), timeout: 10)
        XCTAssertTrue(staticText(containing: "Closed").exists)
    }

    /// Spec 3.3: only the author gets the EDIT → entry into the settings form.
    func testNonAuthorSeesNoEditEntry() {
        launchApp()
        openGroupDetail(named: "Office Royale")
        scrollTo(staticText(containing: "HOUSE RULES"), maxSwipes: 14)
        XCTAssertFalse(app.buttons["EDIT →"].exists)
    }

    /// Spec 3.3: 401 from PUT /settings → "Only the group author can edit these
    /// settings." and the sheet stays open.
    func testSaveRejectedWithAuthorOnlyMessage() {
        backend.api("PUT", "/group/:id/settings") { _, _, _, _ in .empty(401) }
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)

        scrollTo(settings.winPointsField, maxSwipes: 8)
        replaceText(in: settings.winPointsField, with: "9")
        dismissKeyboardIfPresent()
        scrollTo(settings.saveButton, maxSwipes: 6).tap()

        waitFor(toast.message(containing: "Only the group author can edit these settings"),
                timeout: 10)
        XCTAssertTrue(settings.editTitle.exists, "sheet must stay open on 401")
    }

    /// Spec 3.3: ROTATE CODE confirms, PUTs /group/:id/code, and announces the new code.
    func testRotateInviteCode() {
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)

        scrollTo(settings.rotateCodeButton, maxSwipes: 12).tap()
        waitFor(toast.message(containing: "Rotate the invite code"), timeout: 10)
        toast.confirmYesButton.tap()
        waitFor(toast.message(containing: "New invite code is live"), timeout: 10)

        XCTAssertEqual(backend.requests(
            method: "PUT",
            pathPrefix: "/api/v1/group/\(DefaultScenario.groupSundayLegendsID)/code").count, 1)
        let code = withScenario { $0.group(DefaultScenario.groupSundayLegendsID)?.inviteCode }
        XCTAssertNotEqual(code, "SUNLEG")
    }

    /// Spec 3.3: author flips the public toggle → PUT /group/:id/visibility with
    /// `is_public: true` and the group gains a public_at.
    func testVisibilityTogglePublishesGroup() {
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)

        scrollTo(settings.visibilityToggle, maxSwipes: 12)
        XCTAssertEqual(settings.visibilityToggle.value as? String, "0")
        tapToggle(settings.visibilityToggle)

        waitUntilBackend {
            self.withScenario { $0.group(DefaultScenario.groupSundayLegendsID)?.publicAt != nil }
        }
        let puts = backend.requests(
            method: "PUT",
            pathPrefix: "/api/v1/group/\(DefaultScenario.groupSundayLegendsID)/visibility")
        XCTAssertEqual(puts.count, 1)
        XCTAssertEqual(puts.first?.bodyJSON?["is_public"] as? Bool, true)
    }

    /// ShareLink on the invite row presents the system share sheet.
    func testInviteShareSheetAppears() {
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)

        let link = scrollTo(settings.inviteLinkText, maxSwipes: 12).label
        XCTAssertTrue(link.contains("betty.social/dashboard/groups/join/SUNLEG"), "got \(link)")
        settings.inviteShareButton.tap()
        waitForShareSheet()
    }

    /// Spec 3.3 member management: the author blocks a member (confirm → DELETE
    /// /group/:id/block/:userid → success toast).
    func testAuthorBlocksMemberFromSettings() {
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)

        scrollTo(settings.memberMenu(DefaultScenario.rivalUserID), maxSwipes: 12).tap()
        waitFor(settings.blockMemberOption, timeout: 10).tap()
        waitFor(toast.message(containing: "Block The Oracle from Sunday Legends"), timeout: 10)
        toast.confirmYesButton.tap()
        waitFor(toast.message(containing: "The Oracle has been blocked"), timeout: 10)

        let deletes = backend.requests(
            method: "DELETE",
            pathPrefix: "/api/v1/group/\(DefaultScenario.groupSundayLegendsID)/block/\(DefaultScenario.rivalUserID)")
        XCTAssertEqual(deletes.count, 1)
    }

    /// Spec 3.3: LEAVE GROUP confirms, DELETEs /group/:id/leave, pops home, and the
    /// group disappears from the dashboard.
    func testLeaveGroupRemovesItFromHome() {
        launchApp()
        openSundayLegendsSettings()
        let settings = GroupSettingsPage(app: app)
        let home = HomeScreen(app: app)

        scrollTo(settings.leaveButton, maxSwipes: 14).tap()
        waitFor(toast.message(containing: "Are you sure you want to leave Sunday Legends"),
                timeout: 10)
        toast.confirmYesButton.tap()

        waitFor(home.navigationBar, timeout: 15)
        waitForDisappearance(home.groupCard(named: "Sunday Legends"), timeout: 10)
        XCTAssertEqual(backend.requests(
            method: "DELETE",
            pathPrefix: "/api/v1/group/\(DefaultScenario.groupSundayLegendsID)/leave").count, 1)
        let status = withScenario {
            $0.group(DefaultScenario.groupSundayLegendsID)?
                .member(DefaultScenario.currentUserID)?.status
        }
        XCTAssertEqual(status, .left)
    }
}
