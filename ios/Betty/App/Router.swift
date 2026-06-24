import Foundation
import Observation
import SwiftUI

/// Every push destination in the app (one case per screen in the screens spec; sheets
/// live in `SheetDestination`).
enum Destination: Hashable {
    case groupDetail(groupID: Int)
    case groupChat(groupID: Int)
    case support
    case about
    case adminEvaluate
    case adminFIFAProposals
}

/// Modal flows (web modals → sheets).
enum SheetDestination: Identifiable, Hashable {
    case createGroup
    case joinInvite(code: String)
    case bet(gameID: Int, groupID: Int)
    case userHistory(groupID: Int, userID: String)
    case groupSettings(groupID: Int)

    var id: Self { self }
}

enum AppTab: Hashable {
    case home
    case browse
    case leaderboard
    case activity
    case profile
}

/// Parsed deep link. Supported (mirroring `safeReturnUrl` strictness — only these
/// patterns, everything else ignored):
/// - `https://betty.social/dashboard/groups/join/<code>` (universal link)
/// - `https://betty.social/groups/<groupID>/games/<gameID>` (reminder push universal link)
/// - `betty://join/<code>`
/// - `betty://group/<id>`
/// - `betty://leaderboard/<tournamentId>`
/// - `betty://dashboard`
/// - `betty://bet/<groupID>/<gameID>`
enum DeepLink: Equatable {
    case join(code: String)
    case group(id: Int)
    case leaderboard(tournamentID: Int)
    case dashboard
    case bet(gameID: Int, groupID: Int)

    static func parse(_ url: URL) -> DeepLink? {
        if url.scheme == "betty" {
            let host = url.host ?? ""
            let parts = url.pathComponents.filter { $0 != "/" }
            switch host {
            case "join":
                guard let code = parts.first, isValidInviteCode(code) else { return nil }
                return .join(code: code)
            case "group":
                guard let raw = parts.first, let id = Int(raw) else { return nil }
                return .group(id: id)
            case "leaderboard":
                guard let raw = parts.first, let id = Int(raw) else { return nil }
                return .leaderboard(tournamentID: id)
            case "dashboard":
                return .dashboard
            case "bet":
                guard parts.count == 2, let gid = Int(parts[0]), let gameid = Int(parts[1]) else { return nil }
                return .bet(gameID: gameid, groupID: gid)
            default:
                return nil
            }
        }
        if url.scheme == "https", url.host == "betty.social" {
            let parts = url.pathComponents.filter { $0 != "/" }
            // /dashboard/groups/join/<code>
            if parts.count == 4, parts[0] == "dashboard", parts[1] == "groups", parts[2] == "join",
               isValidInviteCode(parts[3]) {
                return .join(code: parts[3])
            }
            // /groups/<groupID>/games/<gameID>  — reminder push universal link
            if parts.count == 4, parts[0] == "groups", parts[2] == "games",
               let gid = Int(parts[1]), let gameid = Int(parts[3]) {
                return .bet(gameID: gameid, groupID: gid)
            }
        }
        return nil
    }

    /// Invite codes are `[A-Za-z0-9-]+` — never store anything looser.
    static func isValidInviteCode(_ code: String) -> Bool {
        !code.isEmpty && code.allSatisfy { $0.isLetter && $0.isASCII || $0.isNumber && $0.isASCII || $0 == "-" }
    }
}

/// Navigation state: tab selection, one typed path per tab, the active sheet, and the
/// pending deep link captured while signed out (replayed by `AppEnvironment.onSignedIn`).
@Observable
final class Router {
    var selectedTab: AppTab = .home

    var homePath: [Destination] = []
    var browsePath: [Destination] = []
    var leaderboardPath: [Destination] = []
    var activityPath: [Destination] = []
    var profilePath: [Destination] = []

    var activeSheet: SheetDestination?

    /// Leaderboard tab's selected tournament (set by deep links; nil = default rule).
    var leaderboardTournamentID: Int?

    private(set) var pendingDeepLink: DeepLink?

    /// `onOpenURL` entry point. When the session isn't ready the link is stashed and
    /// replayed after auth + profile completion.
    func handle(url: URL, isReady: Bool) {
        guard let link = DeepLink.parse(url) else { return }
        if isReady {
            perform(link)
        } else {
            pendingDeepLink = link
        }
    }

    func replayPendingDeepLink() {
        guard let link = pendingDeepLink else { return }
        pendingDeepLink = nil
        perform(link)
    }

    func perform(_ link: DeepLink) {
        switch link {
        case .join(let code):
            selectedTab = .home
            activeSheet = .joinInvite(code: code)
        case .group(let id):
            selectedTab = .home
            homePath = [.groupDetail(groupID: id)]
        case .leaderboard(let tournamentID):
            leaderboardTournamentID = tournamentID
            selectedTab = .leaderboard
        case .dashboard:
            selectedTab = .home
            homePath = []
        case .bet(let gameID, let groupID):
            selectedTab = .home
            homePath = [.groupDetail(groupID: groupID)]
            activeSheet = .bet(gameID: gameID, groupID: groupID)
        }
    }

    func reset() {
        selectedTab = .home
        homePath = []
        browsePath = []
        leaderboardPath = []
        activityPath = []
        profilePath = []
        activeSheet = nil
        leaderboardTournamentID = nil
        pendingDeepLink = nil
    }
}
