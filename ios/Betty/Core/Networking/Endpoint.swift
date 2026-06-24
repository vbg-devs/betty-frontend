import Foundation

/// A REST call description relative to the API base URL.
struct Endpoint {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    var method: Method
    var path: String
    var query: [URLQueryItem] = []
    var body: Data?

    static func get(_ path: String, query: [URLQueryItem] = []) -> Endpoint {
        Endpoint(method: .get, path: path, query: query)
    }

    static func post(_ path: String, body: Data? = nil) -> Endpoint {
        Endpoint(method: .post, path: path, body: body)
    }

    static func put(_ path: String, body: Data? = nil) -> Endpoint {
        Endpoint(method: .put, path: path, body: body)
    }

    static func delete(_ path: String) -> Endpoint {
        Endpoint(method: .delete, path: path)
    }
}
