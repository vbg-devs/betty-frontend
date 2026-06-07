import SwiftUI

/// Web `/admin` — post final scores for kicked-off games; the backend distributes
/// points. Gated on `/user/me.is_admin` (non-admins get the restricted card). Flow:
/// pick an ongoing tournament → un-evaluated games sorted by kickoff → score sheet →
/// confirm → `POST /evaluategame` → success toast + refetch.
struct AdminEvaluateView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var model: AdminEvaluateModel?
    @State private var evaluatingGame: Game?

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            if env.userStore.isAdmin {
                adminContent
            } else {
                restricted
            }
        }
        .navigationTitle("Admin")
        .task {
            if model == nil { model = AdminEvaluateModel(api: env.api) }
        }
        .sheet(item: $evaluatingGame) { game in
            if let model {
                EvaluateGameSheet(game: game, model: model)
            }
        }
    }

    // MARK: - Admin flow

    private var adminContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                hero
                tournamentSection
                if let model, model.selectedTournamentID != nil {
                    gamesSection(model)
                }
            }
            .padding(Space.m)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("★ ADMIN")
                .kicker(Palette.orange)
            Text("EVALUATE GAMES.")
                .font(.bettyDisplayL)
                .displayKerning(40)
                .foregroundStyle(theme.colors.textPrimary)
            Text("Pick an ongoing tournament, choose a game that has kicked off, and post the final score. Betty distributes the points.")
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textBody)
        }
    }

    private var tournamentSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("● ONGOING")
                .kicker(Palette.orange)
            Text("PICK A TOURNAMENT.")
                .font(.bettyTitle1)
                .displayKerning(32)
                .foregroundStyle(theme.colors.textPrimary)

            if env.tournamentStore.running.isEmpty {
                BettyInsetPanel {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("○ NOTHING RUNNING")
                            .kicker(theme.colors.textMuted)
                        Text("No ongoing tournaments right now. There is nothing to evaluate.")
                            .font(.bettyBody)
                            .foregroundStyle(theme.colors.textBody)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tournaments.admin.noTournaments")
            } else {
                ForEach(env.tournamentStore.running) { tournament in
                    tournamentCard(tournament)
                }
            }
        }
    }

    private func tournamentCard(_ tournament: Tournament) -> some View {
        let isSelected = model?.selectedTournamentID == tournament.id
        return Button {
            select(tournament)
        } label: {
            HStack(spacing: Space.s) {
                TournamentImageView(imageURL: tournament.imageURL)
                    .frame(width: 76, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
                Text(tournament.name)
                    .font(.bettyHeadline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2)
                Spacer()
                Text(isSelected ? "● SELECTED" : "SELECT →")
                    .kicker(isSelected ? Palette.orange : theme.colors.textMuted)
            }
            .padding(Space.s)
            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sharp)
                    .strokeBorder(isSelected ? Palette.orange : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tournaments.admin.tournament.\(tournament.id)")
    }

    @ViewBuilder
    private func gamesSection(_ model: AdminEvaluateModel) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("● UPCOMING & PLAYED")
                .kicker(Palette.orange)
            Text(selectedTournamentName.uppercased())
                .font(.bettyTitle1)
                .displayKerning(32)
                .foregroundStyle(theme.colors.textPrimary)

            if model.isLoadingDetails {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Palette.orange)
                        .padding(Space.xxl)
                    Spacer()
                }
            } else if model.loadFailed {
                BettyInsetPanel(accent: Palette.alertRed) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Could not load this tournament's games.")
                            .font(.bettyBody)
                            .foregroundStyle(theme.colors.textBody)
                        Button("TRY AGAIN") {
                            Task { try? await model.reloadDetails() }
                        }
                        .buttonStyle(.bettyOutline)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tournaments.admin.loadFailed")
            } else if model.pendingGames.isEmpty {
                BettyInsetPanel {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("○ NO GAMES TO EVALUATE")
                            .kicker(theme.colors.textMuted)
                        Text("Every game in this tournament has already been evaluated.")
                            .font(.bettyBody)
                            .foregroundStyle(theme.colors.textBody)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tournaments.admin.noPendingGames")
            } else {
                ForEach(model.pendingGames) { game in
                    TournamentGameCard(game: game) { tapped in
                        evaluatingGame = tapped
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("tournaments.admin.game.\(game.id)")
                }
            }
        }
    }

    private var selectedTournamentName: String {
        guard let id = model?.selectedTournamentID else { return "" }
        return env.tournamentStore.byID(id)?.name ?? model?.details?.name ?? ""
    }

    private func select(_ tournament: Tournament) {
        guard let model else { return }
        Task {
            do {
                try await model.select(tournamentID: tournament.id)
            } catch {
                env.toasts.alert(
                    title: "Could not load tournament",
                    message: "Please try again.",
                    state: .error
                )
            }
        }
    }

    // MARK: - Non-admin

    private var restricted: some View {
        ScrollView {
            BettyCard(padding: Space.xxl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("★ RESTRICTED")
                        .kicker(Palette.orange)
                    Text("YOU ARE NOT ADMIN.")
                        .font(.bettyDisplayL)
                        .displayKerning(40)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("This page is for tournament admins only.")
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textBody)
                }
            }
            .padding(Space.m)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tournaments.admin.restricted")
        }
    }
}

