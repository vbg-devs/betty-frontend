import Foundation

/// One Giphy search hit — only the original-rendition URL is used (web parity).
nonisolated struct GiphyImage: Identifiable, Hashable, Sendable {
    let id: String
    let originalURL: String
}

private nonisolated struct GiphySearchResponse: Decodable {
    struct Gif: Decodable {
        struct Images: Decodable {
            struct Original: Decodable {
                let url: String
            }

            let original: Original
        }

        let id: String
        let images: Images
    }

    let data: [Gif]
}

/// Minimal Giphy REST search for the chat GIF mode (`MemeBoard` parity) — plain HTTPS,
/// no SDK.
final class GiphyClient {
    static let defaultAPIKey = "EUSX9DmpuBQafmcrIeKL9jNl5ES91X9r"
    static let productionBaseURL = URL(string: "https://api.giphy.com")!

    private let transport: any HTTPTransport
    private let apiKey: String
    private let baseURL: URL

    /// DEBUG-only `BETTY_GIPHY_BASE_URL` override so the UI-test mock backend can serve
    /// the search endpoint hermetically (mirrors `LaunchOverrides`); release builds
    /// always hit the production host.
    static func resolveBaseURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        #if DEBUG
        if let raw = environment["BETTY_GIPHY_BASE_URL"], let url = URL(string: raw) {
            return url
        }
        #endif
        return productionBaseURL
    }

    init(transport: any HTTPTransport = URLSessionTransport(),
         apiKey: String = GiphyClient.defaultAPIKey,
         baseURL: URL = GiphyClient.resolveBaseURL()) {
        self.transport = transport
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func search(_ query: String, limit: Int = 10) async throws -> [GiphyImage] {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("v1/gifs/search"),
            resolvingAgainstBaseURL: false
        ) else { throw URLError(.badURL) }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(GiphySearchResponse.self, from: data)
        return decoded.data.map { GiphyImage(id: $0.id, originalURL: $0.images.original.url) }
    }
}
