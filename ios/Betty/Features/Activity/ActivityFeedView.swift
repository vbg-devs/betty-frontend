import SwiftUI

/// Web `SideBar`/`ActivityFeed` — live global event ticker over the WebSocket, rendered
/// with the per-type styled rows (`ActivityEventRow`: kicker + accent + bold segments +
/// lazy game/team loading). CLEAR ALL empties the feed.
struct ActivityFeedView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s) {
                    if !env.activityFeed.entries.isEmpty {
                        HStack {
                            Text("★ ACTIVITY")
                                .kicker(Palette.orange)
                            Spacer()
                            Button("CLEAR ALL") {
                                env.activityFeed.clearAll()
                            }
                            .buttonStyle(.bettyGhost)
                        }
                    } else {
                        ScreenPlaceholder(
                            kickerText: "ACTIVITY",
                            title: "ALL QUIET.",
                            note: "Live events from everyone on Betty appear here as they happen."
                        )
                        .frame(height: 240)
                    }
                    ForEach(env.activityFeed.entries) { entry in
                        ActivityEventRow(event: entry.event)
                    }
                }
                .padding(Space.m)
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}
