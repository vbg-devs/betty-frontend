import SwiftUI

/// Web `/dashboard/tournaments` — one card per RUNNING tournament (ended ones are
/// hidden, pinned), image + name; iOS adds the dates line. Tap opens the schedule.
/// Renders inside the Browse tab; never fetches on its own (store is boot-loaded).
struct TournamentsListView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var selected: Tournament?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.cardGap) {
            if env.tournamentStore.running.isEmpty {
                BettyInsetPanel {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("NOTHING RUNNING")
                            .kicker(theme.colors.textMuted)
                        Text("No running tournaments right now. Check back soon.")
                            .font(.bettyBody)
                            .foregroundStyle(theme.colors.textBody)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tournaments.list.empty")
            }
            ForEach(env.tournamentStore.running) { tournament in
                Button {
                    selected = tournament
                } label: {
                    card(tournament)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tournaments.list.card.\(tournament.id)")
            }
        }
        .sheet(item: $selected) { tournament in
            TournamentDetailSheet(tournamentID: tournament.id)
        }
    }

    private func card(_ tournament: Tournament) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TournamentImageView(imageURL: tournament.imageURL)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(tournament.name)
                    .font(.bettyTitle2)
                    .displayKerning(28)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(TournamentSchedule.tournamentDates(start: tournament.startDate, end: tournament.endDate))
                    .kicker(theme.colors.textSecondary)
                Text("VIEW SCHEDULE →")
                    .kicker(Palette.orange)
                    .padding(.top, Space.xxs)
            }
            .padding(Space.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
    }
}

/// 16:9 tournament banner; falls back to the mascot on a deep surface when the
/// tournament has no image (web falls back to a bundled stock photo).
struct TournamentImageView: View {
    var imageURL: String?

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let urlString = imageURL, !urlString.isEmpty, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .clipped()
    }

    private var placeholder: some View {
        ZStack {
            theme.colors.surfaceDeep
            Image("BettyMascot")
                .resizable()
                .scaledToFit()
                .padding(Space.l)
                .opacity(0.5)
                .accessibilityIdentifier("tournaments.image.placeholderMascot")
        }
    }
}
