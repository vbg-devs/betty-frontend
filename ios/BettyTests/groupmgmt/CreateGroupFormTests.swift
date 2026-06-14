import Foundation
import Testing
@testable import Betty

@Suite struct CreateGroupFormTests {
    @Test func canSaveRequiresTournamentNameAndBothPointFields() throws {
        let running = [try GroupMgmtFixtures.tournament(id: 5)]
        var form = CreateGroupForm()

        #expect(!form.canSave(running: running))

        form.tournamentID = 5
        form.name = "Sunday Roast XI"
        form.winPoints = "2"
        #expect(!form.canSave(running: running)) // exact pts still empty

        form.exactPoints = "4"
        #expect(form.canSave(running: running))

        form.name = ""
        #expect(!form.canSave(running: running))
    }

    @Test func canSaveDisablesWhenSelectedTournamentStopsRunning() throws {
        var form = CreateGroupForm()
        form.tournamentID = 5
        form.name = "Sunday Roast XI"
        form.winPoints = "2"
        form.exactPoints = "4"

        #expect(form.canSave(running: [try GroupMgmtFixtures.tournament(id: 5)]))
        #expect(!form.canSave(running: [])) // reactive: tournament left the running list
        #expect(!form.canSave(running: [try GroupMgmtFixtures.tournament(id: 6)]))
    }

    @Test func defaultsAreSneakPeekOnAndPublicOff() {
        let form = CreateGroupForm()
        #expect(form.allowSneakPeek)
        #expect(!form.isPublic)
    }

    @Test func payloadUsesTournamentKickoffAsDeadlineAndTrimsDescription() throws {
        let tournament = try GroupMgmtFixtures.tournament(id: 5, startDate: "2026-06-10T18:00:00Z")
        var form = CreateGroupForm()
        form.tournamentID = 5
        form.name = "Sunday Roast XI"
        form.winPoints = "2"
        form.exactPoints = "4"
        form.welcomeMessage = ""
        form.description = "   "
        form.isPublic = true

        let payload = try #require(form.payload(running: [tournament]))

        #expect(payload.name == "Sunday Roast XI")
        #expect(payload.tournamentID == 5)
        #expect(payload.correctTeamPoints == 2)
        #expect(payload.exactResultPoints == 4)
        #expect(payload.groupPlayDeadline == tournament.startDate)
        #expect(payload.welcomeMessage == "") // sent verbatim, never nilled (web parity)
        #expect(payload.description == nil)   // trimmed-empty → null
        #expect(payload.isPublic)
        #expect(payload.mode == 0)
    }

    @Test func payloadKeepsNonEmptyTrimmedDescription() throws {
        let tournament = try GroupMgmtFixtures.tournament(id: 5)
        var form = CreateGroupForm()
        form.tournamentID = 5
        form.name = "G"
        form.winPoints = "1"
        form.exactPoints = "3"
        form.description = "  Pitch your group.  "

        let payload = try #require(form.payload(running: [tournament]))
        #expect(payload.description == "Pitch your group.")
    }

    @Test func payloadIsNilWhenPointsDoNotParse() throws {
        let tournament = try GroupMgmtFixtures.tournament(id: 5)
        var form = CreateGroupForm()
        form.tournamentID = 5
        form.name = "G"
        form.winPoints = "abc"
        form.exactPoints = "3"

        #expect(form.payload(running: [tournament]) == nil)
    }

    // MARK: - Boosters (spec §3.2 / §1.1)

    @Test func boosterDefaultsAreCountZeroMultiplierTwo() {
        let form = CreateGroupForm()
        #expect(form.boostCount == "0")
        #expect(form.boostMultiplier == "2")
        #expect(form.isMultiplierDisabled) // count == 0 → multiplier disabled
    }

    @Test func canSaveRejectsInvalidBoosterValues() throws {
        let running = [try GroupMgmtFixtures.tournament(id: 5)]
        var form = CreateGroupForm()
        form.tournamentID = 5
        form.name = "G"
        form.winPoints = "1"
        form.exactPoints = "3"

        #expect(form.canSave(running: running))

        form.boostCount = "-1"
        #expect(!form.canSave(running: running))

        form.boostCount = "2"
        form.boostMultiplier = "0"
        #expect(!form.canSave(running: running))

        form.boostMultiplier = "1"
        #expect(form.canSave(running: running))
    }

    @Test func payloadCarriesBoosterFields() throws {
        let tournament = try GroupMgmtFixtures.tournament(id: 5)
        var form = CreateGroupForm()
        form.tournamentID = 5
        form.name = "G"
        form.winPoints = "1"
        form.exactPoints = "3"
        form.boostCount = "2"
        form.boostMultiplier = "3"

        let payload = try #require(form.payload(running: [tournament]))
        #expect(payload.boostCount == 2)
        #expect(payload.boostMultiplier == 3)
    }
}
