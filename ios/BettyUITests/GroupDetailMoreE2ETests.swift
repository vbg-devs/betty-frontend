import XCTest

// Closes the group-detail cover-image gaps: the author CTA state machine
// ("+ ADD COVER" ↔ "CHANGE COVER →") and the author-only gate (a participant never
// sees the upload CTA; the SAME user sees it again in a group they authored).
// KNOWN LIMIT: PhotosPicker presents an OS-process sheet XCUITest cannot drive, so
// the presign → R2 PUT → commit chain and the 401/413/415/503 error mapping are
// pinned in BettyTests/groupdetail/GroupCoverImageFlowTests with a mocked transport.

/// Author-side cover CTA states (seeded user alex authors Sunday Legends).
final class GroupDetailMoreE2ETests: BettyUITestCase {

    @discardableResult
    private func openGroup(named name: String) -> GroupDetailScreen {
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        scrollTo(home.groupCard(named: name)).tap()
        waitFor(staticText(containing: name.uppercased()), timeout: 15)
        return GroupDetailScreen(app: app)
    }

    /// No committed cover → the author CTA invites an upload ("+ ADD COVER").
    func testAuthorCoverCTAReadsAddCoverWithoutCommittedCover() {
        launchApp()
        let screen = openGroup(named: "Sunday Legends")

        let cta = waitFor(screen.coverCTA)
        XCTAssertTrue(cta.label.contains("ADD COVER"), "got '\(cta.label)'")
        XCTAssertFalse(cta.label.contains("CHANGE COVER"))
        XCTAssertTrue(cta.isHittable) // the upload boundary is reachable
    }

    /// A committed `header_image_url` flips the CTA to "CHANGE COVER →" — the
    /// post-upload UI state of the presign → PUT → commit chain.
    func testAuthorCoverCTAFlipsToChangeCoverOnceCoverCommitted() {
        let coverURL = "\(backend.publicAssetBase)/groups/1/header/seeded.png"
        withScenario { $0.groupDetailSetHeaderImage(coverURL) }
        launchApp()
        let screen = openGroup(named: "Sunday Legends")

        let cta = waitFor(screen.coverCTA)
        XCTAssertTrue(cta.label.contains("CHANGE COVER"), "got '\(cta.label)'")
        XCTAssertFalse(cta.label.contains("ADD COVER"))
    }
}

/// Author-only gate from the OTHER side: casey is a plain participant of Sunday
/// Legends but the author of Office Royale — the CTA must follow per-group
/// authorship, not the user.
final class GroupDetailNonAuthorCoverE2ETests: BettyUITestCase {
    override var seededUserID: String { DefaultScenario.friendUserID }

    @discardableResult
    private func openGroup(named name: String) -> GroupDetailScreen {
        let home = HomeScreen(app: app)
        waitFor(home.navigationBar, timeout: 30)
        scrollTo(home.groupCard(named: name)).tap()
        waitFor(staticText(containing: name.uppercased()), timeout: 15)
        return GroupDetailScreen(app: app)
    }

    /// A non-author member gets NO cover CTA at all (not disabled — absent).
    func testNonAuthorSeesNoCoverCTA() {
        launchApp()
        let screen = openGroup(named: "Sunday Legends")

        // Hero fully rendered (rank tile present) before asserting absence.
        waitFor(app.staticTexts["YOUR RANK"])
        XCTAssertFalse(screen.coverCTA.exists)
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'ADD COVER'")).firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'CHANGE COVER'")).firstMatch.exists)
    }

    /// The same non-author user IS the author of Office Royale — there the CTA shows,
    /// pinning the gate to `access_level == 0` in THIS group.
    func testSameUserSeesCoverCTAInGroupTheyAuthored() {
        launchApp()
        let screen = openGroup(named: "Office Royale")

        let cta = waitFor(screen.coverCTA)
        XCTAssertTrue(cta.label.contains("ADD COVER"), "got '\(cta.label)'")
    }
}
