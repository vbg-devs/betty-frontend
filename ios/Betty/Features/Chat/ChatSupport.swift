import Foundation

/// One chip in a message's reaction row, grouped by emoji.
nonisolated struct ReactionGroup: Identifiable, Hashable, Sendable {
    let emojiID: String
    var count: Int
    var reactedByMe: Bool

    var id: String { emojiID }
}

/// What tapping an emoji should do, per the web `toggleReaction` rules.
nonisolated enum ReactionToggleAction: Equatable, Sendable {
    case set(emojiID: String)
    case remove
}

nonisolated enum ReactionLogic {
    /// Groups reactions by emoji in FIRST-SEEN order of the array (web parity), with a
    /// per-chip count and a reacted-by-me flag. nil userID = logged out = never mine.
    static func grouped(_ reactions: [MessageReaction], currentUserID: String?) -> [ReactionGroup] {
        var order: [String] = []
        var groups: [String: ReactionGroup] = [:]
        for reaction in reactions {
            let isMine = currentUserID != nil && reaction.userID == currentUserID
            if var existing = groups[reaction.emojiID] {
                existing.count += 1
                if isMine { existing.reactedByMe = true }
                groups[reaction.emojiID] = existing
            } else {
                order.append(reaction.emojiID)
                groups[reaction.emojiID] = ReactionGroup(emojiID: reaction.emojiID, count: 1, reactedByMe: isMine)
            }
        }
        return order.compactMap { groups[$0] }
    }

    /// Tapping my current emoji removes it; any other emoji replaces my reaction
    /// (one per user per message). nil when logged out (no-op).
    static func toggleAction(
        for emojiID: String,
        in reactions: [MessageReaction],
        currentUserID: String?
    ) -> ReactionToggleAction? {
        guard let currentUserID else { return nil }
        let mine = reactions.first { $0.userID == currentUserID }
        if let mine, mine.emojiID == emojiID { return .remove }
        return .set(emojiID: emojiID)
    }
}

nonisolated enum ChatDisplay {
    /// Web: `nickname || name || 'Unknown'` — JS `||` treats empty strings as missing.
    static func authorName(_ member: Member?) -> String {
        guard let member else { return "Unknown" }
        if let nickname = member.nickname, !nickname.isEmpty { return nickname }
        if let name = member.name, !name.isEmpty { return name }
        return "Unknown"
    }
}

nonisolated enum ChatRelativeTime {
    /// Relative "x ago" timestamp (web date-fns `formatDistance` with suffix).
    static func string(from date: Date, to now: Date = Date(), locale: Locale = .current) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = locale
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

/// Constraints shared with the presigned upload endpoints (1 MiB, four image types).
nonisolated enum ChatImage {
    static let maxBytes = 1_048_576
    static let allowedContentTypes: Set<String> = ["image/jpeg", "image/png", "image/webp", "image/gif"]

    /// Sniffs the content type from magic bytes; nil = not an uploadable image type.
    static func contentType(of data: Data) -> String? {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if data.starts(with: Array("GIF8".utf8)) { return "image/gif" }
        if data.count >= 12,
           data.prefix(4).elementsEqual(Array("RIFF".utf8)),
           data.dropFirst(8).prefix(4).elementsEqual(Array("WEBP".utf8)) {
            return "image/webp"
        }
        return nil
    }

    static func fitsLimit(_ data: Data) -> Bool {
        !data.isEmpty && data.count <= maxBytes
    }
}
