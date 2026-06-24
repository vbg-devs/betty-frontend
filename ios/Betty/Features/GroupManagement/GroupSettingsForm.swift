import Foundation

/// Form state behind the group-settings sheet (web `GroupSettingsModal`).
///
/// Pinned web rules: `canSave` = both point strings parse AND booster fields validate;
/// `isDirty` = any field differs from the loaded group (reverting a field disables
/// saving again); the update payload sends the welcome message verbatim and a
/// trimmed-or-null description.
///
/// Booster validation (spec §1.1): `boostCount >= 0` and `boostMultiplier >= 1`.
nonisolated struct GroupSettingsForm: Equatable, Sendable {
    static let maxDescriptionLength = 1000

    var welcomeMessage: String
    var description: String
    var winPoints: String
    var exactPoints: String
    var allowSneakPeek: Bool
    var boostCount: String
    var boostMultiplier: String
    var loneRangerEnabled: Bool
    var loneRangerPoints: String

    private let originalWelcome: String
    private let originalDescription: String
    private let originalWin: Int
    private let originalExact: Int
    private let originalPeek: Bool
    private let originalBoostCount: Int
    private let originalBoostMultiplier: Int
    private let originalLoneRangerEnabled: Bool
    private let originalLoneRangerPoints: Int

    init(group: Group) {
        welcomeMessage = group.welcomeMessage ?? ""
        description = group.description ?? ""
        winPoints = String(group.correctTeamPoints)
        exactPoints = String(group.exactResultPoints)
        allowSneakPeek = group.allowSneakPeek
        boostCount = String(group.boostCount)
        boostMultiplier = String(group.boostMultiplier)
        loneRangerEnabled = group.loneRangerEnabled
        loneRangerPoints = String(group.loneRangerPoints)
        originalWelcome = group.welcomeMessage ?? ""
        originalDescription = group.description ?? ""
        originalWin = group.correctTeamPoints
        originalExact = group.exactResultPoints
        originalPeek = group.allowSneakPeek
        originalBoostCount = group.boostCount
        originalBoostMultiplier = group.boostMultiplier
        originalLoneRangerEnabled = group.loneRangerEnabled
        originalLoneRangerPoints = group.loneRangerPoints
    }

    /// Whether the multiplier input is disabled (count <= 0 → boosters off).
    var isMultiplierDisabled: Bool {
        (Int(boostCount) ?? 0) <= 0
    }

    /// Whether the bonus-points input is disabled (toggle off → bonus has no effect).
    var isLoneRangerPointsDisabled: Bool {
        !loneRangerEnabled
    }

    var canSave: Bool {
        guard Int(winPoints) != nil, Int(exactPoints) != nil else { return false }
        guard let count = Int(boostCount), count >= 0 else { return false }
        guard let multiplier = Int(boostMultiplier), multiplier >= 1 else { return false }
        // Lone Ranger points only need to validate when the feature is enabled.
        if loneRangerEnabled {
            guard let lrPoints = Int(loneRangerPoints), lrPoints >= 0 else { return false }
        }
        return true
    }

    var isDirty: Bool {
        welcomeMessage != originalWelcome
            || description != originalDescription
            || Int(winPoints) != originalWin
            || Int(exactPoints) != originalExact
            || allowSneakPeek != originalPeek
            || Int(boostCount) != originalBoostCount
            || Int(boostMultiplier) != originalBoostMultiplier
            || loneRangerEnabled != originalLoneRangerEnabled
            || Int(loneRangerPoints) != originalLoneRangerPoints
    }

    /// `PUT /group/:id/settings` body; nil when any field doesn't parse / validate.
    var update: GroupSettingsUpdate? {
        guard let win = Int(winPoints), let exact = Int(exactPoints) else { return nil }
        guard let count = Int(boostCount), count >= 0 else { return nil }
        guard let multiplier = Int(boostMultiplier), multiplier >= 1 else { return nil }
        // When enabled, points must parse and be >= 0; when disabled, send 0.
        let lrPoints: Int
        if loneRangerEnabled {
            guard let parsed = Int(loneRangerPoints), parsed >= 0 else { return nil }
            lrPoints = parsed
        } else {
            lrPoints = 0
        }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return GroupSettingsUpdate(
            welcomeMessage: welcomeMessage,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            correctTeamPoints: win,
            exactResultPoints: exact,
            allowSneakPeek: allowSneakPeek,
            boostCount: count,
            boostMultiplier: multiplier,
            loneRangerEnabled: loneRangerEnabled,
            loneRangerPoints: lrPoints
        )
    }
}
