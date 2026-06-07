import XCTest

// Page objects for the group-management area: the public-groups browse list, the
// create-group sheet, the join-invite sheet (deep-link entry), the group-settings
// sheet, and the shared toast/confirm bar. Identifier convention:
// "<area>.<screen>.<element>" — added by this suite in Features/GroupManagement.

/// Browse tab → GROUPS section (`BrowseGroupsScreen`).
struct BrowseGroupsPage {
    let app: XCUIApplication

    var searchField: XCUIElement { element(app, id: "browse.groups.searchField") }
    var tournamentFilter: XCUIElement { element(app, id: "browse.groups.tournamentFilter") }
    var loadMoreButton: XCUIElement { app.buttons["browse.groups.loadMore"] }
    var startGroupCTA: XCUIElement { app.buttons["browse.groups.createCTA"] }
    var nothingHereTitle: XCUIElement { app.staticTexts["NOTHING HERE."] }
    var openGroupsTitle: XCUIElement { app.staticTexts["OPEN GROUPS."] }

    func card(_ groupID: Int) -> XCUIElement { element(app, id: "browse.groups.card.\(groupID)") }
    func joinButton(_ groupID: Int) -> XCUIElement { app.buttons["browse.groups.join.\(groupID)"] }
    func openButton(_ groupID: Int) -> XCUIElement { app.buttons["browse.groups.open.\(groupID)"] }
    func groupName(_ name: String) -> XCUIElement { app.staticTexts[name].firstMatch }
    /// Menu items render as plain buttons once the menu is open.
    func filterOption(_ title: String) -> XCUIElement { app.buttons[title].firstMatch }
}

/// `.createGroup` router sheet (`CreateGroupSheet`), both steps.
struct CreateGroupPage {
    let app: XCUIApplication

    var formTitle: XCUIElement { app.staticTexts["START A GROUP"] }
    var tournamentPicker: XCUIElement { element(app, id: "createGroup.form.tournamentPicker") }
    var nameField: XCUIElement { element(app, id: "createGroup.form.nameField") }
    var welcomeField: XCUIElement { element(app, id: "createGroup.form.welcomeField") }
    var descriptionField: XCUIElement { element(app, id: "createGroup.form.descriptionField") }
    var winPointsField: XCUIElement { element(app, id: "createGroup.form.winPointsField") }
    var exactPointsField: XCUIElement { element(app, id: "createGroup.form.exactPointsField") }
    var sneakPeekToggle: XCUIElement { app.switches["createGroup.form.sneakPeekToggle"].firstMatch }
    var publicToggle: XCUIElement { app.switches["createGroup.form.publicToggle"].firstMatch }
    var submitButton: XCUIElement { app.buttons["createGroup.form.submitButton"] }
    var closeButton: XCUIElement { app.buttons["Close"].firstMatch }

    var successTitle: XCUIElement { app.staticTexts["GROUP CREATED."] }
    var goToGroupButton: XCUIElement { app.buttons["createGroup.success.goToGroupButton"] }
    var inviteLinkText: XCUIElement { element(app, id: "groupMgmt.inviteLink.text") }
    var inviteShareButton: XCUIElement { element(app, id: "groupMgmt.inviteLink.shareButton") }

    func tournamentOption(_ name: String) -> XCUIElement { app.buttons[name].firstMatch }
}

/// `.joinInvite(code:)` router sheet (`JoinInviteSheet`) — the deep-link entry.
struct JoinInvitePage {
    let app: XCUIApplication

    var groupNameTitle: XCUIElement { element(app, id: "joinInvite.invite.groupName") }
    var acceptButton: XCUIElement { app.buttons["joinInvite.invite.acceptButton"] }
    var declineButton: XCUIElement { app.buttons["joinInvite.invite.declineButton"] }
    var errorTitle: XCUIElement { element(app, id: "joinInvite.error.title") }
    var dashboardButton: XCUIElement { app.buttons["joinInvite.error.dashboardButton"] }
}

/// `.groupSettings(groupID:)` router sheet (`GroupSettingsScreen`).
struct GroupSettingsPage {
    let app: XCUIApplication

    /// Author headline; non-authors see the group name instead.
    var editTitle: XCUIElement { app.staticTexts["EDIT GROUP."] }
    var welcomeField: XCUIElement { element(app, id: "groupSettings.form.welcomeField") }
    var descriptionField: XCUIElement { element(app, id: "groupSettings.form.descriptionField") }
    var winPointsField: XCUIElement { element(app, id: "groupSettings.form.winPointsField") }
    var exactPointsField: XCUIElement { element(app, id: "groupSettings.form.exactPointsField") }
    var sneakPeekToggle: XCUIElement { app.switches["groupSettings.form.sneakPeekToggle"].firstMatch }
    var saveButton: XCUIElement { app.buttons["groupSettings.form.saveButton"] }
    var visibilityToggle: XCUIElement { app.switches["groupSettings.visibility.toggle"].firstMatch }
    var rotateCodeButton: XCUIElement { app.buttons["groupSettings.invite.rotateButton"] }
    var leaveButton: XCUIElement { app.buttons["groupSettings.leaveButton"] }
    var inviteLinkText: XCUIElement { element(app, id: "groupMgmt.inviteLink.text") }
    var inviteCopyButton: XCUIElement { element(app, id: "groupMgmt.inviteLink.copyButton") }
    var inviteShareButton: XCUIElement { element(app, id: "groupMgmt.inviteLink.shareButton") }
    var closeButton: XCUIElement { app.buttons["Close"].firstMatch }

    func memberMenu(_ userID: String) -> XCUIElement {
        element(app, id: "groupSettings.members.menu.\(userID)")
    }
    var blockMemberOption: XCUIElement { app.buttons["Block member"].firstMatch }
}

/// The LiveToastHost cards (alerts auto-dismiss after 4 s; confirms wait for input).
struct ToastBar {
    let app: XCUIApplication

    var confirmYesButton: XCUIElement { app.buttons["YES, DO IT →"].firstMatch }
    var confirmCancelButton: XCUIElement { app.buttons["CANCEL"].firstMatch }

    func message(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
}