/// The web admin evaluate modal: HOME/AWAY score inputs, save enabled only once the
/// game kicked off with both scores entered, native confirmation before posting.
/// Errors render inline (the toast overlay sits beneath this sheet); 410 means the
/// game was already processed.
private struct EvaluateGameSheet: View {
    let game: Game
    let model: AdminEvaluateModel

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var homeScore = ""
    @State private var awayScore = ""
    @State private var isConfirming = false
    @State private var errorMessage: String?

    private var homeTeam: Team? { env.teamStore.byID(game.homeTeamID) }
    private var awayTeam: Team? { env.teamStore.byID(game.awayTeamID) }

    private var hasStarted: Bool { game.startDate < Date() }

    private var canSave: Bool {
        AdminEvaluateModel.canSave(game: game, homeScore: homeScore, awayScore: awayScore)
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Space.m) {
                Text("★ EVALUATE GAME")
                    .kicker(Palette.orange)
                Text("POST THE SCORE.")
                    .font(.bettyTitle1)
                    .displayKerning(32)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("\(homeTeam?.name ?? "") vs \(awayTeam?.name ?? "")")
                    .kicker(theme.colors.textSecondary)

                HStack(alignment: .bottom, spacing: Space.s) {
                    scoreColumn("HOME", text: $homeScore)
                    Text("–")
                        .font(.betty(32))
                        .foregroundStyle(theme.colors.textSecondary)
                        .padding(.bottom, Space.m)
                    scoreColumn("AWAY", text: $awayScore)
                }

                if !hasStarted {
                    Text("This game has not kicked off yet — the score can only be posted after the start.")
                        .font(.bettySubhead)
                        .foregroundStyle(theme.colors.textMuted)
                        .accessibilityIdentifier("tournaments.admin.evaluate.notStarted")
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.bettySubhead)
                        .foregroundStyle(Palette.alertRed)
                        .accessibilityIdentifier("tournaments.admin.evaluate.error")
                }

                Spacer()

                Button(model.isSubmitting ? "EVALUATING…" : "EVALUATE GAME") {
                    isConfirming = true
                }
                .buttonStyle(.bettyPrimaryBlock)
                .disabled(!canSave || model.isSubmitting)
                .accessibilityIdentifier("tournaments.admin.evaluate.submit")
            }
            .padding(Space.xl)
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog(
            confirmQuestion,
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Evaluate game") {
                Task { await submit() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var confirmQuestion: String {
        AdminEvaluateModel.confirmQuestion(
            homeTeam: homeTeam?.name,
            awayTeam: awayTeam?.name,
            homeScore: homeScore,
            awayScore: awayScore
        )
    }

    private func scoreColumn(_ label: String, text: Binding<String>) -> some View {
        VStack(spacing: Space.xs) {
            Text(label)
                .kicker(theme.colors.textSecondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Font.system(size: 48, weight: .black).monospacedDigit())
                .foregroundStyle(theme.colors.textPrimary)
                .padding(.vertical, Space.s)
                .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sharp)
                        .strokeBorder(theme.colors.overlay10, lineWidth: 1)
                }
                .onChange(of: text.wrappedValue) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue { text.wrappedValue = filtered }
                }
                .accessibilityIdentifier("tournaments.admin.evaluate.\(label.lowercased())")
        }
        .frame(maxWidth: .infinity)
    }

    private func submit() async {
        guard let home = Int(homeScore), let away = Int(awayScore) else { return }
        errorMessage = nil
        do {
            try await model.evaluate(game: game, homeScore: home, awayScore: away)
            dismiss()
            env.toasts.alert(title: "Game evaluated!", message: "Yeeeeeah", state: .success)
        } catch let error as APIError {
            if case .gone = error {
                errorMessage = "This game was already evaluated."
            } else {
                errorMessage = error.serverMessage ?? "Could not evaluate the game. Please try again."
            }
        } catch {
            errorMessage = "Could not evaluate the game. Please try again."
        }
    }
}
