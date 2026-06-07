import Foundation
import Testing
@testable import Betty

private final class StubTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token" }
}

/// Pins the web `/leaderboard` rules: hero title splitting, the ENDED suffix rule,
/// raw-number score rendering, the default-tournament pick, and the leaderboard wire row.
@Suite struct GlobalLeaderboardLogicTests {
    private let decoder = JSONCoding.makeDecoder()

    private nonisolated func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func tournamentJSON(id: Int, name: String, start: String, end: String?) -> String {
        let endField = end.map { "\"\($0)\"" } ?? "null"
        return #"{"id": \#(id), "name": "\#(name)", "image_url": null, "start_date": "\#(start)", "end_date": \#(endField), "category_id": 1}"#
    }

    private func tournament(id: Int = 1, name: String = "Euro 2026", start: Date, end: Date?) throws -> Tournament {
        try decoder.decode(
            Tournament.self,
            from: Data(tournamentJSON(id: id, name: name, start: iso(start), end: end.map(iso)).utf8)
        )
    }

    // MARK: - Hero title splitting

    @Test func missingOrEmptyNameFallsBackToTournament() {
        #expect(GlobalLeaderboardLogic.titleParts(nil) == ("TOURNAMENT", ""))
        #expect(GlobalLeaderboardLogic.titleParts("") == ("TOURNAMENT", ""))
    }

    @Test func twoOrFewerWordsStayOnOneLineUppercased() {
        #expect(GlobalLeaderboardLogic.titleParts("Euro 2026") == ("EURO 2026", ""))
        #expect(GlobalLeaderboardLogic.titleParts("Allsvenskan") == ("ALLSVENSKAN", ""))
    }

    @Test func threeWordsSplitTwoThenOne() {
        #expect(GlobalLeaderboardLogic.titleParts("World Cup 2026") == ("WORLD CUP", "2026"))
    }

    @Test func fourWordsSplitEvenly() {
        #expect(GlobalLeaderboardLogic.titleParts("Fifa World Cup 2026") == ("FIFA WORLD", "CUP 2026"))
    }

    // MARK: - ENDED suffix

    @Test func pastEndDateIsEnded() throws {
        let ended = try tournament(start: Date().addingTimeInterval(-86_400 * 30), end: Date().addingTimeInterval(-3_600))
        #expect(GlobalLeaderboardLogic.isEnded(ended))
        #expect(GlobalLeaderboardLogic.pickerLabel(for: ended).hasSuffix(" · ENDED"))
    }

    @Test func exactlyAtEndDateOrWithoutOneIsNotEnded() throws {
        // Whole seconds — the fixture round-trips through ISO8601, which drops
        // fractional seconds and would otherwise shift "ends exactly now" into the past.
        let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let endsNow = try tournament(start: now.addingTimeInterval(-86_400), end: now)
        #expect(!GlobalLeaderboardLogic.isEnded(endsNow, at: now))
        let openEnded = try tournament(start: now.addingTimeInterval(-86_400), end: nil)
        #expect(!GlobalLeaderboardLogic.isEnded(openEnded, at: now))
        #expect(GlobalLeaderboardLogic.pickerLabel(for: openEnded, at: now) == "Euro 2026")
    }

    // MARK: - Score rendering (web prints the raw JSON number)

    @Test func integerValuedScoresDropTheDecimal() {
        #expect(GlobalLeaderboardLogic.scoreText(7.0) == "7")
        #expect(GlobalLeaderboardLogic.scoreText(0) == "0")
    }

    @Test func fractionalScoresKeepTheirDecimals() {
        #expect(GlobalLeaderboardLogic.scoreText(7.5) == "7.5")
    }

    // MARK: - Default tournament pick (web /leaderboard redirect rule)

    @Test func picksRunningTournamentWithLatestStart() async throws {
        let now = Date()
        let json = "[" + [
            tournamentJSON(id: 1, name: "Old Cup", start: iso(now.addingTimeInterval(-86_400 * 10)), end: iso(now.addingTimeInterval(86_400))),
            tournamentJSON(id: 2, name: "New Cup", start: iso(now.addingTimeInterval(-86_400)), end: iso(now.addingTimeInterval(86_400 * 10))),
        ].joined(separator: ",") + "]"
        let store = try await loadedStore(listJSON: json)
        #expect(store.defaultLeaderboardTournament?.id == 2)
    }

