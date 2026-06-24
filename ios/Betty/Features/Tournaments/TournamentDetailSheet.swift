import SwiftUI

/// Web `/dashboard/tournaments/[id]` — header (image, name, "MMM dd HH:mm" dates) over
/// the day-grouped schedule (flat wire `pools[]` + `games[]` joined client-side).
/// Fetches fresh on appear (the web page always refetches), shows the cached detail
/// while reloading, force-reloads on the `evaluate_game` socket event, and scrolls to
/// the next upcoming day. `GET /tournament/:id` 404s for unknown OR ended tournaments.
struct TournamentDetailSheet: View {
    let tournamentID: Int

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var loadFailed = false

    private var tournament: Tournament? {
        env.tournamentStore.detailsByID(tournamentID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.background.ignoresSafeArea()
                if let tournament {
                    loaded(tournament)
                } else if loadFailed {
                    failedState
                } else {
                    ProgressView()
                        .tint(Palette.orange)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    .accessibilityIdentifier("tournaments.detail.close")
                }
            }
        }
        .task { await load(force: true) }
        .task {
            for await event in env.socket.events() {
                if case .evaluateGame = event {
                    try? await env.tournamentStore.loadDetails(id: tournamentID, force: true)
                }
            }
        }
    }

    private func loaded(_ tournament: Tournament) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    header(tournament)
                    TournamentScheduleView(pools: tournament.poolsWithGames)
                }
                .padding(Space.m)
            }
            .refreshable { await load(force: true) }
            .onAppear {
                let days = TournamentSchedule.days(pools: tournament.poolsWithGames)
                guard let anchor = days.first(where: \.isNextUpcoming)?.id else { return }
                // LazyVStack hasn't laid out off-screen days yet on a real device;
                // wait one layout pass before asking the proxy to scroll.
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation {
                        proxy.scrollTo(anchor, anchor: .top)
                    }
                }
            }
        }
    }

    private func header(_ tournament: Tournament) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TournamentImageView(imageURL: tournament.imageURL)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(tournament.name)
                    .font(.bettyTitle1)
                    .displayKerning(32)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(TournamentSchedule.tournamentDates(start: tournament.startDate, end: tournament.endDate))
                    .kicker(theme.colors.textSecondary)
            }
            .padding(Space.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tournaments.detail.header")
    }

    private var failedState: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("TOURNAMENT")
                .kicker(Palette.orange)
            Text("NOT AVAILABLE.")
                .font(.bettyDisplayL)
                .displayKerning(40)
                .foregroundStyle(theme.colors.textPrimary)
            Text("This tournament could not be loaded — it may have ended.")
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textBody)
            Button("TRY AGAIN") {
                Task {
                    loadFailed = false
                    await load(force: true)
                }
            }
            .buttonStyle(.bettyOutline)
        }
        .padding(Space.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tournaments.detail.failed")
    }

    private func load(force: Bool) async {
        do {
            _ = try await env.tournamentStore.loadDetails(id: tournamentID, force: force)
            loadFailed = false
        } catch {
            // Keep showing a cached detail when one exists; only flag a hard failure.
            if tournament == nil { loadFailed = true }
        }
    }
}
