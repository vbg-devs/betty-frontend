import Foundation

// Profile-area fixture helpers layered on DefaultScenario.
extension MockScenario {
    /// Gives the user a committed custom avatar (distinct from the provider photo) so
    /// the "REVERT TO DEFAULT PHOTO" button is visible on the profile screen.
    @discardableResult
    mutating func seedCustomAvatar(userID: String, publicAssetBase: String) -> String {
        let url = "\(publicAssetBase)/users/\(userID)/profile/seeded.png"
        updateUser(userID) {
            $0.imageURL = url
            $0.firebaseImageURL = nil
        }
        return url
    }

    /// Overrides one member's normalized score — the global leaderboard ranks by the
    /// best normalized score per user across the tournament's groups.
    mutating func profileSetNormalizedScore(groupID: Int, userID: String, to value: Double) {
        updateMember(groupID: groupID, userID: userID) { $0.normalizedScore = value }
    }
}
