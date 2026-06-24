import SwiftUI

/// Browse tab root — three sections: public groups (web `/dashboard/groups/browse`,
/// fully implemented by `BrowseGroupsScreen` with debounced search, tournament filter,
/// cursor pagination and the join flow), tournaments (`/dashboard/tournaments`), and
/// teams (`/dashboard/teams`).
struct BrowseGroupsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    fileprivate enum BrowseSection: String, CaseIterable {
        case groups = "GROUPS"
        case tournaments = "TOURNAMENTS"
        case teams = "TEAMS"
    }

    @State private var section: BrowseSection = .groups

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                sectionPicker
                    .padding(.horizontal, Space.m)
                    .padding(.vertical, Space.xs)
                switch section {
                case .groups:
                    BrowseGroupsScreen()
                case .tournaments:
                    sectionScroll(kickerText: "TOURNAMENTS", title: "THE FIELD. THE FIXTURES.") {
                        TournamentsListView()
                    } onRefresh: {
                        try? await env.tournamentStore.load()
                    }
                case .teams:
                    sectionScroll(kickerText: "TEAMS", title: "EVERY TEAM. ONE BOARD.") {
                        TeamsBrowserView()
                    } onRefresh: {
                        try? await env.teamStore.load()
                    }
                }
            }
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sectionPicker: some View {
        HStack(spacing: 3) {
            ForEach(BrowseSection.allCases, id: \.self) { item in
                Button {
                    section = item
                } label: {
                    Text(item.rawValue)
                        .font(.bettyKicker)
                        .kerning(1.4)
                        .foregroundStyle(section == item ? Palette.orange : theme.colors.textMuted)
                        .padding(.vertical, Space.xs)
                        .frame(maxWidth: .infinity)
                        .background(
                            section == item ? Palette.orangeTint18 : .clear,
                            in: RoundedRectangle(cornerRadius: Radius.sharp)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(theme.colors.overlay04, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private func sectionScroll(
        kickerText: String,
        title: String,
        @ViewBuilder content: () -> some View,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text(kickerText)
                    .kicker(Palette.orange)
                Text(title)
                    .font(.bettyDisplayL)
                    .displayKerning(40)
                    .foregroundStyle(theme.colors.textPrimary)
                content()
            }
            .padding(Space.m)
        }
        .refreshable { await onRefresh() }
    }
}
