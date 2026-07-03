import Foundation
import Observation

/// Live activity feed ring buffer fed by `WebSocketService`.
///
/// Web parity: client-assigned incrementing ids (starting 0), capped at the
/// `capacity` most recent (web keeps 5), trimmed from the front; `remove` drops the
/// FIRST match only; pings never reach the store (filtered by the socket service).
@Observable
final class ActivityFeedStore {
    struct Entry: Identifiable {
        let id: Int
        let event: BettyEvent
        let timestamp: Date
    }

    /// Web keeps 5; raise for a longer native scrollback if desired.
    var capacity: Int

    private(set) var entries: [Entry] = []
    private var nextID = 0
    private var consumeTask: Task<Void, Never>?

    init(capacity: Int = 5) {
        self.capacity = capacity
    }

    func add(_ event: BettyEvent) {
        switch event {
        case .ping, .liveScoreUpdate:
            // .liveScoreUpdate drives the live scoreline in place (LiveUpdateCoordinator);
            // too frequent (per FIFA-feed poll) to also show as an activity row without
            // evicting real activity from the capped feed. Web parity: see ActivityFeed.vue.
            return
        default:
            break
        }
        entries.append(Entry(id: nextID, event: event, timestamp: Date()))
        nextID += 1
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    func remove(id: Int) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries.remove(at: index)
        }
    }

    func clearAll() {
        entries = []
    }

    /// Starts consuming the socket's event stream (replaces any previous attachment).
    func attach(to socket: WebSocketService) {
        consumeTask?.cancel()
        consumeTask = Task { [weak self] in
            let stream = socket.events()
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                self.add(event)
            }
        }
    }

    func detach() {
        consumeTask?.cancel()
        consumeTask = nil
    }
}
