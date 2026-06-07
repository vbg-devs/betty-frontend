import Foundation
import Network

/// One parsed HTTP request as the mock routes see it.
struct MockHTTPRequest {
    let method: String
    /// Path only (query stripped), e.g. `/api/v1/groupbyid/5`.
    let path: String
    let query: [String: String]
    /// Header names lowercased.
    let headers: [String: String]
    let body: Data

    var bodyJSON: [String: Any]? {
        (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
    }

    /// `application/x-www-form-urlencoded` body (securetoken refresh).
    var bodyForm: [String: String] {
        Self.parseForm(String(decoding: body, as: UTF8.self))
    }

    static func parseForm(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in raw.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let key = parts.first.map(String.init) else { continue }
            let value = parts.count > 1 ? String(parts[1]) : ""
            result[key.removingPercentEncoding ?? key] =
                (value.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? value)
        }
        return result
    }
}

/// Response value built by route handlers.
struct MockHTTPResponse {
    var status: Int
    var headers: [String: String] = [:]
    var body: Data = Data()

    /// JSON-serialized body (`NSNull` for explicit nulls).
    static func json(_ object: Any, status: Int = 200) -> MockHTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed])) ?? Data()
        return MockHTTPResponse(status: status, headers: ["Content-Type": "application/json"], body: data)
    }

    /// Status-only response (the Betty API's errors usually have empty bodies).
    static func empty(_ status: Int) -> MockHTTPResponse {
        MockHTTPResponse(status: status)
    }

    /// Go's `c.JSON(200, nil)` — the literal 4 bytes `null`.
    static func null(status: Int = 200) -> MockHTTPResponse {
        MockHTTPResponse(status: status, headers: ["Content-Type": "application/json"], body: Data("null".utf8))
    }

    static func reason(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 409: "Conflict"
        case 410: "Gone"
        case 413: "Payload Too Large"
        case 415: "Unsupported Media Type"
        case 423: "Locked"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        default: "Status"
        }
    }
}

/// Minimal HTTP/1.1 server on a loopback ephemeral port (Network.framework, no deps).
/// One request per connection (`Connection: close`) — URLSession transparently opens a
/// fresh connection per call. Handlers run on the server's queue; shared state they
/// touch must bring its own synchronization (BettyMockBackend's scenario lock).
final class MockHTTPServer: @unchecked Sendable {
    typealias Handler = @Sendable (MockHTTPRequest, [String: String]) -> MockHTTPResponse

    private struct Route {
        let method: String
        let segments: [String]
        let handler: Handler
    }

    private let queue = DispatchQueue(label: "betty.mock.http")
    private let lock = NSLock()
    private var routes: [Route] = []
    private var recorded: [MockHTTPRequest] = []
    private var listener: NWListener?
    private(set) var port: UInt16 = 0

    /// Registers a route. Patterns use `:name` for path parameters and a trailing `*`
    /// to match any remainder (e.g. `PUT /_upload/*` for the presigned-PUT catch-all).
    func route(_ method: String, _ pattern: String, handler: @escaping Handler) {
        let segments = pattern.split(separator: "/").map(String.init)
        lock.lock()
        routes.append(Route(method: method, segments: segments, handler: handler))
        lock.unlock()
    }

    /// Every request the server handled, in arrival order (for request assertions).
    var recordedRequests: [MockHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func start() throws {
        let listener = try NWListener(using: .tcp)
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
            connection.start(queue: self.queue)
            self.receive(on: connection, buffer: Data())
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 10) == .success, port != 0 else {
            throw MockServerError.failedToStart("HTTP listener did not become ready")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = Self.parse(buffer) {
                let response = self.dispatch(request)
                self.send(response, on: connection)
                return
            }
            if error != nil || isComplete {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buffer)
        }
    }

    /// Returns nil while the buffer does not yet hold a complete head + body.
    private static func parse(_ buffer: Data) -> MockHTTPRequest? {
        guard let headEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: buffer[buffer.startIndex..<headEnd.lowerBound], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        let method = String(requestLine[0])
        let target = String(requestLine[1])

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let contentLength = headers["content-length"].flatMap(Int.init) ?? 0
        let bodyStart = headEnd.upperBound
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= contentLength else { return nil }
        let body = buffer.subdata(in: bodyStart..<buffer.index(bodyStart, offsetBy: contentLength))

        let pathAndQuery = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(pathAndQuery[0]).removingPercentEncoding ?? String(pathAndQuery[0])
        let query = pathAndQuery.count > 1 ? MockHTTPRequest.parseForm(String(pathAndQuery[1])) : [:]

        return MockHTTPRequest(method: method, path: path, query: query, headers: headers, body: body)
    }

    private func dispatch(_ request: MockHTTPRequest) -> MockHTTPResponse {
        lock.lock()
        recorded.append(request)
        let routes = self.routes
        lock.unlock()

        // LAST registration wins so tests can override any built-in route after
        // `backend.start()` (e.g. force a 500 or a hand-rolled payload).
        let pathSegments = request.path.split(separator: "/").map(String.init)
        for route in routes.reversed() where route.method == request.method {
            if let params = Self.match(pattern: route.segments, path: pathSegments) {
                return route.handler(request, params)
            }
        }
        return .empty(404)
    }

    private static func match(pattern: [String], path: [String]) -> [String: String]? {
        var params: [String: String] = [:]
        if pattern.last == "*" {
            guard path.count >= pattern.count - 1 else { return nil }
        } else {
            guard pattern.count == path.count else { return nil }
        }
        for (index, segment) in pattern.enumerated() {
            if segment == "*" { break }
            if segment.hasPrefix(":") {
                params[String(segment.dropFirst())] = path[index]
            } else if segment != path[index] {
                return nil
            }
        }
        return params
    }

    private func send(_ response: MockHTTPResponse, on connection: NWConnection) {
        var head = "HTTP/1.1 \(response.status) \(MockHTTPResponse.reason(for: response.status))\r\n"
        var headers = response.headers
        headers["Content-Length"] = String(response.body.count)
        headers["Connection"] = "close"
        for (name, value) in headers {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"
        var payload = Data(head.utf8)
        if response.status != 204 {
            payload.append(response.body)
        }
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

enum MockServerError: Error {
    case failedToStart(String)
}
