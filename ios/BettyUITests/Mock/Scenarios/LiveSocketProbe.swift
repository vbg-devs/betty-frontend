import Foundation
import Network

/// Instrumented loopback WebSocket server for the Live suite — same wire behavior as
/// the harness server (greeting `{"type":"ping"}` on handshake so the app flips to
/// `.connected`, plus a server ping every 5 s) with the observation hooks the
/// connection-lifecycle tests need:
/// - `handshakeCount` / `handshakeDates` — every completed client handshake, so
///   reconnects are countable,
/// - `activeClientCount` — currently open sockets (drops to 0 on background/disconnect),
/// - `recordedTextFrames` — every client → server text frame (the app's 10 s
///   `{"type":"ping"}` keepalives),
/// - `closeActiveClients()` — a server-side close that KEEPS the listener (and port)
///   alive so the app's automatic reconnect can land on the same `BETTY_WS_URL`.
///
/// Tests point the app at it by overriding `app.launchEnvironment["BETTY_WS_URL"]`
/// before `launchApp()`; the harness backend's own WS server simply stays idle.
final class LiveSocketProbe: @unchecked Sendable {
    struct TextFrame {
        let text: String
        let receivedAt: Date
    }

    private let queue = DispatchQueue(label: "betty.live.socket.probe")
    private let condition = NSCondition()
    private var listener: NWListener?
    private var activeClients: [NWConnection] = []
    private var handshakes: [Date] = []
    private var frames: [TextFrame] = []
    private var pingTimer: DispatchSourceTimer?
    private(set) var port: UInt16 = 0

    var url: URL { URL(string: "ws://127.0.0.1:\(port)")! }

    func start() throws {
        let parameters = NWParameters.tcp
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)

        let listener = try NWListener(using: parameters)
        self.listener = listener
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.port = listener.port?.rawValue ?? 0
                ready.signal()
            case .failed, .cancelled:
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.add(client: connection)
                case .failed, .cancelled:
                    self?.remove(client: connection)
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
            self.drainIncoming(connection)
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 10) == .success, port != 0 else {
            throw MockServerError.failedToStart("LiveSocketProbe listener did not become ready")
        }

        // 5 s server pings keep the app's 30 s liveness watchdog from tripping.
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            self?.push(text: #"{"type":"ping","message":null}"#)
        }
        timer.resume()
        pingTimer = timer
    }

    func stop() {
        pingTimer?.cancel()
        pingTimer = nil
        listener?.cancel()
        listener = nil
        closeActiveClients()
    }

    /// Server-side close of every open socket; the listener stays up (when not
    /// stopping) so the app's reconnect succeeds on the same port.
    func closeActiveClients() {
        condition.lock()
        let clients = activeClients
        activeClients = []
        condition.broadcast()
        condition.unlock()
        for client in clients {
            client.cancel()
        }
    }

    /// Broadcasts a text frame to every connected client.
    func push(text: String) {
        condition.lock()
        let clients = activeClients
        condition.unlock()
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        for client in clients {
            client.send(content: Data(text.utf8), contentContext: context,
                        isComplete: true, completion: .contentProcessed { _ in })
        }
    }

    /// `{"type": <type>, "message": <message>}` envelope, like the harness backend.
    func pushEvent(type: String, message: Any? = nil) {
        let envelope: [String: Any] = ["type": type, "message": message ?? NSNull()]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope),
              let text = String(data: data, encoding: .utf8) else { return }
        push(text: text)
    }

    // MARK: - Observation

    var handshakeCount: Int {
        locked { handshakes.count }
    }

    var handshakeDates: [Date] {
        locked { handshakes }
    }

    var activeClientCount: Int {
        locked { activeClients.count }
    }

    /// Client → server text frames (the app's `{"type":"ping"}` keepalives).
    var recordedTextFrames: [TextFrame] {
        locked { frames }
    }

    @discardableResult
    func waitForHandshakes(atLeast count: Int, timeout: TimeInterval = 15) -> Bool {
        waitUntil(timeout) { self.handshakes.count >= count }
    }

    @discardableResult
    func waitForActiveClients(_ count: Int, timeout: TimeInterval = 15) -> Bool {
        waitUntil(timeout) { self.activeClients.count == count }
    }

    @discardableResult
    func waitForTextFrames(atLeast count: Int, timeout: TimeInterval = 30) -> Bool {
        waitUntil(timeout) { self.frames.count >= count }
    }

    // MARK: - Private

    private func locked<T>(_ body: () -> T) -> T {
        condition.lock()
        defer { condition.unlock() }
        return body()
    }

    /// `predicate` runs WITH the condition lock held — read fields directly, never
    /// through the `locked` accessors (NSCondition is not recursive).
    private func waitUntil(_ timeout: TimeInterval, _ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while !predicate() {
            guard condition.wait(until: deadline) else { return predicate() }
        }
        return true
    }

    private func add(client: NWConnection) {
        condition.lock()
        activeClients.append(client)
        handshakes.append(Date())
        condition.broadcast()
        condition.unlock()
        // First frame — flips the app's connection state to `.connected`.
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        client.send(content: Data(#"{"type":"ping","message":null}"#.utf8), contentContext: context,
                    isComplete: true, completion: .contentProcessed { _ in })
    }

    private func remove(client: NWConnection) {
        condition.lock()
        activeClients.removeAll { $0 === client }
        condition.broadcast()
        condition.unlock()
    }

    private func drainIncoming(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                self.condition.lock()
                self.frames.append(TextFrame(text: text, receivedAt: Date()))
                self.condition.broadcast()
                self.condition.unlock()
            }
            guard error == nil else {
                self.remove(client: connection)
                return
            }
            self.drainIncoming(connection)
        }
    }
}
