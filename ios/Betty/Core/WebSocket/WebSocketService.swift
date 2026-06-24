import Foundation
import Observation

/// `wss://api.betty.social/ws` — unauthenticated GLOBAL broadcast (no per-user filtering;
/// treat every payload as public).
///
/// Behavior:
/// - reports `.connecting` until the FIRST frame arrives (the server broadcasts
///   `{"type":"ping"}` every 10 s, so a healthy connection confirms itself quickly);
///   only then `.connected` — a half-open socket never looks live,
/// - sends `{"type":"ping"}` every 10 s (client keepalive per the agreed spec),
/// - the server's ping doubles as the liveness signal (watchdog reconnects if nothing
///   arrives for ~30 s),
/// - auto-reconnects with exponential backoff (1 s → 30 s cap) unless `disconnect()`
///   was called,
/// - decodes the `{"type", "message"}` envelope into typed `BettyEvent`s and fans them
///   out to every `events()` AsyncStream. Server pings are NOT forwarded to streams
///   (the web ignores them) — `lastMessageAt` still updates.
@Observable
final class WebSocketService {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
    }

    private(set) var state: ConnectionState = .disconnected
    private(set) var lastMessageAt: Date?

    private let url: URL
    private let connector: any WebSocketConnecting
    private let pingInterval: TimeInterval
    private let watchdogTimeout: TimeInterval
    private let reconnectBaseDelay: TimeInterval

    private var connection: (any WebSocketConnection)?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<BettyEvent>.Continuation] = [:]
    private var backoff: TimeInterval
    private var manuallyClosed = false

    static let defaultURL = URL(string: "wss://api.betty.social/ws")!

    init(url: URL = WebSocketService.defaultURL,
         connector: any WebSocketConnecting = URLSessionWebSocketConnector(),
         pingInterval: TimeInterval = 10,
         watchdogTimeout: TimeInterval = 30,
         reconnectBaseDelay: TimeInterval = 1) {
        self.url = url
        self.connector = connector
        self.pingInterval = pingInterval
        self.watchdogTimeout = watchdogTimeout
        self.reconnectBaseDelay = reconnectBaseDelay
        self.backoff = reconnectBaseDelay
    }

    /// Pure backoff policy: double up to a 30 s cap.
    nonisolated static func nextBackoff(after delay: TimeInterval) -> TimeInterval {
        min(delay * 2, 30)
    }

    /// A stream of typed events for one consumer (activity feed, group detail, ...).
    /// Multiple concurrent consumers are supported; the stream ends on `disconnect()`
    /// only if the consumer cancels — reconnects are transparent.
    func events() -> AsyncStream<BettyEvent> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations[id] = nil
                }
            }
        }
    }

    func connect() {
        guard state == .disconnected else { return }
        manuallyClosed = false
        open()
    }

    func disconnect() {
        manuallyClosed = true
        teardown()
        state = .disconnected
    }

    private func open() {
        // .connected is reported only by the receive loop on the first frame.
        state = .connecting
        let connection = connector.open(url: url)
        self.connection = connection
        // Watchdog epoch: without this, a half-open FIRST connection (nil) is never torn
        // down, and a reconnect inherits the previous connection's stale timestamp and
        // gets killed by the first ping tick.
        lastMessageAt = Date()
        startReceiveLoop()
        startPingLoop()
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let connection = self.connection else { return }
                do {
                    let message = try await connection.receive()
                    self.backoff = self.reconnectBaseDelay
                    self.lastMessageAt = Date()
                    if self.state != .connected {
                        self.state = .connected
                    }
                    self.handle(message)
                } catch {
                    if !Task.isCancelled {
                        self.scheduleReconnect()
                    }
                    return
                }
            }
        }
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.pingInterval ?? 10))
                guard let self, let connection = self.connection, !Task.isCancelled else { return }
                try? await connection.send(text: #"{"type":"ping"}"#) // receive loop handles errors
                if let last = self.lastMessageAt, Date().timeIntervalSince(last) > self.watchdogTimeout {
                    self.scheduleReconnect()
                    return
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let payload):
            data = payload
        @unknown default:
            return
        }
        guard let event = BettyEvent.decode(from: data) else { return }
        if case .ping = event { return } // liveness only — never forwarded
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func scheduleReconnect() {
        teardown()
        guard !manuallyClosed else {
            state = .disconnected
            return
        }
        state = .connecting
        let delay = backoff
        backoff = Self.nextBackoff(after: backoff)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, !self.manuallyClosed else { return }
            self.open()
        }
    }

    private func teardown() {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        connection?.cancel()
        connection = nil
    }
}
