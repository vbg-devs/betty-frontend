import XCTest

// Page objects for the Tournaments area: the Browse tab's TOURNAMENTS / TEAMS sections,
// the tournament detail sheet (day-grouped schedule), and the admin evaluate flow.
// All identifiers follow "tournaments.<screen>.<element>" and live in
// Betty/Features/Tournaments/.

/// Browse tab → TOURNAMENTS section (`TournamentsListView`).
struct TournamentsListScreen {
    let app: XCUIApplication

    /// Browse-tab section picker buttons (test-pinned copy in `BrowseGroupsView`).
    var tournamentsSectionButton: XCUIElement { app.buttons["TOURNAMENTS"] }
    var teamsSectionButton: XCUIElement { app.buttons["TEAMS"] }

    /// One running-tournament card (a contained button — children stay queryable).
    func card(_ tournamentID: Int) -> XCUIElement {
        element(app, id: "tournaments.list.card.\(tournamentID)")
    }

    var emptyPanel: XCUIElement { element(app, id: "tournaments.list.empty") }

    /// The mascot artwork rendered when a tournament has no `image_url`.
    func placeholderArtwork(in container: XCUIElement) -> XCUIElement {
        container.descendants(matching: .any)
            .matching(identifier: "tournaments.image.placeholderMascot").firstMatch
    }
}

/// `TournamentDetailSheet` — header + day-grouped schedule.
struct TournamentDetailScreen {
    let app: XCUIApplication

    var header: XCUIElement { element(app, id: "tournaments.detail.header") }
    var failedPanel: XCUIElement { element(app, id: "tournaments.detail.failed") }
    var closeButton: XCUIElement { app.buttons["tournaments.detail.close"] }
    var tryAgainButton: XCUIElement { app.buttons["TRY AGAIN"] }

    /// Day header by its exact rendered text ("● Today", "Tomorrow",
    /// "Knockout - in 2 days", "2 days ago", ...). Matched on the label because the
    /// header Text carries the "tournaments.schedule.day.<key>" identifier.
    func dayHeader(_ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// One schedule game card (contained — team names/score/labels are children).
    func gameCard(_ gameID: Int) -> XCUIElement {
        element(app, id: "tournaments.schedule.game.\(gameID)")
    }
}

/// Browse tab → TEAMS section (`TeamsBrowserView`).
struct TeamsBrowserScreen {
    let app: XCUIApplication

    var searchField: XCUIElement { app.textFields["tournaments.teams.search"] }
    var clearSearchButton: XCUIElement { app.buttons["tournaments.teams.clearSearch"] }
    var emptyPanel: XCUIElement { element(app, id: "tournaments.teams.empty") }

    func cell(_ teamID: Int) -> XCUIElement {
        element(app, id: "tournaments.teams.cell.\(teamID)")
    }

    /// The circular logo inside a cell. Bundled art renders an image (no text child);
    /// a missing/unknown `image_url` renders the monogram letter as a static text.
    func logo(_ teamID: Int) -> XCUIElement {
        element(app, id: "tournaments.teams.logo.\(teamID)")
    }

    func monogram(teamID: Int, letter: String) -> XCUIElement {
        logo(teamID).staticTexts[letter]
    }
}

/// `AdminEvaluateView` + its evaluate sheet (reached from Profile → Admin).
struct AdminEvaluateScreen {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars["Admin"] }
    var heroTitle: XCUIElement { app.staticTexts["EVALUATE GAMES."] }
    var restrictedCard: XCUIElement { element(app, id: "tournaments.admin.restricted") }
    var noTournamentsPanel: XCUIElement { element(app, id: "tournaments.admin.noTournaments") }
    var loadFailedPanel: XCUIElement { element(app, id: "tournaments.admin.loadFailed") }
    var noPendingGamesPanel: XCUIElement { element(app, id: "tournaments.admin.noPendingGames") }
    var tryAgainButton: XCUIElement { app.buttons["TRY AGAIN"] }

    func tournamentCard(_ tournamentID: Int) -> XCUIElement {
        element(app, id: "tournaments.admin.tournament.\(tournamentID)")
    }

    func gameCard(_ gameID: Int) -> XCUIElement {
        element(app, id: "tournaments.admin.game.\(gameID)")
    }

    // Evaluate sheet

    var sheetTitle: XCUIElement { app.staticTexts["POST THE SCORE."] }
    var homeScoreField: XCUIElement { app.textFields["tournaments.admin.evaluate.home"] }
    var awayScoreField: XCUIElement { app.textFields["tournaments.admin.evaluate.away"] }
    var submitButton: XCUIElement { app.buttons["tournaments.admin.evaluate.submit"] }
    var notStartedNotice: XCUIElement { app.staticTexts["tournaments.admin.evaluate.notStarted"] }
    var errorText: XCUIElement { app.staticTexts["tournaments.admin.evaluate.error"] }
    /// Native confirmation-dialog action ("Evaluate game" / "Cancel").
    var confirmEvaluateButton: XCUIElement { app.buttons["Evaluate game"] }
    var cancelConfirmButton: XCUIElement { app.buttons["Cancel"] }
}
