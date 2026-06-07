import Foundation

/// Form state behind the group-settings sheet (web `GroupSettingsModal`).
///
/// Pinned web rules: `canSave` = both point strings parse; `isDirty` = any field
/// differs from the loaded group (reverting a field disables saving again); the
/// update payload sends the welcome message verbatim and a trimmed-or-null
/// description.
nonisolated struct GroupSettingsForm: Equatable, Sendable {
    static let maxDescriptionLength = 1000

    var welcomeMessage: String
    var description: String
    var winPoints: String
    var exactPoints: String
    var allowSneakPeek: Bool

    private let originalWelcome: String
    private let originalDescription: String
    private let originalWin: Int
    private let originalExact: Int
    private let originalPeek: Bool

    init(group: Group) {
        welcomeMessage = group.welcomeMessage ?? ""
        description = group.description ?? ""
        winPoints = String(group.correctTeamPoints)
        exactPoints = String(group.exactResultPoints)
        allowSneakPeek = group.allowSneakPeek
        originalWelcome = group.welcomeMessage ?? ""
        originalDescription = group.description ?? ""
        originalWin = group.correctTeamPoints
        originalExact = group.exactResultPoints
        originalPeek = group.allowSneakPeek
    }

    var canSave: Bool {
        Int(winPoints) != nil && Int(exactPoints) != nil
    }

    var isDirty: Bool {
        welcomeMessage != originalWelcome
            || description != originalDescription
            || Int(winPoints) != originalWin
            || Int(exactPoints) != originalExact
            || allowSneakPeek != originalPeek
    }

    /// `PUT /group/:id/settings` body; nil when the points don't parse.
    var update: GroupSettingsUpdate? {
        guard let win = Int(winPoints), let exact = Int(exactPoints) else { return nil }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return GroupSettingsUpdate(
            welcomeMessage: welcomeMessage,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            correctTeamPoints: win,
            exactResultPoints: exact,
            allowSneakPeek: allowSneakPeek
        )
    }
}