    @Test func prefersRunningOverEndedWithLaterStart() async throws {
        let now = Date()
        let json = "[" + [
            // Ended, but started most recently.
            tournamentJSON(id: 1, name: "Sprint Cup", start: iso(now.addingTimeInterval(-3_600)), end: iso(now.addingTimeInterval(-60))),
            // Running, started long ago.
            tournamentJSON(id: 2, name: "Marathon Cup", start: iso(now.addingTimeInterval(-86_400 * 10)), end: iso(now.addingTimeInterval(86_400 * 10))),
        ].joined(separator: ",") + "]"
        let store = try await loadedStore(listJSON: json)
        #expect(store.defaultLeaderboardTournament?.id == 2)
    }

    @Test func fallsBackToLatestStartedWhenAllEnded() async throws {
        let now = Date()
        let json = "[" + [
            tournamentJSON(id: 1, name: "Ancient Cup", start: iso(now.addingTimeInterval(-86_400 * 20)), end: iso(now.addingTimeInterval(-86_400 * 10))),
            tournamentJSON(id: 2, name: "Recent Cup", start: iso(now.addingTimeInterval(-86_400 * 5)), end: iso(now.addingTimeInterval(-86_400))),
        ].joined(separator: ",") + "]"
        let store = try await loadedStore(listJSON: json)
        #expect(store.defaultLeaderboardTournament?.id == 2)
    }

    @Test func treatsMissingEndDateAsRunning() async throws {
        let now = Date()
        let json = "[" + [
            tournamentJSON(id: 1, name: "Closed Cup", start: iso(now.addingTimeInterval(-3_600)), end: iso(now.addingTimeInterval(-60))),
            tournamentJSON(id: 2, name: "Open Cup", start: iso(now.addingTimeInterval(-86_400 * 30)), end: nil),
        ].joined(separator: ",") + "]"
        let store = try await loadedStore(listJSON: json)
        #expect(store.defaultLeaderboardTournament?.id == 2)
    }

    @Test func noTournamentsMeansNoDefault() async throws {
        let store = try await loadedStore(listJSON: "[]")
        #expect(store.defaultLeaderboardTournament == nil)
    }

    private func loadedStore(listJSON: String) async throws -> TournamentStore {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: StubTokens())
        transport.handler = { request in
            MockTransport.json(listJSON, url: request.url)
        }
        let store = TournamentStore(api: api)
        try await store.load()
        return store
    }

    // MARK: - Leaderboard wire rows

    @Test func leaderboardRowsCarryOnlyTheRealFields() async throws {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: StubTokens())
        transport.handler = { request in
            MockTransport.json(
                #"[{"user_id": "uid-9", "name": "Ada", "nickname": null, "image_url": null, "score": 0, "normalized_score": 7.5, "access_level": 0}]"#,
                url: request.url
            )
        }

        let rows = try await api.tournamentLeaderboard(id: 5, limit: 100)

        let url = try #require(transport.requests.first?.url?.absoluteString)
        #expect(url.contains("/tournament/5/leaderboard"))
        #expect(url.contains("limit=100"))
        #expect(rows.count == 1)
        #expect(rows[0].userID == "uid-9")
        #expect(rows[0].normalizedScore == 7.5)
        #expect(rows[0].score == 0) // zeroed on this route — never display it
        #expect(rows[0].nickname == nil)
    }

    @Test func leaderboardRanksWithDenseTies() {
        let members = [
            Member(userID: "a", name: "A", nickname: nil, imageURL: nil, score: 0, normalizedScore: 10, accessLevel: 2),
            Member(userID: "b", name: "B", nickname: nil, imageURL: nil, score: 0, normalizedScore: 10, accessLevel: 2),
            Member(userID: "c", name: "C", nickname: nil, imageURL: nil, score: 0, normalizedScore: 8, accessLevel: 2),
        ]
        let ranked = DenseRanking.rank(members, score: { $0.normalizedScore })
        #expect(ranked.map(\.place) == [1, 1, 2]) // dense, not competition (1,1,3)
    }
}
