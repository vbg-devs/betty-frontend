import Foundation
import Observation

/// State machine behind the public-groups browse screen (web `browse.vue`).
///
/// Pagination is page-local (results are never stored in `GroupStore`): `reload()`
/// clears and fetches the first page, `loadMore()` appends with the cursor. Join
/// outcomes mirror the web handler exactly — 409 marks the row a member, 404 drops
/// the row, 403 is "blocked"; success mutates the row optimistically.
@Observable
final class BrowseGroupsModel {
    enum JoinOutcome: Equatable {
        case joined(groupID: Int, name: String)
        case alreadyMember(name: String)
        case blocked(name: String)
        case unavailable
        case failed
    }

    private let store: GroupStore

    private(set) var items: [PublicGroupItem] = []
    private(set) var nextCursor = ""
    private(set) var isLoading = false
    /// True once the first page has settled (success or failure) — gates the
    /// FETCHING vs NO MATCHES states.
    private(set) var hasLoaded = false
    private(set) var joiningID: Int?

    var query = ""
    var tournamentID: Int?

    var hasMore: Bool { !nextCursor.isEmpty }

    /// Bumped by every `reload()` — a fetch that resolves under an older generation is
    /// stale (the debounce only cancels the sleep, not an in-flight request) and must
    /// not append into the fresh list.
    private var loadGeneration = 0

    init(store: GroupStore) {
        self.store = store
    }

    /// Clears the list and fetches page one (search/filter change, pull-to-refresh).
    /// Invalidates any fetch still in flight.
    func reload() async throws {
        loadGeneration += 1
        items = []
        nextCursor = ""
        try await fetchPage(generation: loadGeneration)
    }

    /// Appends the next page; no-op when exhausted or already in flight.
    func loadMore() async throws {
        guard hasMore, !isLoading else { return }
        try await fetchPage(generation: loadGeneration)
    }

    /// `POST /group/:id/join` with the web's exact outcome handling.
    func join(_ item: PublicGroupItem) async -> JoinOutcome {
        joiningID = item.id
        defer { joiningID = nil }
        do {
            _ = try await store.joinPublic(id: item.id)
            mutate(id: item.id) {
                $0.isMember = true
                $0.memberCount += 1
            }
            return .joined(groupID: item.id, name: item.name)
        } catch let error as APIError {
            switch error.status {
            case 409:
                mutate(id: item.id) { $0.isMember = true }
                return .alreadyMember(name: item.name)
            case 403:
                return .blocked(name: item.name)
            case 404:
                items.removeAll { $0.id == item.id }
                return .unavailable
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    private func fetchPage(generation: Int) async throws {
        isLoading = true
        defer {
            // A stale fetch must not clear the loading state a newer reload owns.
            if generation == loadGeneration {
                isLoading = false
                hasLoaded = true
            }
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let page = try await store.listPublic(
            cursor: nextCursor.isEmpty ? nil : nextCursor,
            query: trimmed.isEmpty ? nil : trimmed,
            tournamentID: tournamentID,
            limit: nil
        )
        guard generation == loadGeneration else { return } // superseded by a newer reload
        items.append(contentsOf: page.items)
        nextCursor = page.nextCursor
    }

    private func mutate(id: Int, _ change: (inout PublicGroupItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }
}
