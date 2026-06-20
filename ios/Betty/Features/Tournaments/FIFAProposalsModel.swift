import Foundation
import Observation

/// State for the admin FIFA result-proposals screen (web `/admin/fifa` "Review results"
/// step). Loads staged FIFA results by status and applies (confirm) or dismisses each.
/// Mirrors the web store: a monotonic load token drops stale responses on rapid
/// Pending<->Applied switches, and confirm/dismiss remove the row from local state.
@Observable
final class FIFAProposalsModel {
    enum Tab: String, CaseIterable { case pending, applied }

    private let api: APIClient

    private(set) var tab: Tab = .pending
    private(set) var proposals: [FIFAProposal] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false
    /// The proposal currently being confirmed/dismissed (disables row actions).
    private(set) var busyProposalID: Int?

    private var loadToken = 0

    init(api: APIClient) {
        self.api = api
    }

    /// Load proposals for `tab`. A slow response cannot overwrite a newer load.
    func load(tab: Tab) async {
        self.tab = tab
        loadToken += 1
        let token = loadToken
        isLoading = true
        loadFailed = false
        defer { if token == loadToken { isLoading = false } }
        do {
            let list = try await api.fifaProposals(status: tab.rawValue)
            guard token == loadToken else { return }
            proposals = list
        } catch {
            guard token == loadToken else { return }
            loadFailed = true
        }
    }

    /// Confirm (apply) a pending proposal, then drop it from the list. Rethrows
    /// `APIError` (e.g. `.gone`) so the view can surface the reason.
    func confirm(_ proposal: FIFAProposal) async throws {
        busyProposalID = proposal.id
        defer { busyProposalID = nil }
        try await api.confirmFIFAProposal(id: proposal.id)
        proposals.removeAll { $0.id == proposal.id }
    }

    /// Dismiss a pending proposal, then drop it from the list.
    func dismiss(_ proposal: FIFAProposal) async throws {
        busyProposalID = proposal.id
        defer { busyProposalID = nil }
        try await api.dismissFIFAProposal(id: proposal.id)
        proposals.removeAll { $0.id == proposal.id }
    }
}
