import SwiftUI

/// `.groupSettings` sheet (web `GroupSettingsModal` + the sidebar management cards).
/// The full implementation lives in `GroupSettingsScreen` (Features/GroupManagement);
/// this type keeps the `GroupSettingsSheet(groupID:)` signature `MainTabView` references.
struct GroupSettingsSheet: View {
    let groupID: Int

    var body: some View {
        GroupSettingsScreen(groupID: groupID)
    }
}
