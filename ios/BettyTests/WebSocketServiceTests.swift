import Foundation
import Testing
@testable import Betty

/// Scripted `WebSocketConnection` — push frames with `push(_:)`, drop the connection
/// with `dropConnection()`, inspect `sentTexts`/`isCancelled`.
private final class MockWSConnection: WebSocketConnection {
    private var buffered: [URLSessionWebSocketTask.Message] = []
    private var waiter: CheckedContinuation<URLSessionWebSocketTask.Message, Error>?
    private var isDropped = false
    private(set) var sentTexts: [String] = []
    private(set) var isCancelled = false

    func push(_ text: String) {
        if let waiter {
            self.waiter = nil
            waiter.resume(returning: .string(text))
        } else {
            buffered.append(.string(text))
        }
    }

    /// Ends the frame stream — the next `receive()` throws like a dropped socket.
    func dropConnection() {
        isDropped = true
        if let waiter {
            self.waiter = nil
            waiter.resume(throwing: URLError(.networkConnectionLost))
        }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        if !buffered.isEmpty { return buffered.removeFirst() }
        if isDropped { throw URLError(.networkConnectionLost) }
        return try await withCheckedThrowingContinuation { waiter = $0 }
    }

    func send(text: String) async throws {
        sentTexts.append(text)
    }

    func cancel() {
        isCancelled = true
        dropConnection()
    }
}

private final class MockWSConnector: WebSocketConnecting {
    private(set) var connections: [MockWSConnection] = []

    func open(url: URL) -> any WebSocketConnection {
        let connection = MockWSConnection()
        connections.append(connection)
        return connection
    }
}

@Suite struct WebSocketServiceTests {
    private static let wsURL = URL(string: "ws://127.0.0.1:1/ws")!

    private func makeService(
        connector: MockWSConnector,
        pingInterval: TimeInterval = 10,
        watchdogTimeout: TimeInterval = 30,
        reconnectBaseDelay: TimeInterval = 0.01
    ) -> WebSocketService {
        WebSocketService(
            url: Self.wsURL,
            connector: connector,
            pingInterval: pingInterval,
            watchdogTimeout: watchdogTimeout,
            reconnectBaseDelay: reconnectBaseDelay
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: connection state

    @Test func staysConnectingUntilFirstFrameArrives() async {
        let connector = MockWSConnector()
        let service = makeService(connector: connector)

        service.connect()

        #expect(service.state == .connecting) // handshake alone is not liveness
        #expect(connector.connections.count == 1)

        connector.connections[0].push(#"{"type":"ping","message":null}"#)
        await waitUntil { service.state == .connected }
        #expect(service.state == .connected)
        #expect(service.lastMessageAt != nil)
    }

    @Test func connectIsIdempotentWhileActive() async {
        let connector = MockWSConnector()
        let service = makeService(connector: connector)

        service.connect()
        service.connect() // already connecting — must not open a second socket

        #expect(connector.connections.count == 1)
    }

    @Test func disconnectCancelsAndReportsDisconnected() async {
        let connector = MockWSConnector()
        let service = makeService(connector: connector)
        service.connect()

        service.disconnect()

        #expect(service.state == .disconnected)
        #expect(connector.connections[0].isCancelled)
        // The dropped stream must not trigger a reconnect after a manual close.
        try? await Task.sleep(for: .milliseconds(100))
        #expect(connector.connections.count == 1)
    }

    // MARK: ping cadence

    @Test func sendsClientPingOnTheConfiguredCadence() async {
        let connector = MockWSConnector()
        let service = makeService(connector: connector, pingInterval: 0.02)
        service.connect()

        await waitUntil { connector.connections[0].sentTexts.count >= 2 }

        let sent = connector.connections[0].sentTexts
        #expect(sent.count >= 2)
        #expect(sent.allSatisfy { $0 == #"{"type":"ping"}"# })
        service.disconnect()
    }

    // MARK: event decode fan-out

    @Test func decodedEventsFanOutToAllConsumersAndPingsAreFiltered() async {
        let connector = MockWSConnector()
        let service = makeService(connector: connector)
        let streamA = service.events()
        let streamB = service.events()
        service.connect()

        let firstA = Task { () -> BettyEvent? in
            for await event in streamA { return event }
            return nil
        }
        let firstB = Task { () -> BettyEvent? in
            for await event in streamB { return event }
            return nil
        }
        connector.connections[0].push(#"{"type":"ping","message":null}"#) // liveness only
        connector.connections[0].push(#"{"type":"group_joined","message":{"group":{"id":7,"name":"Office League"},"who":"Ada"}}"#)

        let eventA = await firstA.value
        let eventB = await firstB.value
        for event in [eventA, eventB] {
            guard case .groupJoined(let payload) = event else {
                Issue.record("expected groupJoined, got \(String(describing: event))")
                continue
            }
            #expect(payload.group?.id == 7)
            #expect(payload.who == "Ada")
        }
        service.disconnect()
    }

    @Test func undecodableFramesAreIgnoredAndTheLoopKeepsRunning() async {
        let connector = MockWSConnector()
        let service = makeService(connector: connector)
        let stream = service.events()
        service.connect()

        let first = Task { () -> BettyEvent? in
            for await event in stream { return event }
            return nil
        }
        connector.connections[0].push("not json at all")
        connector.connections[0].push(#"{"type":"group_created","message":null}"#)

        let event = await first.value
        #expect(event == .groupCreated)
        service.disconnect()
    }

    // MARK: reconnect / backoff

    @Test func droppedConnectionReconnectsWithAFreshSocket() async {
        let connector = MockWSConnector()
        let service = makeService(connector: connector)
        service.connect()
        connector.connections[0].push(#"{"type":"ping","message":null}"#)
        await waitUntil { service.state == .connected }

        connector.connections[0].dropConnection()

        await waitUntil { connector.connections.count == 2 }
        #expect(connector.connections.count == 2)
        #expect(service.state == .connecting) // fresh socket, no frame yet

        connector.connections[1].push(#"{"type":"ping","message":null}"#)
        await waitUntil { service.state == .connected }
        #expect(service.state == .connected)
        service.disconnect()
    }

    @Test func watchdogReconnectsWhenNoFramesArrive() async {
        let connector = MockWSConnector()
        let service = makeService(connector: connector, pingInterval: 0.02, watchdogTimeout: 0.001)
        service.connect()

        // First ping tick sees a silent socket (> watchdogTimeout since open) → reconnect.
        await waitUntil { connector.connections.count >= 2 }
        #expect(connector.connections.count >= 2)
        service.disconnect()
    }

    @Test func backoffDoublesUpToThirtySecondCap() {
        #expect(WebSocketService.nextBackoff(after: 1) == 2)
        #expect(WebSocketService.nextBackoff(after: 8) == 16)
        #expect(WebSocketService.nextBackoff(after: 16) == 30)
        #expect(WebSocketService.nextBackoff(after: 30) == 30)
    }
}
