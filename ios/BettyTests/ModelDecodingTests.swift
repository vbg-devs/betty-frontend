import Foundation
import Testing
@testable import Betty

/// Decoding tests against REAL wire fixtures from the api-contract spec — pinning the
/// trickiest gotchas: string user IDs, nullable game status, the flat tournament
/// payload, null arrays, `PushTokens`, zero times, and the presign header map.
@Suite struct ModelDecodingTests {
    private let decoder = JSONCoding.makeDecoder()

    @Test func userDecodesStringUIDAndIgnoresPushTokens() throws {
        let json = """
        {
          "id": "x7gQ2bTfNzdR0kLuWqYpA1c9eSJ3",
          "email": "a@b.c",
          "name": "Ada",
          "image_url": null,
          "firebase_image_url": "https://lh3.googleusercontent.com/pic.png",
          "country": "SE",
          "created_at": "2026-06-07T12:34:56Z",
          "updated_at": "0001-01-01T00:00:00Z",
          "is_admin": false,
          "PushTokens": null
        }
        """
        let user = try decoder.decode(UserProfile.self, from: Data(json.utf8))
        #expect(user.id == "x7gQ2bTfNzdR0kLuWqYpA1c9eSJ3")
        #expect(user.imageURL == nil)
        #expect(user.firebaseImageURL == "https://lh3.googleusercontent.com/pic.png")
        #expect(user.country == "SE")
        #expect(user.isAdmin == false)
        // Go zero time decodes (year 1) rather than failing.
        let year = Calendar(identifier: .gregorian).component(.year, from: user.updatedAt)
        #expect(year == 1)
    }

    @Test func tournamentDetailDecodesFlatSiblingPoolsAndGames() throws {
        let json = """
        {
          "id": 1, "name": "Euro 2026", "image_url": null,
          "start_date": "2026-06-10T18:00:00Z", "end_date": "2026-07-10T20:00:00Z",
          "category_id": 1,
          "pools": [
            { "id": 1, "tournament_id": 1, "name": "Group A" },
            { "id": 2, "tournament_id": 1, "name": "Group B" }
          ],
          "games": [
            {
              "id": 9, "tournament_id": 1, "pool_id": 1,
              "home_team_id": 1, "away_team_id": 2,
              "home_team_score": 0, "away_team_score": 0,
              "start_date": "2026-06-10T18:00:00Z", "updated_at": null,
              "status": null
            },
            {
              "id": 10, "tournament_id": 1, "pool_id": 2,
              "home_team_id": 3, "away_team_id": 4,
              "home_team_score": 2, "away_team_score": 1,
              "start_date": "2026-06-11T18:00:00Z", "updated_at": "2026-06-11T20:00:00Z",
              "status": 1
            }
          ]
        }
        """
        let tournament = try decoder.decode(Tournament.self, from: Data(json.utf8))
        #expect(tournament.pools?.count == 2)
        #expect(tournament.games?.count == 2)

        // Nullable int status: nil = not finished, 1 = finished.
        let scheduled = tournament.games![0]
        #expect(scheduled.status == nil)
        #expect(!scheduled.isFinished)
        #expect(scheduled.homeTeamScore == 0) // non-null int even before play
        let finished = tournament.games![1]
        #expect(finished.status == 1)
        #expect(finished.isFinished)

        // Client-side join (pool.games is NOT a wire field).
        #expect(tournament.games(inPool: 1).map(\.id) == [9])
        #expect(tournament.games(inPool: 2).map(\.id) == [10])
        let joined = tournament.poolsWithGames
        #expect(joined.count == 2)
        #expect(joined[0].pool.name == "Group A")
        #expect(joined[0].games.map(\.id) == [9])
    }

    @Test func tournamentListHasNullPoolsAndGames() throws {
        let json = """
        [{
          "id": 1, "name": "Euro 2026", "image_url": "https://img/x.png",
          "start_date": "2026-06-10T18:00:00Z", "end_date": "2026-07-10T20:00:00Z",
          "category_id": 1, "pools": null, "games": null
        }]
        """
        let tournaments = try decoder.decode([Tournament].self, from: Data(json.utf8))
        #expect(tournaments.count == 1)
        #expect(tournaments[0].pools == nil)
        #expect(tournaments[0].games == nil)
        #expect(tournaments[0].poolsWithGames.isEmpty)
    }

