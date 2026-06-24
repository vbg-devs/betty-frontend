import Foundation
import Network

/// Loopback WebSocket server (NWProtocolWebSocket) mirroring `wss://api.betty.social/ws`:
/// a global broadcast fan-out. On client connect it immediately sends
/// `{"type":"ping","message":null}` (the app reports `.connected` only after the first
/// frame) and keeps pinging every 5 s so the client's 30 s watchdog never trips.
/// `push(text:)` broadcasts an event frame to every connected client.
final class MockWebSocketServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "betty.mock.ws")
    private let condition = NSCondition()
    private var clients: [NWConnection] = []
    private var listener: NWListener?
    private var pingTimer: DispatchSourceTimer?
    private(set) var port: UInt16 = 0

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
            throw MockServerError.failedToStart("WebSocket listener did not become ready")
        }

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
        condition.lock()
        let clients = self.clients
        self.clients = []
        condition.unlock()
        for client in clients {
            client.cancel()
        }
    }

    /// Broadcasts a text frame to every connected client.
    func push(text: String) {
        condition.lock()
        let clients = self.clients
        condition.unlock()
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        for client in clients {
            client.send(content: Data(text.utf8), contentContext: context,
                        isComplete: true, completion: .contentProcessed { _ in })
        }
    }

    /// Blocks until at least one client completed the handshake (the app connects only
    /// after a successful sign-in bootstrap).
    @discardableResult
    func waitForClient(timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while clients.isEmpty {
            guard condition.wait(until: deadline) else { return !clients.isEmpty }
        }
        return true
    }

    var clientCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return clients.count
    }

    // MARK: - Private

    private func add(client: NWConnection) {
        condition.lock()
        clients.append(client)
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
        clients.removeAll { $0 === client }
        condition.unlock()
    }

    /// The real server logs and ignores client messages — drain the app's keepalives.
    private func drainIncoming(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] _, _, _, error in
            guard error == nil else { return }
            self?.drainIncoming(connection)
        }
    }
}
