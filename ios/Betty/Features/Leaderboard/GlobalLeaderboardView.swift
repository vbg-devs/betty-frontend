import SwiftUI

/// Leaderboard tab root (web `/leaderboard` + `/leaderboard/[id]`). The full
/// implementation lives in `GlobalLeaderboardScreen` (Features/Profile); this type keeps
/// the name `MainTabView` references.
struct GlobalLeaderboardView: View {
    var body: some View {
        GlobalLeaderboardScreen()
    }
}