    @Test func betDecodesStringUserIDAndNullPoints() throws {
        let json = """
        {
          "id": 1, "user_id": "x7gQ2bTfNzdR0kLuWqYpA1c9eSJ3", "game_id": 9, "group_id": 7,
          "user_points": null,
          "home_team_score": 2, "away_team_score": 1,
          "is_universal": false,
          "processed_at": null,
          "created_at": "2026-06-07T12:00:00Z", "updated_at": "2026-06-07T12:00:00Z"
        }
        """
        let bet = try decoder.decode(Bet.self, from: Data(json.utf8))
        #expect(bet.userID == "x7gQ2bTfNzdR0kLuWqYpA1c9eSJ3")
        #expect(bet.userPoints == nil)
        #expect(!bet.isProcessed)
        #expect(!bet.isUniversal)
    }

    @Test func postBetEchoDecodesZeroIDAndZeroTimes() throws {
        // The POST /bet 200 body: request echo with id 0 and zero timestamps.
        let json = """
        {
          "id": 0, "user_id": "uid-1", "game_id": 9, "group_id": 7,
          "user_points": null,
          "home_team_score": 2, "away_team_score": 1,
          "is_universal": true,
          "processed_at": null,
          "created_at": "0001-01-01T00:00:00Z", "updated_at": "0001-01-01T00:00:00Z"
        }
        """
        let echo = try decoder.decode(Bet.self, from: Data(json.utf8))
        #expect(echo.id == 0)
        #expect(echo.isUniversal)
    }

    @Test func groupDerivesPublicnessFromPublicAtNotIsPublic() throws {
        // is_public is ALWAYS false on reads (db:"-") — publicness = public_at != nil.
        let json = """
        {
          "id": 7, "name": "Office League",
          "tournament_id": 1, "tournament_name": "Euro 2026",
          "tournament_image_url": null, "header_image_url": null,
          "invite_code": "aB3-xY", "invite_url": "https://betty.social/dashboard/groups/join/aB3-xY",
          "welcome_message": null, "description": null,
          "correct_team_points": 1, "exact_result_points": 3,
          "allow_sneak_peek": true,
          "group_play_deadline": null,
          "mode": 0,
          "is_public": false,
          "public_at": "2026-06-01T08:00:00Z",
          "created_at": "2026-05-01T08:00:00Z", "updated_at": "2026-05-01T08:00:00Z",
          "members": [
            {
              "user_id": "uid-author", "name": "Ada", "nickname": null,
              "image_url": null, "score": 10, "normalized_score": 8, "access_level": 0
            },
            {
              "user_id": "uid-2", "name": null, "nickname": "Lovelace",
              "image_url": null, "score": 4, "normalized_score": 4, "access_level": 2
            }
          ]
        }
        """
        let group = try decoder.decode(Group.self, from: Data(json.utf8))
        #expect(group.isPublic) // despite "is_public": false on the wire
        #expect(group.members.count == 2)
        #expect(group.members[0].userID == "uid-author")
        #expect(group.members[0].isAuthor)
        #expect(group.members[1].name == nil)
        #expect(group.members[1].displayName == "Lovelace")
        #expect(group.member(withUserID: "uid-2")?.nickname == "Lovelace")
        #expect(group.member(withUserID: nil) == nil)
    }

    @Test func messageReactionsNullInPostResponseNormalizesToEmpty() throws {
        // POST /messageboard 201 has "reactions": null; GET has [].
        let postJSON = """
        {
          "id": 3, "group_id": 7, "user_id": "uid-1",
          "image_url": null, "body": "let's go",
          "created_at": "2026-06-07T12:00:00Z",
          "reactions": null
        }
        """
        let posted = try decoder.decode(GroupMessage.self, from: Data(postJSON.utf8))
        #expect(posted.reactions.isEmpty)

        let getJSON = """
        {
          "id": 3, "group_id": 7, "user_id": "uid-1",
          "image_url": "https://media.giphy.com/x.gif", "body": null,
          "created_at": "2026-06-07T12:00:00Z",
          "reactions": [
            { "user_id": "uid-2", "emoji_id": "🔥", "created_at": "2026-06-07T12:05:00Z" }
          ]
        }
        """
        let fetched = try decoder.decode(GroupMessage.self, from: Data(getJSON.utf8))
        #expect(fetched.reactions.count == 1)
        #expect(fetched.reactions[0].userID == "uid-2")
        #expect(fetched.reactions[0].emojiID == "🔥")
    }

