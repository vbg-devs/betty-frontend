import Foundation
import Testing
@testable import Betty

/// Holds every request suspended until `resolve(at:body:)` — lets tests interleave
/// overlapping reloads deterministically.
private final class SuspendingTransport: HTTPTransport {
    private var pending: [(request: URLRequest, continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>)] = []

    var pendingCount: Int { pending.count }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            pending.append((request, continuation))
        }
    }

    /// Indices are stable — entries are kept in arrival order and resolved once each.
    func resolve(at index: Int, body: String) {
        let entry = pending[index]
        entry.continuation.resume(returning: MockTransport.json(body, url: entry.request.url))
    }
}

@Suite struct BrowseGroupsModelTests {
    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    private func makeModel(transport: MockTransport) -> BrowseGroupsModel {
        let api = APIClient(transport: transport, tokens: GroupMgmtMockTokens())
        return BrowseGroupsModel(store: GroupStore(api: api))
    }

    private func pageJSON(ids: [Int], nextCursor: String, isMember: Bool = false) -> String {
        let items = ids.map {
            GroupMgmtFixtures.publicGroupItemJSON(id: $0, isMember: isMember)
        }.joined(separator: ",")
        return #"{"items":[\#(items)],"next_cursor":"\#(nextCursor)"}"#
    }

    @Test func loadMoreAppendsAndSendsCursor() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        transport.handler = { request in
            let query = request.url?.query() ?? ""
            if query.contains("cursor=abc") {
                return MockTransport.json(self.pageJSON(ids: [3], nextCursor: ""), url: request.url)
            }
            return MockTransport.json(self.pageJSON(ids: [1, 2], nextCursor: "abc"), url: request.url)
        }

        try await model.reload()
        #expect(model.items.map(\.id) == [1, 2])
        #expect(model.hasMore)

        try await model.loadMore()
        #expect(model.items.map(\.id) == [1, 2, 3])
        #expect(!model.hasMore)
        #expect(model.hasLoaded)

