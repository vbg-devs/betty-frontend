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

    // MARK: - Boosters (spec §3.1 / §1.1)

    @Test func prefillsBoosterFieldsFromGroup() throws {
        let group = try GroupMgmtFixtures.group(boostCount: 2, boostMultiplier: 3)
        let form = GroupSettingsForm(group: group)
        #expect(form.boostCount == "2")
        #expect(form.boostMultiplier == "3")
        #expect(!form.isMultiplierDisabled)
        #expect(!form.isDirty)
    }

    @Test func multiplierIsDisabledWhenCountIsZero() throws {
        let group = try GroupMgmtFixtures.group(boostCount: 0, boostMultiplier: 2)
        let form = GroupSettingsForm(group: group)
        #expect(form.isMultiplierDisabled)
    }

    @Test func boosterFieldsContributeToIsDirty() throws {
        let group = try GroupMgmtFixtures.group(boostCount: 0, boostMultiplier: 2)
        var form = GroupSettingsForm(group: group)

        form.boostCount = "3"
        #expect(form.isDirty)
        form.boostCount = "0"
        #expect(!form.isDirty)

        form.boostMultiplier = "5"
        #expect(form.isDirty)
        form.boostMultiplier = "2"
        #expect(!form.isDirty)
    }

    @Test func boosterValidationRejectsNegativeCountAndSubOneMultiplier() throws {
        let group = try GroupMgmtFixtures.group(boostCount: 2, boostMultiplier: 2)
        var form = GroupSettingsForm(group: group)

        form.boostCount = "-1"
        #expect(!form.canSave)
        #expect(form.update == nil)

        form.boostCount = "0"
        #expect(form.canSave)

        form.boostMultiplier = "0"
        #expect(!form.canSave)
        form.boostMultiplier = "1"
        #expect(form.canSave)
    }

    @Test func updateSendsBoosterFields() throws {
        let group = try GroupMgmtFixtures.group(boostCount: 0, boostMultiplier: 2)
        var form = GroupSettingsForm(group: group)
        form.boostCount = "2"
        form.boostMultiplier = "3"

        let update = try #require(form.update)
        #expect(update.boostCount == 2)
        #expect(update.boostMultiplier == 3)
    }

    // MARK: - Lone Ranger (spec §6.1)

    @Test func prefillsLoneRangerFieldsFromGroup() throws {
        let group = try GroupMgmtFixtures.group(loneRangerEnabled: true, loneRangerPoints: 5)
        let form = GroupSettingsForm(group: group)
        #expect(form.loneRangerEnabled)
        #expect(form.loneRangerPoints == "5")
        #expect(!form.isLoneRangerPointsDisabled)
        #expect(!form.isDirty)
    }

    @Test func loneRangerPointsDisabledWhenToggleOff() throws {
        let group = try GroupMgmtFixtures.group(loneRangerEnabled: false, loneRangerPoints: 0)
        let form = GroupSettingsForm(group: group)
        #expect(form.isLoneRangerPointsDisabled)
    }

    @Test func loneRangerFieldsContributeToIsDirty() throws {
        let group = try GroupMgmtFixtures.group(loneRangerEnabled: false, loneRangerPoints: 0)
        var form = GroupSettingsForm(group: group)

        form.loneRangerEnabled = true
        #expect(form.isDirty)
        form.loneRangerEnabled = false
        #expect(!form.isDirty)

        form.loneRangerPoints = "5"
        #expect(form.isDirty)
        form.loneRangerPoints = "0"
        #expect(!form.isDirty)
    }

    @Test func canSaveRequiresNonNegativeLoneRangerPointsWhenEnabled() throws {
        let group = try GroupMgmtFixtures.group(loneRangerEnabled: false, loneRangerPoints: 0)
        var form = GroupSettingsForm(group: group)

        form.loneRangerEnabled = true
        form.loneRangerPoints = "-1"
        #expect(!form.canSave)
        #expect(form.update == nil)

        form.loneRangerPoints = "5"
        #expect(form.canSave)

        // When disabled, an unparseable / garbage value is ignored.
        form.loneRangerEnabled = false
        form.loneRangerPoints = "x"
        #expect(form.canSave)
    }

    @Test func updateSendsLoneRangerFields() throws {
        let group = try GroupMgmtFixtures.group(loneRangerEnabled: false, loneRangerPoints: 0)
        var form = GroupSettingsForm(group: group)
        form.loneRangerEnabled = true
        form.loneRangerPoints = "5"

        let update = try #require(form.update)
        #expect(update.loneRangerEnabled == true)
        #expect(update.loneRangerPoints == 5)
    }
}
