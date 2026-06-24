import SwiftUI

/// Web `/dashboard/teams` — every team from the boot-loaded store in store order
/// (the web renders bare names; here each gets its `TeamLogoView`). iOS adds a local
/// name filter. Never fetches on its own (pinned on the web page).
struct TeamsBrowserView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var query = ""

    private var teams: [Team] {
        let all = env.teamStore.teams
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            searchField
            if teams.isEmpty {
                BettyInsetPanel {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("NO TEAMS")
                            .kicker(theme.colors.textMuted)
                        Text(query.isEmpty
                             ? "No teams loaded yet. Pull to refresh."
                             : "No teams match \"\(query)\".")
                            .font(.bettyBody)
                            .foregroundStyle(theme.colors.textBody)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tournaments.teams.empty")
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 100), spacing: Space.s)],
                    spacing: Space.s
                ) {
                    ForEach(teams) { team in
                        teamCell(team)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("tournaments.teams.cell.\(team.id)")
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colors.textMuted)
            TextField("Search teams", text: $query)
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("tournaments.teams.search")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.colors.textMuted)
                }
                .accessibilityIdentifier("tournaments.teams.clearSearch")
            }
        }
        .padding(Space.s)
        .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private func teamCell(_ team: Team) -> some View {
        VStack(spacing: Space.xs) {
            TeamLogoView(team: team, size: 56)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tournaments.teams.logo.\(team.id)")
            Text(team.name.uppercased())
                .font(.bettyCaption)
                .kerning(0.6)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s)
        .padding(.horizontal, Space.xxs)
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }
}
