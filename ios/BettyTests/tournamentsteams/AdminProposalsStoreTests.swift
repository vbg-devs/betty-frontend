import Foundation
import Testing
@testable import Betty

@Suite("AdminProposalsStore")
struct AdminProposalsStoreTests {
    /// Build a store whose fetch returns the given counts in order across refreshes.
    private func store(returning counts: [Int]) -> (AdminProposalsStore, () -> [Int]) {
        var index = 0
        var notified: [Int] = []
        let store = AdminProposalsStore(fetchCount: {
            defer { index += 1 }
            return counts[min(index, counts.count - 1)]
        })
        store.onNewProposals = { notified.append($0) }
        return (store, { notified })
    }

    @Test("refresh stores the pending count")
    func refreshStoresCount() async {
        let (store, _) = store(returning: [3])
        await store.refresh()
        #expect(store.pendingCount == 3)
    }

    @Test("does not notify on the first load")
    func noNotifyOnFirstLoad() async {
        let (store, notified) = store(returning: [2])
        await store.refresh()
        #expect(notified().isEmpty)
        #expect(store.pendingCount == 2)
    }

    @Test("notifies only when the count increases")
    func notifiesOnIncrease() async {
        let (store, notified) = store(returning: [1, 3])
        await store.refresh()
        await store.refresh()
        #expect(notified() == [3])
        #expect(store.pendingCount == 3)
    }

    @Test("stays silent when the count drops")
    func silentOnDecrease() async {
        let (store, notified) = store(returning: [3, 1])
        await store.refresh()
        await store.refresh()
        #expect(notified().isEmpty)
        #expect(store.pendingCount == 1)
    }

    @Test("swallows fetch errors without throwing")
    func swallowsErrors() async {
        struct Boom: Error {}
        let store = AdminProposalsStore(fetchCount: { throw Boom() })
        await store.refresh()
        #expect(store.pendingCount == 0)
    }

    @Test("reset clears the count and the notify baseline")
    func resetClearsBaseline() async {
        let (store, notified) = store(returning: [5, 9])
        await store.refresh()
        store.reset()
        await store.refresh()
        #expect(notified().isEmpty)
        #expect(store.pendingCount == 9)
    }
}