        // No more pages → loadMore is a no-op.
        try await model.loadMore()
        #expect(transport.requests.count == 2)
    }

    @Test func reloadClearsListAndDropsCursor() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        transport.handler = { request in
            MockTransport.json(self.pageJSON(ids: [1], nextCursor: "abc"), url: request.url)
        }

        try await model.reload()
        try await model.reload()

        #expect(model.items.map(\.id) == [1]) // replaced, not appended
        let secondQuery = transport.requests[1].url?.query() ?? ""
        #expect(!secondQuery.contains("cursor"))
    }

    @Test func queryIsTrimmedAndOmittedWhenBlank() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        transport.handler = { request in
            MockTransport.json(self.pageJSON(ids: [], nextCursor: ""), url: request.url)
        }

        model.query = "   "
        try await model.reload()
        let blankQuery = transport.requests[0].url?.query() ?? ""
        #expect(!blankQuery.contains("q="))

        model.query = " roast "
        try await model.reload()
        let trimmedQuery = transport.requests[1].url?.query() ?? ""
        #expect(trimmedQuery.contains("q=roast"))
    }

    @Test func failedReloadKeepsListEmptyAndMarksLoaded() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        transport.handler = { request in
            MockTransport.json("", status: 500, url: request.url)
        }

        await #expect(throws: APIError.self) {
            try await model.reload()
        }
        #expect(model.items.isEmpty)
        #expect(model.hasLoaded)
        #expect(!model.isLoading)
    }

    // MARK: overlapping loads (debounce cancels only the sleep, not the request)

    @Test func staleReloadFinishingLastIsDiscarded() async throws {
        let transport = SuspendingTransport()
        let api = APIClient(transport: transport, tokens: GroupMgmtMockTokens())
        let model = BrowseGroupsModel(store: GroupStore(api: api))

        let first = Task { try await model.reload() }
        await waitUntil { transport.pendingCount == 1 }
        let second = Task { try await model.reload() }
        await waitUntil { transport.pendingCount == 2 }

        // The NEWER reload resolves first; the stale one lands afterwards.
        transport.resolve(at: 1, body: pageJSON(ids: [3], nextCursor: ""))
        try await second.value
        transport.resolve(at: 0, body: pageJSON(ids: [1, 2], nextCursor: "abc"))
        try await first.value

        #expect(model.items.map(\.id) == [3]) // stale page did not interleave
        #expect(!model.hasMore)               // stale cursor discarded too
        #expect(!model.isLoading)
        #expect(model.hasLoaded)
    }

    @Test func reloadInvalidatesAnInFlightLoadMore() async throws {
        let transport = SuspendingTransport()
        let api = APIClient(transport: transport, tokens: GroupMgmtMockTokens())
        let model = BrowseGroupsModel(store: GroupStore(api: api))

        let initial = Task { try await model.reload() }
        await waitUntil { transport.pendingCount == 1 }
        transport.resolve(at: 0, body: pageJSON(ids: [1], nextCursor: "abc"))
        try await initial.value

        let more = Task { try await model.loadMore() }
        await waitUntil { transport.pendingCount == 2 }
        let fresh = Task { try await model.reload() }
        await waitUntil { transport.pendingCount == 3 }

        transport.resolve(at: 2, body: pageJSON(ids: [9], nextCursor: ""))
        try await fresh.value
        transport.resolve(at: 1, body: pageJSON(ids: [2], nextCursor: "def"))
        try await more.value

        #expect(model.items.map(\.id) == [9]) // superseded page-2 result dropped
        #expect(!model.hasMore)
        #expect(!model.isLoading)
    }

    // MARK: join outcomes (web browse.vue join handler, pinned)

    private func loadOneItem(_ transport: MockTransport, model: BrowseGroupsModel) async throws {
        transport.handler = { request in
            MockTransport.json(self.pageJSON(ids: [1], nextCursor: ""), url: request.url)
        }
        try await model.reload()
    }

    @Test func joinSuccessMarksMemberAndBumpsCount() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        try await loadOneItem(transport, model: model)
        transport.handler = { request in
            if request.url?.path().contains("/group/1/join") == true {
                return MockTransport.json(#"{"group_id":1}"#, url: request.url)
            }
            return MockTransport.json("[]", url: request.url) // GET /groups reload
        }

        let outcome = await model.join(model.items[0])

        #expect(outcome == .joined(groupID: 1, name: "Sunday Roast XI"))
        #expect(model.items[0].isMember)
        #expect(model.items[0].memberCount == 3)
        #expect(model.joiningID == nil)
    }

    @Test func join409MarksMemberWithoutCountBump() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        try await loadOneItem(transport, model: model)
        transport.handler = { request in
            MockTransport.json("", status: 409, url: request.url)
        }

        let outcome = await model.join(model.items[0])

        #expect(outcome == .alreadyMember(name: "Sunday Roast XI"))
        #expect(model.items[0].isMember)
        #expect(model.items[0].memberCount == 2)
    }

    @Test func join404DropsTheRow() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        try await loadOneItem(transport, model: model)
        transport.handler = { request in
            MockTransport.json("", status: 404, url: request.url)
        }

        let outcome = await model.join(model.items[0])

        #expect(outcome == .unavailable)
        #expect(model.items.isEmpty)
    }

    @Test func join403IsBlockedAndLeavesRowUntouched() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        try await loadOneItem(transport, model: model)
        transport.handler = { request in
            MockTransport.json("", status: 403, url: request.url)
        }

        let outcome = await model.join(model.items[0])

        #expect(outcome == .blocked(name: "Sunday Roast XI"))
        #expect(!model.items[0].isMember)
        #expect(model.items[0].memberCount == 2)
    }

    @Test func joinServerErrorIsGenericFailure() async throws {
        let transport = MockTransport()
        let model = makeModel(transport: transport)
        try await loadOneItem(transport, model: model)
        transport.handler = { request in
            MockTransport.json("", status: 500, url: request.url)
        }

        let outcome = await model.join(model.items[0])

        #expect(outcome == .failed)
        #expect(model.items.count == 1)
    }
}
