import Foundation
import Testing
@testable import Betty

@Suite struct GiphyClientTests {
    private let fixture = """
    {
      "data": [
        { "id": "g1", "images": { "original": { "url": "https://giphy.test/1.gif", "width": "480" } } },
        { "id": "g2", "images": { "original": { "url": "https://giphy.test/2.gif" } } }
      ]
    }
    """

    @Test func searchParsesResultsAndBuildsQuery() async throws {
        let transport = MockTransport()
        let body = fixture
        transport.handler = { request in
            MockTransport.json(body, url: request.url)
        }
        let client = GiphyClient(transport: transport, apiKey: "test-key")

        let results = try await client.search("happy dog", limit: 10)

        #expect(results.map(\.id) == ["g1", "g2"])
        #expect(results.map(\.originalURL) == ["https://giphy.test/1.gif", "https://giphy.test/2.gif"])

        let url = try #require(transport.requests.first?.url)
        #expect(url.host() == "api.giphy.com")
        #expect(url.path() == "/v1/gifs/search")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        #expect(query["api_key"] == "test-key")
        #expect(query["q"] == "happy dog")
        #expect(query["limit"] == "10")
    }

    @Test func emptyDataYieldsEmptyResults() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(#"{"data":[]}"#, url: request.url)
        }
        let client = GiphyClient(transport: transport, apiKey: "test-key")

        let results = try await client.search("nothing")

        #expect(results.isEmpty)
    }

    @Test func httpErrorThrows() async {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json("", status: 500, url: request.url)
        }
        let client = GiphyClient(transport: transport, apiKey: "test-key")

        await #expect(throws: (any Error).self) {
            _ = try await client.search("boom")
        }
    }

    @Test func malformedBodyThrows() async {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(#"{"unexpected":true}"#, url: request.url)
        }
        let client = GiphyClient(transport: transport, apiKey: "test-key")

        await #expect(throws: (any Error).self) {
            _ = try await client.search("weird")
        }
    }
}
