import XCTest

// Group-detail area page objects. Identifier namespace: "groupDetail.*"
// (rows/cards added by this suite to Betty/Features/GroupDetail views).

extension GroupDetailScreen {
    /// Author-only hero cover CTA (PhotosPicker): "+ ADD COVER" without a cover,
    /// "CHANGE COVER →" once one is committed, "UPLOADING…" mid-flight.
    var coverCTA: XCUIElement { element(app, id: "groupDetail.hero.coverCTA") }

    /// Game card (need-action strip + Games tab): "groupDetail.games.card.<gameID>".
    func gameCard(_ gameID: Int) -> XCUIElement {
        element(app, id: "groupDetail.games.card.\(gameID)")
    }

    /// TOP 3 sidebar card avatar button (index 0 = highest score).
    func topThreeMember(_ index: Int) -> XCUIElement {
        element(app, id: "groupDetail.top3.member.\(index)")
    }

    /// Final-podium person button: place slot (1–3) + index within tied slot.
    func podiumMember(place: Int, index: Int = 0) -> XCUIElement {
        element(app, id: "groupDetail.podium.place.\(place).member.\(index)")
    }
}

/// BetSheet (router sheet `.bet`): YOUR BET / PLACED BETS tabs, steppers, the
/// universal toggle, submit, 423 error panel, placed-bet rows.
struct BetSheetScreen {
    let app: XCUIApplication

    var root: XCUIElement { element(app, id: "groupDetail.betSheet.root") }
    var header: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'PLACE YOUR BET'")).firstMatch
    }
    var yourBetTab: XCUIElement { element(app, id: "groupDetail.betSheet.tab.yourBet") }
    var placedTab: XCUIElement { element(app, id: "groupDetail.betSheet.tab.placed") }

    var homeField: XCUIElement { app.textFields["groupDetail.betSheet.homeField"] }
    var awayField: XCUIElement { app.textFields["groupDetail.betSheet.awayField"] }
    var homePlus: XCUIElement { element(app, id: "groupDetail.betSheet.home.plus") }
    var homeMinus: XCUIElement { element(app, id: "groupDetail.betSheet.home.minus") }
    var awayPlus: XCUIElement { element(app, id: "groupDetail.betSheet.away.plus") }
    var awayMinus: XCUIElement { element(app, id: "groupDetail.betSheet.away.minus") }

    var universalToggle: XCUIElement {
        let toggle = app.switches["groupDetail.betSheet.universalToggle"]
        return toggle.exists ? toggle : element(app, id: "groupDetail.betSheet.universalToggle")
    }

    /// Flips the toggle. SwiftUI exposes a Toggle as one full-row Switch whose center
    /// is the LABEL — taps there don't reach the control, so aim at the nested switch
    /// (or the trailing edge when it isn't exposed separately).
    func tapUniversalToggle() {
        let control = universalToggle.switches.firstMatch
        if control.exists, control.isHittable {
            control.tap()
        } else {
            universalToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
    }
    var submitButton: XCUIElement { app.buttons["groupDetail.betSheet.submit"] }
    var errorPanel: XCUIElement { element(app, id: "groupDetail.betSheet.error") }
    var closeButton: XCUIElement { app.buttons["Close"] }

    /// Placed-bets row, ordered by `user_points` desc (combined label:
    /// "<name>, <h> – <a>, +NP" — score/points omitted while hidden/unprocessed).
    func placedRow(_ index: Int) -> XCUIElement {
        element(app, id: "groupDetail.betSheet.placedRow.\(index)")
    }
}

/// UserHistorySheet (router sheet `.userHistory`): "<N> BETS · <Σ> PTS" header and
/// kickoff-ascending bet rows (combined label carries score digits only when visible).
struct UserHistorySheetScreen {
    let app: XCUIApplication

    var root: XCUIElement { element(app, id: "groupDetail.userHistory.root") }
    var title: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'BET HISTORY'")).firstMatch
    }
    var emptyState: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'NO BETS YET'")).firstMatch
    }
    var closeButton: XCUIElement { app.buttons["Close"] }

    func row(_ index: Int) -> XCUIElement {
        element(app, id: "groupDetail.userHistory.row.\(index)")
    }
}
