import Foundation
import Testing
@testable import Betty

@Suite struct BrowseGroupingTests {
    @Test func listModeKeepsEveryItemSingleInOrder() throws {
        let items = [
            try GroupMgmtFixtures.publicGroupItem(id: 1, tournamentID: 1),
            try GroupMgmtFixtures.publicGroupItem(id: 2, tournamentID: 1),
            try GroupMgmtFixtures.publicGroupItem(id: 3, tournamentID: 2),
        ]

        let cards = BrowseGrouping.cards(items: items, grouped: false)

        #expect(cards.map(\.id) == ["g-1", "g-2", "g-3"])
    }

    @Test func groupedModeBucketsByTournamentWithHeaderImageSinglesFirst() throws {
        let items = [
            try GroupMgmtFixtures.publicGroupItem(id: 1, tournamentID: 1),
            try GroupMgmtFixtures.publicGroupItem(id: 2, tournamentID: 1),
            try GroupMgmtFixtures.publicGroupItem(id: 3, tournamentID: 2, headerImageURL: "https://img/custom.png"),
            try GroupMgmtFixtures.publicGroupItem(id: 4, tournamentID: 3),
        ]

        let cards = BrowseGrouping.cards(items: items, grouped: true)

        // Header-image singles first (item order), then buckets in first-appearance
        // order; the lone tournament-3 bucket collapses back to a single.
        #expect(cards.map(\.id) == ["g-3", "t-1", "g-4"])
    }

    @Test func tournamentCardTakesNameAndImageFromFirstBucketItem() throws {
        let items = [
            try GroupMgmtFixtures.publicGroupItem(id: 1, tournamentID: 9, tournamentName: "Copa", tournamentImageURL: "https://img/copa.png"),
            try GroupMgmtFixtures.publicGroupItem(id: 2, tournamentID: 9, tournamentName: "Copa", tournamentImageURL: nil),
        ]

        let cards = BrowseGrouping.cards(items: items, grouped: true)

        guard case .tournament(let id, let name, let imageURL, let groups) = cards.first else {
            Issue.record("expected a tournament card, got \(cards)")
            return
        }
        #expect(id == 9)
        #expect(name == "Copa")
        #expect(imageURL == "https://img/copa.png")
        #expect(groups.map(\.id) == [1, 2])
    }

    @Test func groupedModeWithOnlySinglesNeverEmitsTournamentCards() throws {
        let items = [
            try GroupMgmtFixtures.publicGroupItem(id: 1, tournamentID: 1),
            try GroupMgmtFixtures.publicGroupItem(id: 2, tournamentID: 2),
        ]

        let cards = BrowseGrouping.cards(items: items, grouped: true)

        #expect(cards.map(\.id) == ["g-1", "g-2"])
    }

    @Test func emptyInputYieldsNoCards() {
        #expect(BrowseGrouping.cards(items: [], grouped: true).isEmpty)
        #expect(BrowseGrouping.cards(items: [], grouped: false).isEmpty)
    }
}
