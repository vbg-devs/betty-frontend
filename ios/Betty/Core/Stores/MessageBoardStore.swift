import Foundation
import Observation

/// Group chat (meme board) for ONE group — instantiate per group screen.
///
/// Messages are newest-first (server order; new posts prepend). The group screen polls
/// `load()` every 10 s while visible. Reactions are optimistic with snapshot/rollback.
@Observable
final class MessageBoardStore {
    private let api: APIClient
    let groupID: Int

    private(set) var messages: [GroupMessage] = []
    private(set) var isLoaded = false

    /// Fixed reaction palette, exact web order.
    static let reactionPalette = ["👍", "❤️", "😂", "🔥", "🎉", "😮", "😢", "👀"]

    init(api: APIClient, groupID: Int) {
        self.api = api
        self.groupID = groupID
    }

    /// `GET /messageboard/:groupid` — `page` is a PAGE INDEX. A failed poll should keep
    /// showing the last good list (catch at the call site; web logs and renders nothing).
    func load(amount: Int = 50, page: Int = 0) async throws {
        messages = try await api.messages(groupID: groupID, amount: amount, page: page)
        isLoaded = true
    }

    /// `POST /messageboard` — at least one of body/imageURL non-nil. Prepends the
    /// created message (which arrives with `reactions: null` → normalized `[]`).
    @discardableResult
    func post(body: String?, imageURL: String? = nil) async throws -> GroupMessage {
        let created = try await api.postMessage(groupID: groupID, body: body, imageURL: imageURL)
        messages.insert(created, at: 0)
        return created
    }

    /// `DELETE /messageboard/:id` — own messages only. A 404 means "already gone":
    /// dropped locally with NO error (pinned web behavior).
    func delete(messageID: Int) async throws {
        do {
            try await api.deleteMessage(id: messageID)
        } catch APIError.notFound {
            // already gone — fall through to local removal
        }
        messages.removeAll { $0.id == messageID }
    }

    /// Sets/replaces MY reaction (one per user per message) — optimistic: my previous
    /// reaction is replaced locally first, the whole reactions array restores on failure.
    func setReaction(messageID: Int, emojiID: String, userID: String) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let snapshot = messages[index].reactions
        var updated = snapshot.filter { $0.userID != userID }
        updated.append(MessageReaction(userID: userID, emojiID: emojiID, createdAt: Date()))
        messages[index].reactions = updated
        do {
            try await api.setReaction(messageID: messageID, emojiID: emojiID)
        } catch {
            if let rollbackIndex = messages.firstIndex(where: { $0.id == messageID }) {
                messages[rollbackIndex].reactions = snapshot
            }
            throw error
        }
    }

    /// Removes MY reaction — optimistic with rollback. Idempotent server-side (204).
    func removeReaction(messageID: Int, userID: String) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let snapshot = messages[index].reactions
        messages[index].reactions = snapshot.filter { $0.userID != userID }
        do {
            try await api.removeReaction(messageID: messageID)
        } catch {
            if let rollbackIndex = messages.firstIndex(where: { $0.id == messageID }) {
                messages[rollbackIndex].reactions = snapshot
            }
            throw error
        }
    }
}
