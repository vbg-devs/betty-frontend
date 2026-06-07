import Foundation
import Testing
@testable import Betty

/// Pins the teams foreground-refresh rule: reload only when never loaded or stale > 24 h.
@Suite struct ForegroundRefreshPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    @Test func neverLoadedReloads() {
        #expect(ForegroundRefreshPolicy.shouldReloadTeams(isLoaded: false, loadedAt: nil, now: now))
        #expect(ForegroundRefreshPolicy.shouldReloadTeams(isLoaded: true, loadedAt: nil, now: now))
    }

    @Test func failedLoadWithTimestampStillReloads() {
        let recent = now.addingTimeInterval(-60)
        #expect(ForegroundRefreshPolicy.shouldReloadTeams(isLoaded: false, loadedAt: recent, now: now))
    }

    @Test func freshDataSkipsReload() {
        let recent = now.addingTimeInterval(-60)
        #expect(!ForegroundRefreshPolicy.shouldReloadTeams(isLoaded: true, loadedAt: recent, now: now))
    }

    @Test func exactly24HoursIsStillFresh() {
        let edge = now.addingTimeInterval(-24 * 60 * 60)
        #expect(!ForegroundRefreshPolicy.shouldReloadTeams(isLoaded: true, loadedAt: edge, now: now))
    }

    @Test func olderThan24HoursReloads() {
        let stale = now.addingTimeInterval(-24 * 60 * 60 - 1)
        #expect(ForegroundRefreshPolicy.shouldReloadTeams(isLoaded: true, loadedAt: stale, now: now))
    }
}
