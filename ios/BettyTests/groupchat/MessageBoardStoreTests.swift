import Foundation
import Testing
@testable import Betty

private final class ChatStubTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token-2" }
}

/// Pins the meme-board behaviors the chat screen relies on: prepend-on-post,
/// reactions normalized from null, delete-404-is-success, and optimistic
/// reaction rollback.
@Suite struct MessageBoardStoreTests {
    private let listJSON = """
    [
      {
        "id": 1, "group_id": 5, "user_id": "uid-a",
        "image_url": null, "body": "hello",
        "created_at": "2026-06-01T10:00:00Z",
        "reactions": [
          { "user_id": "uid-b", "emoji_id": "👍", "created_at": "2026-06-01T10:05:00Z" },
          { "user_id": "uid-me", "emoji_id": "❤️", "created_at": "2026-06-01T10:06:00Z" }
        ]
      },
      {
        "id": 2, "group_id": 5, "user_id": "uid-me",
        "image_url": null, "body": "second",
        "created_at": "2026-06-01T10:30:00Z",
        "reactions": []
      }
    ]
    """

    private func makeStore(_ transport: MockTransport) -> MessageBoardStore {
        let api = APIClient(transport: transport, tokens: ChatStubTokens())
        return MessageBoardStore(api: api, groupID: 5)
    }

    @Test func postPrependsCreatedMessageAndNormalizesNullReactions() async throws {
        let transport = MockTransport()
        let list = listJSON
        transport.handler = { request in
            if request.httpMethod == "POST" {
                let created = """
                {
                  "id": 9, "group_id": 5, "user_id": "uid-me",
                  "image_url": null, "body": "yo",
                  "created_at": "2026-06-01T11:00:00Z",
                  "reactions": null
                }
                """
                return MockTransport.json(created, status: 201, url: request.url)
            }
            return MockTransport.json(list, url: request.url)
        }
        let store = makeStore(transport)
        try await store.load()

        let created = try await store.post(body: "yo")

        #expect(created.id == 9)
        #expect(store.messages.map(\.id) == [9, 1, 2])
        #expect(store.messages[0].reactions.isEmpty)

        let postRequest = try #require(transport.requests.first { $0.httpMethod == "POST" })
        let body = try #require(postRequest.httpBody)
        let payload = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(payload["group_id"] as? Int == 5)
        #expect(payload["body"] as? String == "yo")
    }

    @Test func delete404IsTreatedAsAlreadyGone() async throws {
        let transport = MockTransport()
        let list = listJSON
        transport.handler = { request in
            if request.httpMethod == "DELETE" {
                return MockTransport.json(#"{"error":"not found"}"#, status: 404, url: request.url)
            }
            return MockTransport.json(list, url: request.url)
        }
        let store = makeStore(transport)
        try await store.load()

        try await store.delete(messageID: 1) // must NOT throw

        #expect(store.messages.map(\.id) == [2])
    }

    @Test func deleteFailureKeepsTheMessageAndThrows() async throws {
        let transport = MockTransport()
        let list = listJSON
        transport.handler = { request in
            if request.httpMethod == "DELETE" {
                return MockTransport.json(#"{"error":"boom"}"#, status: 500, url: request.url)
            }
            return MockTransport.json(list, url: request.url)
        }
        let store = makeStore(transport)
        try await store.load()

        await #expect(throws: APIError.self) {
            try await store.delete(messageID: 1)
        }
        #expect(store.messages.map(\.id) == [1, 2])
    }

    @Test func setReactionReplacesMineAndAppendsOptimistically() async throws {
        let transport = MockTransport()
        let list = listJSON
        transport.handler = { request in
            if request.httpMethod == "PUT" {
                return MockTransport.json("", status: 204, url: request.url)
            }
            return MockTransport.json(list, url: request.url)
        }
        let store = makeStore(transport)
        try await store.load()

        try await store.setReaction(messageID: 1, emojiID: "🔥", userID: "uid-me")

        let reactions = store.messages[0].reactions
        #expect(reactions.count == 2)
        #expect(reactions[0].userID == "uid-b") // others preserved in place
        #expect(reactions[1].userID == "uid-me")
        #expect(reactions[1].emojiID == "🔥") // mine replaced + appended last

        let putRequest = try #require(transport.requests.first { $0.httpMethod == "PUT" })
        let body = try #require(putRequest.httpBody)
        let payload = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(payload["emoji_id"] as? String == "🔥")
    }

    @Test func setReactionRollsBackOnFailure() async throws {
        let transport = MockTransport()
        let list = listJSON
        transport.handler = { request in
            if request.httpMethod == "PUT" {
                return MockTransport.json(#"{"error":"forbidden"}"#, status: 403, url: request.url)
            }
            return MockTransport.json(list, url: request.url)
        }
        let store = makeStore(transport)
        try await store.load()

        await #expect(throws: APIError.self) {
            try await store.setReaction(messageID: 1, emojiID: "🔥", userID: "uid-me")
        }

        let reactions = store.messages[0].reactions
        #expect(reactions.map(\.emojiID) == ["👍", "❤️"])
        #expect(reactions[1].userID == "uid-me")
    }

    @Test func removeReactionDropsOnlyMine() async throws {
        let transport = MockTransport()
        let list = listJSON
        transport.handler = { request in
            if request.httpMethod == "DELETE" {
                return MockTransport.json("", status: 204, url: request.url)
            }
            return MockTransport.json(list, url: request.url)
        }
        let store = makeStore(transport)
        try await store.load()

        try await store.removeReaction(messageID: 1, userID: "uid-me")

        let reactions = store.messages[0].reactions
        #expect(reactions.count == 1)
        #expect(reactions[0].userID == "uid-b")
    }

    @Test func removeReactionRollsBackOnFailure() async throws {
        let transport = MockTransport()
        let list = listJSON
        transport.handler = { request in
            if request.httpMethod == "DELETE" {
                return MockTransport.json(#"{"error":"boom"}"#, status: 500, url: request.url)
            }
            return MockTransport.json(list, url: request.url)
        }
        let store = makeStore(transport)
        try await store.load()

        await #expect(throws: APIError.self) {
            try await store.removeReaction(messageID: 1, userID: "uid-me")
        }

        #expect(store.messages[0].reactions.map(\.emojiID) == ["👍", "❤️"])
    }
}
