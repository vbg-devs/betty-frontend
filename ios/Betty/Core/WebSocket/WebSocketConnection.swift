import Foundation

/// One live WebSocket connection — the injectable seam between `WebSocketService`
/// and `URLSessionWebSocketTask` (mocked in unit tests).
protocol WebSocketConnection: AnyObject {
    /// Awaits the next frame; throws when the connection drops or is cancelled.
    func receive() async throws -> URLSessionWebSocketTask.Message
    /// Sends a text frame (keepalive ping); failures surface via `receive()`.
    func send(text: String) async throws
    func cancel()
}

/// Factory for `WebSocketConnection`s — one fresh connection per (re)connect attempt.
protocol WebSocketConnecting {
    func open(url: URL) -> any WebSocketConnection
}

final class URLSessionWebSocketConnector: WebSocketConnecting {
    func open(url: URL) -> any WebSocketConnection {
        URLSessionWebSocketConnection(task: URLSession.shared.webSocketTask(with: url))
    }
}

final class URLSessionWebSocketConnection: WebSocketConnection {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
        task.resume()
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await task.receive()
    }

    func send(text: String) async throws {
        try await task.send(.string(text))
    }

    func cancel() {
        task.cancel(with: .goingAway, reason: nil)
    }
}
