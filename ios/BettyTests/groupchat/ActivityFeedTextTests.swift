import Foundation
import Testing
@testable import Betty

/// Pins the activity-feed copy + kicker/accent mapping (web `ActivityFeed` TYPE_META
/// and the per-type list items).
@Suite struct ActivityFeedTextTests {
    private func event(_ envelope: String) throws -> BettyEvent {
        try #require(BettyEvent.decode(from: Data(envelope.utf8)))
    }

    // MARK: - Type → label/accent table

    @Test func metaMapsKnownTypes() throws {
        let bet = """
        {"type":"bet_placed","message":{"id":1,"user_id":"u1","game_id":9,"group_id":2,
        "user_points":null,"home_team_score":1,"away_team_score":0,"is_universal":false,
        "processed_at":null,"created_at":"2026-06-01T10:00:00Z","updated_at":"2026-06-01T10:00:00Z"}}
        """
        let betMeta = try ActivityEventMeta.meta(for: event(bet))
        #expect(betMeta.label == "● NEW BET")
        #expect(betMeta.accent == .orange)

        let updated = bet.replacingOccurrences(of: "bet_placed", with: "bet_updated")
        let updatedMeta = try ActivityEventMeta.meta(for: event(updated))
        #expect(updatedMeta.label == "● BET UPDATED")
        #expect(updatedMeta.accent == .orange)

        let kickoff = try event(#"{"type":"game_starting_soon","message":{"Games":[{"id":9}]}}"#)
        #expect(ActivityEventMeta.meta(for: kickoff).label == "● KICKING OFF")
        #expect(ActivityEventMeta.meta(for: kickoff).accent == .yellow)

        let fullTime = try event(#"{"type":"evaluate_game","message":{"game_id":9,"home_team_score":2,"away_team_score":1}}"#)
        #expect(ActivityEventMeta.meta(for: fullTime).label == "★ FULL TIME")
        #expect(ActivityEventMeta.meta(for: fullTime).accent == .cream)

        let exact = try event(#"{"type":"user_exact_score","message":{"game_id":9,"user_ids":["u1"]}}"#)
        #expect(ActivityEventMeta.meta(for: exact).label == "★ EXACT SCORE")
        #expect(ActivityEventMeta.meta(for: exact).accent == .green)

        let joined = try event(#"{"type":"group_joined","message":{"group":{"id":1,"name":"G"},"who":"Anna"}}"#)
        #expect(ActivityEventMeta.meta(for: joined).label == "● JOINED GROUP")
        #expect(ActivityEventMeta.meta(for: joined).accent == .green)

        let left = try event(#"{"type":"group_left","message":null}"#)
        #expect(ActivityEventMeta.meta(for: left).label == "● LEFT GROUP")
        #expect(ActivityEventMeta.meta(for: left).accent == .cream)

        let created = try event(#"{"type":"group_created","message":null}"#)
        #expect(ActivityEventMeta.meta(for: created).label == "★ NEW GROUP")
        #expect(ActivityEventMeta.meta(for: created).accent == .orange)

        let visibility = try event(#"{"type":"group_visibility_changed","message":{"group_id":1,"public_at":null}}"#)
        #expect(ActivityEventMeta.meta(for: visibility).label == "● VISIBILITY")
        #expect(ActivityEventMeta.meta(for: visibility).accent == .yellow)

        let register = try event("""
        {"type":"user_register","message":{"id":"u1","email":"a@b.c","name":"Anna",
        "image_url":null,"firebase_image_url":null,"country":null,
        "created_at":"2026-06-01T10:00:00Z","updated_at":"2026-06-01T10:00:00Z","is_admin":false}}
        """)
        #expect(ActivityEventMeta.meta(for: register).label == "★ WELCOME")
        #expect(ActivityEventMeta.meta(for: register).accent == .green)
    }

    @Test func unknownTypeFallsBackToUppercasedRawType() throws {
        let unknown = try event(#"{"type":"party_time","message":{"x":1}}"#)
        let meta = ActivityEventMeta.meta(for: unknown)
        #expect(meta.label == "PARTY_TIME")
        #expect(meta.accent == .cream)
        #expect(meta.symbol == nil)
    }

    // MARK: - Exact score copy

    @Test func exactScoreSoloWinReadsYouAndZeroOthers() {
        let text = ActivityFeedText.exactScore(userIDs: ["me"], currentUserID: "me")
        #expect(text == "You and 0 other(s) had the exact score")
    }

    @Test func exactScoreWithMeCountsTheOthers() {
        let text = ActivityFeedText.exactScore(userIDs: ["a", "me", "b"], currentUserID: "me")
        #expect(text == "You and 2 other(s) had the exact score")
    }

    @Test func exactScoreWithoutMeUsesPlayerCount() {
        #expect(ActivityFeedText.exactScore(userIDs: ["a", "b", "c"], currentUserID: "me") == "3 players had the exact score!")
        #expect(ActivityFeedText.exactScore(userIDs: [], currentUserID: nil) == "0 players had the exact score!")
        #expect(ActivityFeedText.exactScore(userIDs: ["a"], currentUserID: nil) == "1 players had the exact score!")
    }

    // MARK: - Group joined copy

    @Test func joinedWhoFallsBackToSomeoneForNilAndEmpty() {
        #expect(ActivityFeedText.joinedWho(nil) == "Someone")
        #expect(ActivityFeedText.joinedWho("") == "Someone")
        #expect(ActivityFeedText.joinedWho("Anna") == "Anna")
    }

    // MARK: - Visibility copy

    @Test func visibilityGroupNameResolvesOnlyCachedNonEmptyNames() {
        #expect(ActivityFeedText.visibilityGroupName(groupID: nil) { _ in "X" } == "A group")
        #expect(ActivityFeedText.visibilityGroupName(groupID: 7) { _ in nil } == "A group")
        #expect(ActivityFeedText.visibilityGroupName(groupID: 7) { _ in "" } == "A group")
        #expect(ActivityFeedText.visibilityGroupName(groupID: 7) { id in id == 7 ? "The Lads" : nil } == "The Lads")
    }

    @Test func visibilityStateFollowsPublicAt() {
        #expect(ActivityFeedText.visibilityState(publicAt: Date()) == "public")
        #expect(ActivityFeedText.visibilityState(publicAt: nil) == "private")
    }
}
