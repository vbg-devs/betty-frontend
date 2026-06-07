import Foundation
import Testing
@testable import Betty

@Suite struct ReactionLogicTests {
    private func reaction(_ userID: String, _ emoji: String) -> MessageReaction {
        MessageReaction(userID: userID, emojiID: emoji, createdAt: Date())
    }

    @Test func groupsByEmojiInFirstSeenOrderWithCounts() {
        let reactions = [
            reaction("uid-a", "👍"),
            reaction("uid-b", "❤️"),
            reaction("uid-c", "👍"),
            reaction("uid-d", "🔥"),
        ]

        let groups = ReactionLogic.grouped(reactions, currentUserID: "uid-c")

        #expect(groups.map(\.emojiID) == ["👍", "❤️", "🔥"])
        #expect(groups.map(\.count) == [2, 1, 1])
        #expect(groups.map(\.reactedByMe) == [true, false, false])
    }

    @Test func emptyReactionsYieldNoGroups() {
        #expect(ReactionLogic.grouped([], currentUserID: "uid-a").isEmpty)
    }

    @Test func loggedOutIsNeverMineAndCannotToggle() {
        let reactions = [reaction("uid-a", "👍")]

        let groups = ReactionLogic.grouped(reactions, currentUserID: nil)
        #expect(groups.count == 1)
        #expect(groups[0].reactedByMe == false)

        #expect(ReactionLogic.toggleAction(for: "👍", in: reactions, currentUserID: nil) == nil)
    }

    @Test func tappingMyCurrentEmojiRemoves() {
        let reactions = [reaction("uid-b", "❤️"), reaction("uid-me", "👍")]

        let action = ReactionLogic.toggleAction(for: "👍", in: reactions, currentUserID: "uid-me")

        #expect(action == .remove)
    }

    @Test func tappingDifferentEmojiReplacesMine() {
        let reactions = [reaction("uid-me", "👍")]

        let action = ReactionLogic.toggleAction(for: "🔥", in: reactions, currentUserID: "uid-me")

        #expect(action == .set(emojiID: "🔥"))
    }

    @Test func tappingWithoutPriorReactionSets() {
        let reactions = [reaction("uid-other", "👍")]

        let action = ReactionLogic.toggleAction(for: "👍", in: reactions, currentUserID: "uid-me")

        #expect(action == .set(emojiID: "👍"))
    }

    @Test func authorNamePrefersNonEmptyNicknameThenNameThenUnknown() {
        func member(name: String?, nickname: String?) -> Member {
            Member(
                userID: "u",
                name: name,
                nickname: nickname,
                imageURL: nil,
                score: 0,
                normalizedScore: 0,
                accessLevel: 2
            )
        }

        #expect(ChatDisplay.authorName(member(name: "Ada", nickname: "Lovelace")) == "Lovelace")
        // Empty nickname falls through (web `||` semantics).
        #expect(ChatDisplay.authorName(member(name: "Ada", nickname: "")) == "Ada")
        #expect(ChatDisplay.authorName(member(name: "", nickname: nil)) == "Unknown")
        #expect(ChatDisplay.authorName(member(name: nil, nickname: nil)) == "Unknown")
        #expect(ChatDisplay.authorName(nil) == "Unknown")
    }

    @Test func relativeTimeSaysJustNowUnderAMinute() {
        let now = Date()
        #expect(ChatRelativeTime.string(from: now.addingTimeInterval(-30), to: now) == "just now")
        #expect(ChatRelativeTime.string(from: now, to: now) == "just now")
    }

    @Test func relativeTimeFormatsOlderDates() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let formatted = ChatRelativeTime.string(from: twoHoursAgo, to: now, locale: Locale(identifier: "en_US"))
        #expect(formatted == "2 hours ago")
    }
}
