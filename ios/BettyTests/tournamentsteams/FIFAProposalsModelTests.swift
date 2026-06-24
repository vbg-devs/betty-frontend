import Foundation
import Testing
@testable import Betty

private final class MockTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token" }
}

/// `{ "proposals": [...] }` wire body for the given (id, status) rows.
private func proposalsBody(_ rows: [(id: Int, status: String)]) -> String {
    let items = rows.map { row in
        """
        {"id": \(row.id), "game_id": \(800 + row.id), "match_id": "m\(row.id)",
         "home_team_score": 2, "away_team_score": 1, "kind": "initial",
         "status": "\(row.status)", "source": "proposal",
         "prev_home_score": null, "prev_away_score": null,
         "game_home_team": "Home\(row.id)", "game_away_team": "Away\(row.id)",
         "game_start_date": "2026-06-20T17:00:00Z"}
        """
    }.joined(separator: ",")
    return "{\"proposals\": [\(items)]}"
}

@Suite struct FIFAProposalsModelTests {
    private func makeModel() -> (FIFAProposalsModel, MockTransport) {
        let transport = MockTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())
        return (FIFAProposalsModel(api: api), transport)
    }

    @Test func confirmAppliesAndDropsTheRow() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            if request.url?.path.contains("/confirm") == true {
                return MockTransport.json("null", url: request.url)
            }
            return MockTransport.json(proposalsBody([(1, "pending"), (2, "pending")]), url: request.url)
        }

        await model.load(tab: .pending)
        #expect(model.proposals.map(\.id) == [1, 2])

        try await model.confirm(model.proposals[0])

        #expect(model.proposals.map(\.id) == [2])
        #expect(transport.requests.contains {
            $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/proposals/1/confirm") == true
        })
    }

    @Test func confirmGoneDropsTheStaleRowAndRethrows() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            if request.url?.path.contains("/confirm") == true {
                return MockTransport.json("", status: 410, url: request.url) // already auto-applied
            }
            return MockTransport.json(proposalsBody([(1, "pending")]), url: request.url)
        }

        await model.load(tab: .pending)

        do {
            try await model.confirm(model.proposals[0])
            Issue.record("expected a 410 to throw")
        } catch let error as APIError {
            guard case .gone = error else {
                Issue.record("expected .gone, got \(error)")
                return
            }
        }
        // The stale pending row is dropped so the admin stops re-tapping a dead proposal.
        #expect(model.proposals.isEmpty)
    }

    @Test func confirmConflictKeepsTheRowAndRethrows() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            if request.url?.path.contains("/confirm") == true {
                return MockTransport.json("", status: 409, url: request.url) // apply racing
            }
            return MockTransport.json(proposalsBody([(1, "pending")]), url: request.url)
        }

        await model.load(tab: .pending)

        do {
            try await model.confirm(model.proposals[0])
            Issue.record("expected a 409 to throw")
        } catch let error as APIError {
            guard case .conflict = error else {
                Issue.record("expected .conflict, got \(error)")
                return
            }
        }
        // A racing apply is not resolved — the row stays for a later retry.
        #expect(model.proposals.map(\.id) == [1])
    }

    @Test func dismissDropsTheRow() async throws {
        let (model, transport) = makeModel()
        transport.handler = { request in
            if request.url?.path.contains("/dismiss") == true {
                return MockTransport.json("null", url: request.url)
            }
            return MockTransport.json(proposalsBody([(1, "pending"), (2, "pending")]), url: request.url)
        }

        await model.load(tab: .pending)
        try await model.dismiss(model.proposals[0])

        #expect(model.proposals.map(\.id) == [2])
        #expect(transport.requests.contains {
            $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/proposals/1/dismiss") == true
        })
    }

    /// The race the `loadToken` guard exists for: switching to the Applied tab while a
    /// confirm is in flight must not let the resumed confirm delete the freshly-loaded
    /// applied row (same id, different list).
    @Test func tabSwitchDuringConfirmKeepsTheFreshlyLoadedAppliedRow() async throws {
        let transport = GatedTransport()
        let api = APIClient(transport: transport, tokens: MockTokens())
        let model = FIFAProposalsModel(api: api)

        transport.enqueue(proposalsBody([(1, "pending")]))
        await model.load(tab: .pending)
        #expect(model.proposals.map(\.id) == [1])

        // Park the confirm POST mid-flight, then start it.
        transport.gate(pathContains: "/confirm")
        let target = model.proposals[0]
        let confirmTask = Task { try await model.confirm(target) }
        await transport.waitUntilParked()

        // Admin switches to Applied — proposal 1 now shows as an applied-history row.
        transport.enqueue(proposalsBody([(1, "applied")]))
        await model.load(tab: .applied)
        #expect(model.tab == .applied)
        #expect(model.proposals.map(\.id) == [1])

        // Release the confirm: it succeeds but must NOT remove the applied row.
        transport.release()
        try await confirmTask.value

        #expect(model.tab == .applied)
        #expect(model.proposals.map(\.id) == [1])
    }
}

/// A transport that parks the first request whose path contains `gatePath` until
/// `release()`, so a test can interleave other model calls while a network call is in
/// flight. The whole test target is MainActor-isolated, so all access is serialized.
private final class GatedTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private var responses: [(Data, HTTPURLResponse)] = []
    private var gatePath: String?

    private var parked = false
    private var parkContinuation: CheckedContinuation<Void, Never>?
    private var arrivalWaiter: CheckedContinuation<Void, Never>?

    func enqueue(_ body: String, status: Int = 200) {
        responses.append(MockTransport.json(body, status: status))
    }

    func gate(pathContains path: String) { gatePath = path }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if let gatePath, request.url?.path.contains(gatePath) == true {
            self.gatePath = nil
            parked = true
            arrivalWaiter?.resume()
            arrivalWaiter = nil
            await withCheckedContinuation { parkContinuation = $0 }
        }
        guard !responses.isEmpty else { return MockTransport.json("null") }
        return responses.removeFirst()
    }

    /// Suspend the caller until the gated request has parked inside `send`.
    func waitUntilParked() async {
        if parked { return }
        await withCheckedContinuation { arrivalWaiter = $0 }
    }

    /// Resume the parked request so it returns its response.
    func release() {
        parkContinuation?.resume()
        parkContinuation = nil
    }
}
