import Foundation
@testable import Betty

/// Routing mock for `HTTPTransport` — set `handler` (or use `route`) and inspect
/// `requests` afterwards.
final class MockTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard let handler else {
            throw URLError(.notConnectedToInternet)
        }
        return try handler(request)
    }

    static func response(_ status: Int, url: URL?) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url ?? URL(string: "https://mock.test")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
    }

    static func json(_ body: String, status: Int = 200, url: URL? = nil) -> (Data, HTTPURLResponse) {
        (Data(body.utf8), response(status, url: url))
    }
}
