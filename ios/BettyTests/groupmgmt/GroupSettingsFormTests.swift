import Foundation
import Testing
@testable import Betty

@Suite struct GroupSettingsFormTests {
    @Test func prefillsFromGroupWithNilFallingBackToEmpty() throws {
        let group = try GroupMgmtFixtures.group(
            welcomeMessage: nil,
            description: "Banter HQ",
            correctTeamPoints: 2,
            exactResultPoints: 4,
            allowSneakPeek: true
        )

        let form = GroupSettingsForm(group: group)

        #expect(form.welcomeMessage == "")
        #expect(form.description == "Banter HQ")
        #expect(form.winPoints == "2")
        #expect(form.exactPoints == "4")
        #expect(form.allowSneakPeek)
        #expect(!form.isDirty)
        #expect(form.canSave)
    }

    @Test func isDirtyFlipsPerFieldAndRevertDisablesAgain() throws {
        let group = try GroupMgmtFixtures.group(welcomeMessage: "Hello", correctTeamPoints: 2)
        var form = GroupSettingsForm(group: group)

        form.welcomeMessage = "Hi"
        #expect(form.isDirty)
        form.welcomeMessage = "Hello"
        #expect(!form.isDirty) // revert disables saving again (pinned)

        form.winPoints = "3"
        #expect(form.isDirty)
        form.winPoints = "2"
        #expect(!form.isDirty)

        form.allowSneakPeek.toggle()
        #expect(form.isDirty)
    }

    @Test func unparseablePointsBlockSaveButCountAsDirty() throws {
        let group = try GroupMgmtFixtures.group()
        var form = GroupSettingsForm(group: group)

        form.winPoints = ""
        #expect(!form.canSave)
        #expect(form.isDirty) // NaN-never-equals parity with the web

        form.winPoints = "x"
        #expect(!form.canSave)
        #expect(form.update == nil)
    }

    @Test func updateSendsWelcomeVerbatimAndTrimmedOrNullDescription() throws {
        let group = try GroupMgmtFixtures.group(welcomeMessage: "Hello", description: "Old")
        var form = GroupSettingsForm(group: group)
        form.welcomeMessage = ""
        form.description = "   "
        form.winPoints = "5"
        form.exactPoints = "9"
        form.allowSneakPeek = false

        let update = try #require(form.update)

        #expect(update.welcomeMessage == "") // verbatim empty string, not null
        #expect(update.description == nil)   // trimmed-empty → explicit null
        #expect(update.correctTeamPoints == 5)
        #expect(update.exactResultPoints == 9)
        #expect(!update.allowSneakPeek)
    }

    @Test func updateKeepsTrimmedDescription() throws {
        let group = try GroupMgmtFixtures.group()
        var form = GroupSettingsForm(group: group)
        form.description = "  Fresh pitch  "

        let update = try #require(form.update)
        #expect(update.description == "Fresh pitch")
    }
}
