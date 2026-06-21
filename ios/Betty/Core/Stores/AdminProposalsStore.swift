import Foundation
import Observation

/// Admin-only live count of pending FIFA result proposals (web `useAdminProposals`).
///
/// Backs the count badge on the profile "FIFA results" row and surfaces a toast when
/// *new* proposals arrive. The composition root polls `refresh()` while the app is
/// foregrounded and only for admins (the count endpoint is admin-guarded). Poll errors
/// are swallowed: a best-effort badge must never disrupt the app.
@Observable
final class AdminProposalsStore {
    private(set) var pendingCount = 0
    /// nil until the first successful poll, so the first load never toasts.
    private var lastCount: Int?
    private var pollTask: Task<Void, Never>?

    private let fetchCount: () async throws -> Int
    private let pollInterval: Duration

    /// Invoked when the pending count increases (new proposals staged) — set by the
    /// composition root to raise a toast. Not called on the first load, nor when the
    /// count drops because the admin just confirmed some.
    var onNewProposals: ((Int) -> Void)?

    init(pollInterval: Duration = .seconds(60), fetchCount: @escaping () async throws -> Int) {
        self.pollInterval = pollInterval
        self.fetchCount = fetchCount
    }

    /// Fetch the count once, update the badge, and fire `onNewProposals` on an increase.
    func refresh() async {
        do {
            let next = try await fetchCount()
            if let last = lastCount, next > last {
                onNewProposals?(next)
            }
            lastCount = next
            pendingCount = next
        } catch {
            // Swallow: the badge poll is best-effort and must not disrupt the app.
        }
    }

    /// Begin polling while foregrounded. Idempotent; refreshes immediately.
    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                guard let interval = self?.pollInterval else { return }
                try? await Task.sleep(for: interval)
            }
        }
    }

    /// Pause polling (e.g. on background) while keeping the last known count.
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Full reset on sign-out / losing admin.
    func reset() {
        stopPolling()
        pendingCount = 0
        lastCount = nil
    }
}
