import Foundation
import Testing
@testable import Betty

private final class MockTokens: TokenProviding {
    var isSignedIn = true
    var current = "token-1"
    var refreshed = "token-2"
    private(set) var refreshCalls = 0

    func validIDToken() async throws -> String { current }

    func tokenAfterAuthFailure() async throws -> String {
        refreshCalls += 1
        return refreshed
    }
}

@Suite struct APIClientTests {
    @Test func throwsBeforeNetworkWhenSignedOut() async {
        let transport = MockTransport()
        let tokens = MockTokens()
        tokens.isSignedIn = false
        let api = APIClient(transport: transport, tokens: tokens)

        await #expect(throws: APIError.self) {
            _ = try await api.groups()
        }
        #expect(transport.requests.isEmpty) // no I/O when unauthenticated
    }

    @Test func setsBearerAndRetriesOnceAfter401() async throws {
        let transport = MockTransport()
        let tokens = MockTokens()
        let api = APIClient(transport: transport, tokens: tokens)
        transport.handler = { request in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer token-1" {
                return MockTransport.json(#"{"error":"Invalid API token"}"#, status: 401, url: request.url)
            }
            return MockTransport.json("[]", url: request.url)
        }

        let groups = try await api.groups()

        #expect(groups.isEmpty)
        #expect(tokens.refreshCalls == 1)
        #expect(transport.requests.count == 2)
        #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer token-2")
    }

    @Test func handler401WithEmptyBodyIsNeverRetried() async {
        let transport = MockTransport()
        let tokens = MockTokens()
        let api = APIClient(transport: transport, tokens: tokens)
        transport.handler = { request in
            // Handler authorization failure: `c.Status(401)` — empty body, the request
            // DID execute. A blind retry would re-run the mutation.
            MockTransport.json("", status: 401, url: request.url)
        }

        do {
            _ = try await api.rotateInviteCode(groupID: 7)
            Issue.record("expected unauthorized")
        } catch let error as APIError {
            #expect(error.status == 401)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
        #expect(transport.requests.count == 1) // no retry
        #expect(tokens.refreshCalls == 0)      // no forced refresh either
    }

    @Test func secondConsecutive401SurfacesUnauthorized() async {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())
        transport.handler = { request in
            MockTransport.json(#"{"error":"Invalid API token"}"#, status: 401, url: request.url)
        }

        do {
            _ = try await api.groups()
            Issue.record("expected unauthorized")
        } catch let error as APIError {
            #expect(error.status == 401)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
        #expect(transport.requests.count == 2) // exactly one retry
    }

    @Test func statusCodesMapToTypedErrors() async {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())

        let cases: [(Int, Int?)] = [(403, 403), (404, 404), (409, 409), (423, 423), (413, 413), (415, 415), (503, 503)]
        for (wireStatus, expected) in cases {
            transport.handler = { request in
                MockTransport.json("", status: wireStatus, url: request.url)
            }
            do {
                _ = try await api.getMe()
                Issue.record("expected error for \(wireStatus)")
            } catch let error as APIError {
                #expect(error.status == expected)
            } catch {
                Issue.record("unexpected error type: \(error)")
            }
        }
    }

    @Test func nullArrayBodyDecodesAsEmptyList() async throws {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())
        transport.handler = { request in
            MockTransport.json("null", url: request.url)
        }
        let bets = try await api.bets(groupID: 7)
        #expect(bets.isEmpty)
    }

    @Test func betsByGameDedupesJoinFanOutRows() async throws {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())
        let row = """
        {"id": 5, "user_id": "uid-1", "game_id": 9, "group_id": 7,
         "user_points": null, "home_team_score": 2, "away_team_score": 1,
         "is_universal": false, "processed_at": null,
         "created_at": "2026-06-07T12:00:00Z", "updated_at": "2026-06-07T12:00:00Z"}
        """
        transport.handler = { request in
            MockTransport.json("[\(row), \(row), \(row)]", url: request.url)
        }

        let bets = try await api.bets(gameID: 9, groupID: 7)

        #expect(bets.count == 1) // wire repeats the row once per membership
        #expect(bets[0].id == 5)
    }

    @Test func groupByIDMaps500ToNotFound() async {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())
        transport.handler = { request in
            MockTransport.json("", status: 500, url: request.url)
        }
        do {
            _ = try await api.group(id: 99)
            Issue.record("expected notFound")
        } catch let error as APIError {
            #expect(error.status == 404) // contract quirk: 500 means "not available" here
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func publicGroupsQueryOmitsEmptyCursorAndQuery() async throws {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())
        transport.handler = { request in
            MockTransport.json(#"{"items": [], "next_cursor": ""}"#, url: request.url)
        }

        _ = try await api.publicGroups(cursor: "", query: nil, tournamentID: 0, limit: 20)

        let url = try #require(transport.requests.first?.url?.absoluteString)
        #expect(!url.contains("cursor="))
        #expect(!url.contains("q="))
        #expect(url.contains("tournament_id=0")) // include even when 0 (pinned)
        #expect(url.contains("limit=20"))
    }
}
