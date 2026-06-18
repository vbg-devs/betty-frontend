import Foundation

/// Form state + validation for `CreateGroupSheet` (web `CreateGroupModal`).
///
/// `canSave` is reactive against the *current* running list: if the selected
/// tournament stops being running the button disables again (pinned web behavior).
///
/// Booster defaults (spec decision log #6): `boostCount = 0` (boosters off by default),
/// `boostMultiplier = 2`. Admin opts in by setting count > 0.
nonisolated struct CreateGroupForm: Equatable, Sendable {
    static let maxDescriptionLength = 1000

    var tournamentID: Int?
    var name = ""
    var welcomeMessage = ""
    var description = ""
    var winPoints = ""
    var exactPoints = ""
    var allowSneakPeek = false  // default OFF
    var isPublic = false        // default OFF
    /// Boosters per user (0 = off — spec decision log #6). Sent verbatim.
    var boostCount = "0"
    /// Multiplier (>= 1). Ignored server-side when count == 0.
    var boostMultiplier = "2"

    func selectedTournament(in running: [Tournament]) -> Tournament? {
        guard let tournamentID else { return nil }
        return running.first { $0.id == tournamentID }
    }

    /// Whether the multiplier input is disabled (count <= 0 mirrors settings sheet).
    var isMultiplierDisabled: Bool {
        (Int(boostCount) ?? 0) <= 0
    }

    /// Web `canSave`: tournament still running AND name + both point fields non-empty
    /// AND booster fields validate (count ≥ 0, multiplier ≥ 1).
    func canSave(running: [Tournament]) -> Bool {
        guard selectedTournament(in: running) != nil,
              !name.isEmpty,
              !winPoints.isEmpty,
              !exactPoints.isEmpty
        else { return false }
        guard let count = Int(boostCount), count >= 0 else { return false }
        guard let multiplier = Int(boostMultiplier), multiplier >= 1 else { return false }
        return true
    }

    /// `POST /group` body. Welcome message is sent verbatim (even empty — web parity);
    /// description is trimmed and nilled when empty; deadline = tournament kickoff.
    func payload(running: [Tournament]) -> CreateGroupRequest? {
        guard let tournament = selectedTournament(in: running),
              let win = Int(winPoints),
              let exact = Int(exactPoints),
              let count = Int(boostCount), count >= 0,
              let multiplier = Int(boostMultiplier), multiplier >= 1
        else { return nil }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return CreateGroupRequest(
            name: name,
            tournamentID: tournament.id,
            correctTeamPoints: win,
            exactResultPoints: exact,
            allowSneakPeek: allowSneakPeek,
            groupPlayDeadline: tournament.startDate,
            welcomeMessage: welcomeMessage,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            isPublic: isPublic,
            mode: 0,
            boostCount: count,
            boostMultiplier: multiplier
        )
    }
}
