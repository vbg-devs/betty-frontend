import Foundation
import Testing
@testable import Betty

// 2026-06-05 (Friday) noon UTC.
private let now = GroupDetailFixtures.date("2026-06-05T12:00:00Z")
private let calendar = GroupDetailFixtures.utcCalendar

@Suite("Day-grouped schedule (Pools.vue gameGroups pins)")
struct GroupGameDayScheduleTests {
    @Test func flattensAcrossPoolsAndSplitsDifferentKnockoutRoundsSameDay() {
        // Two knockout rounds on the same day must NOT collapse into one header
        // ("Round of 16 & Quarter-final - Tomorrow") — they get their own day-group each,
        // preserving start-order so the earlier round appears first.
        let poolA = PoolGames(
            pool: GroupDetailFixtures.pool(id: 1, name: "Quarter-final"),
            games: [GroupDetailFixtures.game(id: 2, start: GroupDetailFixtures.date("2026-06-06T18:00:00Z"))]
        )
        let poolB = PoolGames(
            pool: GroupDetailFixtures.pool(id: 2, name: "Round of 16"),
            games: [GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-06T12:00:00Z"))]
        )
        let groups = GroupGameDaySchedule.build(pools: [poolA, poolB], now: now, calendar: calendar)
        #expect(groups.count == 2)
        #expect(groups.flatMap { $0.games.map(\.id) } == [1, 2])
        #expect(groups[0].poolNames == ["Round of 16"])
        #expect(groups[1].poolNames == ["Quarter-final"])
        #expect(groups[0].headerText == "Round of 16 - Tomorrow")
        #expect(groups[1].headerText == "Quarter-final - Tomorrow")
    }

    @Test func dayTitles() {
        let pools = [PoolGames(
            pool: GroupDetailFixtures.pool(id: 1, name: "Quarter-final"),
            games: [
                GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-05T18:00:00Z")),
                GroupDetailFixtures.game(id: 2, start: GroupDetailFixtures.date("2026-06-06T18:00:00Z")),
                GroupDetailFixtures.game(id: 3, start: GroupDetailFixtures.date("2026-06-08T18:00:00Z")),
                GroupDetailFixtures.game(id: 4, start: GroupDetailFixtures.date("2026-06-03T18:00:00Z")),
            ]
        )]
        let groups = GroupGameDaySchedule.build(pools: pools, now: now, calendar: calendar)
        #expect(groups.map(\.title) == ["2 days ago", "Today", "Tomorrow", "in 3 days"])
    }

    @Test func groupPoolNameShowsDayTitleOnly() {
        let pools = [PoolGames(
            pool: GroupDetailFixtures.pool(id: 1, name: "Group A"),
            games: [GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-05T18:00:00Z"))]
        )]
        let groups = GroupGameDaySchedule.build(pools: pools, now: now, calendar: calendar)
        #expect(groups[0].headerText == "Today")
    }

    @Test func nonGroupPoolNamePrefixesHeader() {
        let pools = [PoolGames(
            pool: GroupDetailFixtures.pool(id: 1, name: "Quarter-final"),
            games: [GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-06T18:00:00Z"))]
        )]
        let groups = GroupGameDaySchedule.build(pools: pools, now: now, calendar: calendar)
        #expect(groups[0].headerText == "Quarter-final - Tomorrow")
    }

    @Test func groupStageAndKnockoutSameDaySplitIntoSeparateBuckets() {
        // A group-stage pool and a knockout pool on the same day are two separate buckets:
        // the group-stage header shows the day title only, the knockout header prefixes.
        let pools = [
            PoolGames(
                pool: GroupDetailFixtures.pool(id: 1, name: "Group B"),
                games: [GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-06T12:00:00Z"))]
            ),
            PoolGames(
                pool: GroupDetailFixtures.pool(id: 2, name: "Quarter-final"),
                games: [GroupDetailFixtures.game(id: 2, start: GroupDetailFixtures.date("2026-06-06T18:00:00Z"))]
            ),
        ]
        let groups = GroupGameDaySchedule.build(pools: pools, now: now, calendar: calendar)
        #expect(groups.count == 2)
        #expect(groups[0].poolNames == ["Group B"])
        #expect(groups[0].headerText == "Tomorrow")
        #expect(groups[1].poolNames == ["Quarter-final"])
        #expect(groups[1].headerText == "Quarter-final - Tomorrow")
    }

    @Test func multipleGroupStagePoolsSameDayShareOneBucket() {
        // Group A + Group B on the same day still collapse into one block — group-stage
        // pools share the "group" bucket so the day header doesn't repeat per pool letter.
        let pools = [
            PoolGames(
                pool: GroupDetailFixtures.pool(id: 1, name: "Group A"),
                games: [GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-06T12:00:00Z"))]
            ),
            PoolGames(
                pool: GroupDetailFixtures.pool(id: 2, name: "Group B"),
                games: [GroupDetailFixtures.game(id: 2, start: GroupDetailFixtures.date("2026-06-06T18:00:00Z"))]
            ),
        ]
        let groups = GroupGameDaySchedule.build(pools: pools, now: now, calendar: calendar)
        #expect(groups.count == 1)
        #expect(groups[0].poolNames == ["Group A", "Group B"])
        #expect(groups[0].headerText == "Tomorrow")
    }

    @Test func nextUpcomingIsTheGroupOfTheFirstFutureGame() {
        let pools = [PoolGames(
            pool: GroupDetailFixtures.pool(id: 1, name: "Quarter-final"),
            games: [
                GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-04T18:00:00Z")),
                GroupDetailFixtures.game(id: 2, start: GroupDetailFixtures.date("2026-06-06T18:00:00Z")),
                GroupDetailFixtures.game(id: 3, start: GroupDetailFixtures.date("2026-06-07T18:00:00Z")),
            ]
        )]
        let groups = GroupGameDaySchedule.build(pools: pools, now: now, calendar: calendar)
        #expect(groups.map(\.isNextUpcoming) == [false, true, false])
        #expect(GroupGameDaySchedule.nextUpcomingKey(in: groups) == groups[1].key)
    }

    @Test func todayStaysNextUpcomingWhenItsFirstGameAlreadyStarted() {
        // Pinned: today's 09:00 game already started but the 18:00 one hasn't —
        // TODAY is still the next-upcoming group.
        let pools = [PoolGames(
            pool: GroupDetailFixtures.pool(id: 1, name: "Quarter-final"),
            games: [
                GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-05T09:00:00Z")),
                GroupDetailFixtures.game(id: 2, start: GroupDetailFixtures.date("2026-06-05T18:00:00Z")),
                GroupDetailFixtures.game(id: 3, start: GroupDetailFixtures.date("2026-06-06T18:00:00Z")),
            ]
        )]
        let groups = GroupGameDaySchedule.build(pools: pools, now: now, calendar: calendar)
        #expect(groups[0].title == "Today")
        #expect(groups[0].isNextUpcoming)
        #expect(!groups[1].isNextUpcoming)
    }

    @Test func noUpcomingFlagWhenEverythingIsPast() {
        let pools = [PoolGames(
            pool: GroupDetailFixtures.pool(id: 1, name: "Quarter-final"),
            games: [
                GroupDetailFixtures.game(id: 1, start: GroupDetailFixtures.date("2026-06-01T18:00:00Z")),
                GroupDetailFixtures.game(id: 2, start: GroupDetailFixtures.date("2026-06-02T18:00:00Z")),
            ]
        )]
        let groups = GroupGameDaySchedule.build(pools: pools, now: now, calendar: calendar)
        #expect(groups.allSatisfy { !$0.isNextUpcoming })
        #expect(GroupGameDaySchedule.nextUpcomingKey(in: groups) == nil)
    }
}

@Suite("Standings (group page rankedMembers / podium pins)")
struct GroupStandingsTests {
    @Test func denseTieRanking() {
        let members = [
            GroupDetailFixtures.member(userID: "a", score: 10),
            GroupDetailFixtures.member(userID: "b", score: 8),
            GroupDetailFixtures.member(userID: "c", score: 10),
        ]
        let ranked = GroupStandings.ranked(members)
        #expect(ranked.map(\.place) == [1, 1, 2])
        #expect(Set(ranked.prefix(2).map(\.item.userID)) == ["a", "c"])
    }

    @Test func podiumBucketsTiesAndExcludesBeyondThird() {
        let members = [
            GroupDetailFixtures.member(userID: "a", score: 10),
            GroupDetailFixtures.member(userID: "b", score: 10),
            GroupDetailFixtures.member(userID: "c", score: 8),
            GroupDetailFixtures.member(userID: "d", score: 5),
            GroupDetailFixtures.member(userID: "e", score: 5),
            GroupDetailFixtures.member(userID: "f", score: 3),
        ]
        let slots = GroupStandings.podium(GroupStandings.ranked(members))
        #expect(slots.map(\.place) == [1, 2, 3])
        #expect(slots[0].members.count == 2)
        #expect(slots[1].members.map(\.userID) == ["c"])
        #expect(slots[2].members.count == 2)
        // Place 4 (score 3) is excluded.
        #expect(!slots.flatMap(\.members).contains { $0.userID == "f" })
    }

    @Test func championsAndYourPlace() {
        let members = [
            GroupDetailFixtures.member(userID: "a", score: 10),
            GroupDetailFixtures.member(userID: "b", score: 10),
            GroupDetailFixtures.member(userID: "c", score: 8),
        ]
        let ranked = GroupStandings.ranked(members)
        #expect(GroupStandings.champions(ranked).map(\.userID).sorted() == ["a", "b"])
        #expect(GroupStandings.yourPlace(ranked, userID: "c") == 2)
        #expect(GroupStandings.yourPlace(ranked, userID: "missing") == nil)
        #expect(GroupStandings.yourPlace(ranked, userID: nil) == nil)
    }

    @Test func placeDisplayZeroPadsAndDashesWhenAbsent() {
        #expect(GroupStandings.placeDisplay(1) == "01")
        #expect(GroupStandings.placeDisplay(12) == "12")
        #expect(GroupStandings.placeDisplay(nil) == "–")
    }

    @Test func completionPercentage() {
        #expect(GroupStandings.completionPercentage(completeGames: 0, allGames: 10) == 0)
        #expect(GroupStandings.completionPercentage(completeGames: 0, allGames: 0) == 0)
        #expect(GroupStandings.completionPercentage(completeGames: 1, allGames: 3) == 33)
        #expect(GroupStandings.completionPercentage(completeGames: 2, allGames: 3) == 67)
        #expect(GroupStandings.completionPercentage(completeGames: 3, allGames: 3) == 100)
    }
}
