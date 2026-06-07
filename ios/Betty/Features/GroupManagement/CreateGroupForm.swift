import Foundation

/// Form state + validation for `CreateGroupSheet` (web `CreateGroupModal`).
///
/// `canSave` is reactive against the *current* running list: if the selected
/// tournament stops being running the button disables again (pinned web behavior).
nonisolated struct CreateGroupForm: Equatable, Sendable {
    static let maxDescriptionLength = 1000

    var tournamentID: Int?
    var name = ""
    var welcomeMessage = ""
    var description = ""
    var winPoints = ""
    var exactPoints = ""
    var allowSneakPeek = true   // default ON
    var isPublic = false        // default OFF

    func selectedTournament(in running: [Tournament]) -> Tournament? {
        guard let tournamentID else { return nil }
        return running.first { $0.id == tournamentID }
    }

    /// Web `canSave`: tournament still running AND name + both point fields non-empty.
    func canSave(running: [Tournament]) -> Bool {
        selectedTournament(in: running) != nil
            && !name.isEmpty
            && !winPoints.isEmpty
            && !exactPoints.isEmpty
    }

    /// `POST /group` body. Welcome message is sent verbatim (even empty — web parity);
    /// description is trimmed and nilled when empty; deadline = tournament kickoff.
    func payload(running: [Tournament]) -> CreateGroupRequest? {
        guard let tournament = selectedTournament(in: running),
              let win = Int(winPoints),
              let exact = Int(exactPoints)
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
            mode: 0
        )
    }
}