    @Test func presignedUploadDecodesHeaderArrayMap() throws {
        let json = """
        {
          "key": "users/uid-1/profile/abc123.png",
          "upload_url": "https://r2.example.com/presigned?sig=x",
          "method": "PUT",
          "headers": { "Content-Length": ["12345"], "Content-Type": ["image/png"] },
          "public_url": "https://cdn.betty.social/users/uid-1/profile/abc123.png",
          "expires_at": "2026-06-07T12:39:56Z"
        }
        """
        let upload = try decoder.decode(PresignedUpload.self, from: Data(json.utf8))
        #expect(upload.headers["Content-Type"] == ["image/png"])
        #expect(upload.headers["Content-Length"] == ["12345"])
        #expect(upload.publicURL.hasPrefix("https://cdn.betty.social/"))
    }

    @Test func publicGroupListDecodesItemsAndCursor() throws {
        let json = """
        {
          "items": [{
            "id": 7, "name": "Office League", "description": null,
            "tournament_id": 1, "tournament_name": "Euro 2026",
            "tournament_image_url": null, "header_image_url": null,
            "correct_team_points": 1, "exact_result_points": 3, "allow_sneak_peek": true,
            "bet_mode": 0, "group_play_deadline": null,
            "public_at": "2026-06-01T08:00:00Z", "created_at": "2026-05-01T08:00:00Z",
            "member_count": 12, "is_member": false
          }],
          "next_cursor": "eyJpZCI6N30"
        }
        """
        let list = try decoder.decode(PublicGroupList.self, from: Data(json.utf8))
        #expect(list.items.count == 1)
        #expect(list.items[0].betMode == 0) // key is bet_mode here, mode on Group
        #expect(list.nextCursor == "eyJpZCI6N30")

        let emptyPage = try decoder.decode(PublicGroupList.self, from: Data(#"{"items": null, "next_cursor": ""}"#.utf8))
        #expect(emptyPage.items.isEmpty)
        #expect(emptyPage.nextCursor.isEmpty)
    }

    @Test func userGroupsResponseDecodesPlacements() throws {
        let json = """
        {
          "user": {
            "id": "uid-1", "email": "a@b.c", "name": "Ada",
            "image_url": null, "firebase_image_url": null, "country": null,
            "created_at": "2026-05-01T08:00:00Z", "updated_at": "2026-05-01T08:00:00Z",
            "is_admin": false, "PushTokens": null
          },
          "groups": [{
            "id": 7, "name": "Office League", "tournament_id": 1, "tournament_name": "Euro 2026",
            "tournament_image_url": null, "header_image_url": null,
            "bet_mode": 0, "public_at": null, "created_at": "2026-05-01T08:00:00Z",
            "score": 10, "normalized_score": 8, "placement": 1, "member_count": 5
          }]
        }
        """
        let response = try decoder.decode(UserGroupsResponse.self, from: Data(json.utf8))
        #expect(response.user.id == "uid-1")
        #expect(response.groups.count == 1)
        #expect(response.groups[0].placement == 1)
        #expect(response.groups[0].memberCount == 5)
    }

    @Test func leaderboardMemberRowsDecodeWithZeroedFields() throws {
        // Leaderboard rows: only user_id/name/image_url/normalized_score are real.
        let json = """
        [{ "user_id": "uid-1", "name": "Ada", "nickname": null, "image_url": null,
           "score": 0, "normalized_score": 12.5, "access_level": 0 }]
        """
        let members = try decoder.decode([Member].self, from: Data(json.utf8))
        #expect(members[0].userID == "uid-1")
        #expect(members[0].normalizedScore == 12.5)
        #expect(members[0].score == 0)
    }

    @Test func fractionalSecondDatesAlsoDecode() throws {
        let json = #"{ "id": 1, "tournament_id": 1, "name": "Group A" }"#
        _ = try decoder.decode(Pool.self, from: Data(json.utf8))
        let game = """
        {
          "id": 9, "tournament_id": 1, "pool_id": 1,
          "home_team_id": 1, "away_team_id": 2,
          "home_team_score": 0, "away_team_score": 0,
          "start_date": "2026-06-10T18:00:00.123456Z", "updated_at": null, "status": 0
        }
        """
        let decoded = try decoder.decode(Game.self, from: Data(game.utf8))
        #expect(decoded.status == 0)
        #expect(!decoded.isFinished) // 0 is NOT finished — only 1 is
    }
}

@Suite struct DerivedLogicTests {
    @Test func denseRankingSharesPlacesAndIncrementsByOne() {
        struct Row: Identifiable { let id: Int; let score: Double }
        let rows = [Row(id: 1, score: 10), Row(id: 2, score: 8), Row(id: 3, score: 10)]
        let ranked = DenseRanking.rank(rows, score: \.score)
        // 10, 10, 8 → places 1, 1, 2 (dense, not competition 1,1,3)
        #expect(ranked.map(\.place) == [1, 1, 2])
        #expect(Set(ranked.prefix(2).map(\.item.id)) == [1, 3])
    }

    @Test func largestRemainderPinnedCases() {
        #expect(LargestRemainder.percentages(home: 2, away: 1, tie: 1) == (50, 25, 25))
        #expect(LargestRemainder.percentages(home: 2, away: 0, tie: 0) == (100, 0, 0))
        #expect(LargestRemainder.percentages(home: 2, away: 1, tie: 0) == (67, 0, 33))
        #expect(LargestRemainder.percentages(home: 1, away: 1, tie: 1) == (34, 33, 33))
        #expect(LargestRemainder.percentages(home: 3, away: 2, tie: 2) == (43, 28, 29))
        #expect(LargestRemainder.percentages(home: 0, away: 0, tie: 0) == (0, 0, 0))
    }
}

/// `FIFAProposal` enrichment fields, with a focus on the optional kickoff: the date must
/// degrade gracefully (absent / Go zero time / malformed → nil) and a single bad row must
/// never abort the whole `[FIFAProposal]` decode.
@Suite struct FIFAProposalDecodingTests {
    private let decoder = JSONCoding.makeDecoder()

    private func proposalJSON(id: Int = 1, kind: String = "initial", prevHome: String = "null",
                              prevAway: String = "null", startDate: String? = "2026-06-20T17:00:00Z") -> String {
        var fields = [
            "\"id\": \(id)",
            "\"game_id\": 808",
            "\"match_id\": \"400021440\"",
            "\"home_team_score\": 2",
            "\"away_team_score\": 1",
            "\"kind\": \"\(kind)\"",
            "\"status\": \"pending\"",
            "\"source\": \"proposal\"",
            "\"prev_home_score\": \(prevHome)",
            "\"prev_away_score\": \(prevAway)",
            "\"game_home_team\": \"Netherlands\"",
            "\"game_away_team\": \"Sweden\"",
        ]
        if let startDate {
            fields.append("\"game_start_date\": \"\(startDate)\"")
        }
        return "{\(fields.joined(separator: ", "))}"
    }

    @Test func decodesEnrichedProposalWithKickoff() throws {
        let p = try decoder.decode(FIFAProposal.self, from: Data(proposalJSON().utf8))
        #expect(p.id == 1)
        #expect(p.gameHomeTeam == "Netherlands")
        #expect(p.homeTeamScore == 2)
        #expect(p.gameStartDate != nil)
        #expect(p.prevHomeScore == nil)
    }

    @Test func correctionAndRollbackCarryPrevScores() throws {
        let correction = try decoder.decode(FIFAProposal.self, from: Data(proposalJSON(kind: "correction", prevHome: "1", prevAway: "0").utf8))
        #expect(correction.prevHomeScore == 1)
        #expect(correction.prevAwayScore == 0)

        let rollback = try decoder.decode(FIFAProposal.self, from: Data(proposalJSON(kind: "rollback", prevHome: "3", prevAway: "2").utf8))
        #expect(rollback.kind == "rollback")
        #expect(rollback.prevHomeScore == 3)
        #expect(rollback.prevAwayScore == 2)
    }

    @Test func missingKickoffDecodesToNil() throws {
        let p = try decoder.decode(FIFAProposal.self, from: Data(proposalJSON(startDate: nil).utf8))
        #expect(p.gameStartDate == nil)
    }

    @Test func goZeroTimeKickoffDecodesToNil() throws {
        // Go's zero time parses as a real (year 1) date, but means "no kickoff" — it must
        // not render as a sentinel; the model maps it to nil.
        let p = try decoder.decode(FIFAProposal.self, from: Data(proposalJSON(startDate: "0001-01-01T00:00:00Z").utf8))
        #expect(p.gameStartDate == nil)
    }

    @Test func malformedKickoffDecodesToNilWithoutThrowing() throws {
        let p = try decoder.decode(FIFAProposal.self, from: Data(proposalJSON(startDate: "not-a-date").utf8))
        #expect(p.gameStartDate == nil)
        #expect(p.id == 1) // the rest of the row still decoded
    }

    @Test func oneMalformedDateDoesNotAbortTheWholeArray() throws {
        let good = proposalJSON()
        let bad = proposalJSON(id: 2, startDate: "garbage")
        let array = "[\(good), \(bad)]"
        let proposals = try decoder.decode([FIFAProposal].self, from: Data(array.utf8))
        #expect(proposals.count == 2) // a single bad date no longer fails the list
        #expect(proposals[0].gameStartDate != nil)
        #expect(proposals[1].gameStartDate == nil)
    }
}
