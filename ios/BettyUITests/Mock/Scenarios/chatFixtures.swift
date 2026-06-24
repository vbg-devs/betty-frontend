import Foundation

/// Extra meme-board fixtures for the chat suite, layered on top of `DefaultScenario`
/// (group 1 "Sunday Legends" ships messages 1 + 2). IDs live in the 3xx range so they
/// never collide with DefaultScenario ids or POST-created ids (1000+).
enum ChatFixtures {
    static let groupedReactionsMessageID = 301
    static let imageMessageID = 302
    static let nicknameMessageID = 303
    static let unknownAuthorMessageID = 304
    static let polledMessageID = 305

    /// 👍 from two other users + ❤️ from the signed-in user — drives grouped counts,
    /// first-seen chip order, and the replace-my-reaction flow.
    static func groupedReactionsMessage(now: Date = Date()) -> MockMessage {
        MockMessage(
            id: groupedReactionsMessageID,
            groupID: DefaultScenario.groupSundayLegendsID,
            userID: DefaultScenario.friendUserID,
            body: "Who is winning this weekend?",
            createdAt: now.addingTimeInterval(-1800),
            reactions: [
                MockReaction(userID: DefaultScenario.friendUserID, emojiID: "👍"),
                MockReaction(userID: DefaultScenario.rivalUserID, emojiID: "👍"),
                MockReaction(userID: DefaultScenario.currentUserID, emojiID: "❤️"),
            ]
        )
    }

    /// Image-only message — `image_url` set, `body` nil (renders ONLY the image).
    /// The URL must live under the mock's `publicAssetBase`.
    static func imageMessage(publicAssetBase: String, now: Date = Date()) -> MockMessage {
        MockMessage(
            id: imageMessageID,
            groupID: DefaultScenario.groupSundayLegendsID,
            userID: DefaultScenario.friendUserID,
            body: nil,
            imageURL: "\(publicAssetBase)/chat/meme.png",
            createdAt: now.addingTimeInterval(-900)
        )
    }

    /// From uid-robin, whose group-1 member entry has nickname "The Oracle" —
    /// author display must prefer the nickname.
    static func nicknameMessage(now: Date = Date()) -> MockMessage {
        MockMessage(
            id: nicknameMessageID,
            groupID: DefaultScenario.groupSundayLegendsID,
            userID: DefaultScenario.rivalUserID,
            body: "The Oracle has spoken.",
            createdAt: now.addingTimeInterval(-600)
        )
    }

    /// From a user with no member entry in the group — author renders "Unknown".
    static func unknownAuthorMessage(now: Date = Date()) -> MockMessage {
        MockMessage(
            id: unknownAuthorMessageID,
            groupID: DefaultScenario.groupSundayLegendsID,
            userID: "uid-ghost",
            body: "Boo from the void.",
            createdAt: now.addingTimeInterval(-300)
        )
    }

    /// Appended server-side mid-test — must surface via the 10 s message poll.
    static func polledMessage(now: Date = Date()) -> MockMessage {
        MockMessage(
            id: polledMessageID,
            groupID: DefaultScenario.groupSundayLegendsID,
            userID: DefaultScenario.friendUserID,
            body: "Fresh from the server",
            createdAt: now
        )
    }
}

/// Mock Giphy search payloads for the GIF composer flow. The app's `GiphyClient` is
/// pointed at the mock backend via the DEBUG-only `BETTY_GIPHY_BASE_URL` launch
/// override, so `GET /v1/gifs/search` lands on `backend.http` like every other route.
enum GiphyFixtures {
    /// Stable ids for a three-hit search ("g0" first ⇒ the selector must open on it).
    static let gifIDs = ["g0", "g1", "g2"]

    /// Original-rendition URL for one GIF — lives under the mock's `/_public` asset
    /// route so `AsyncImage` resolves against the loopback server.
    static func gifURL(_ id: String, httpBase: String) -> String {
        "\(httpBase)/_public/gifs/\(id).gif"
    }

    /// Giphy wire shape: `{"data": [{"id", "images": {"original": {"url"}}}]}` —
    /// only the fields `GiphyClient` decodes.
    static func searchResponse(ids: [String], httpBase: String) -> [String: Any] {
        let data: [[String: Any]] = ids.map { id in
            [
                "id": id,
                "images": ["original": ["url": gifURL(id, httpBase: httpBase)]],
            ]
        }
        return ["data": data]
    }
}
