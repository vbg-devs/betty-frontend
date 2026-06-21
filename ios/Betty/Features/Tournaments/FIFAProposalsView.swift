import SwiftUI

/// Web `/admin/fifa` "Review results" — the FIFA result-proposals inbox. Gated on
/// `/user/me.is_admin` (non-admins get the restricted card). Pending proposals can be
/// applied (confirm → distributes points through the same seam as manual evaluation) or
/// dismissed; the Applied tab is read-only history. Each row shows the betty matchup +
/// score (already oriented to betty home/away) so the admin verifies before applying.
struct FIFAProposalsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var model: FIFAProposalsModel?

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            if env.userStore.isAdmin {
                content
            } else {
                restricted
            }
        }
        .navigationTitle("FIFA results")
        .task {
            if model == nil {
                let created = FIFAProposalsModel(api: env.api)
                model = created
                await created.load(tab: .pending)
            }
        }
    }

    // MARK: - Admin flow

    @ViewBuilder
    private var content: some View {
        if let model {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    hero
                    tabs(model)
                    list(model)
                }
                .padding(Space.m)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("★ ADMIN")
                .kicker(Palette.orange)
            Text("REVIEW RESULTS.")
                .font(.bettyDisplayL)
                .displayKerning(40)
                .foregroundStyle(theme.colors.textPrimary)
            Text("Results Betty polled from FIFA for mapped games. Confirm to distribute points, or dismiss. Auto-applied results appear under Applied.")
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textBody)
        }
    }

    private func tabs(_ model: FIFAProposalsModel) -> some View {
        HStack(spacing: Space.s) {
            tabButton(model, .pending, "PENDING")
            tabButton(model, .applied, "APPLIED")
        }
    }

    private func tabButton(_ model: FIFAProposalsModel, _ tab: FIFAProposalsModel.Tab, _ label: String) -> some View {
        let isActive = model.tab == tab
        return Button {
            Task { await model.load(tab: tab) }
        } label: {
            Text(label)
                .kicker(isActive ? theme.colors.textPrimary : theme.colors.textMuted)
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
                .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sharp)
                        .strokeBorder(isActive ? Palette.orange : .clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("admin.fifa.tab.\(tab.rawValue)")
    }

    @ViewBuilder
    private func list(_ model: FIFAProposalsModel) -> some View {
        if model.isLoading {
            HStack {
                Spacer()
                ProgressView().tint(Palette.orange).padding(Space.xxl)
                Spacer()
            }
        } else if model.loadFailed {
            BettyInsetPanel(accent: Palette.alertRed) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Could not load proposals.")
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textBody)
                    Button("Try again") {
                        Task { await model.load(tab: model.tab) }
                    }
                    .buttonStyle(.bettyOutline)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("admin.fifa.loadFailed")
        } else if model.proposals.isEmpty {
            BettyInsetPanel {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("○ NOTHING HERE")
                        .kicker(theme.colors.textMuted)
                    Text(model.tab == .pending ? "No proposals waiting for review." : "No applied results yet.")
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textBody)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("admin.fifa.empty")
        } else {
            VStack(spacing: Space.s) {
                ForEach(model.proposals) { proposal in
                    proposalRow(model, proposal)
                }
            }
        }
    }

    private func proposalRow(_ model: FIFAProposalsModel, _ proposal: FIFAProposal) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(proposal.kind.uppercased())
                    .kicker(kindColor(proposal.kind))
                Spacer()
                if model.tab == .applied {
                    Text(proposal.source.uppercased())
                        .kicker(theme.colors.textMuted)
                }
            }

            HStack(spacing: Space.s) {
                Text(proposal.gameHomeTeam)
                    .font(.bettyHeadline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                Text("\(proposal.homeTeamScore) – \(proposal.awayTeamScore)")
                    .font(Font.system(size: 22, weight: .black).monospacedDigit())
                    .foregroundStyle(theme.colors.textPrimary)
                Text(proposal.gameAwayTeam)
                    .font(.bettyHeadline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
            }

            if let start = proposal.gameStartDate {
                Text(kickoffText(start))
                    .font(.bettySubhead)
                    .foregroundStyle(theme.colors.textMuted)
            }

            // Show the prior score for any proposal that carries one — both corrections
            // and rollbacks do (initial proposals leave prev_* null), so the admin sees
            // what a rollback reverts from before applying it.
            if let prevHome = proposal.prevHomeScore, let prevAway = proposal.prevAwayScore {
                Text("was \(prevHome) – \(prevAway)")
                    .font(.bettySubhead)
                    .foregroundStyle(theme.colors.textMuted)
            }

            if model.tab == .pending {
                HStack(spacing: Space.s) {
                    Button("Confirm") { confirm(model, proposal) }
                        .buttonStyle(.bettyPrimary)
                        .disabled(model.busyProposalID != nil)
                        .accessibilityIdentifier("admin.fifa.confirm.\(proposal.id)")
                    Button("Dismiss") { dismiss(model, proposal) }
                        .buttonStyle(.bettyGhost)
                        .disabled(model.busyProposalID != nil)
                        .accessibilityIdentifier("admin.fifa.dismiss.\(proposal.id)")
                }
            }
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.fifa.proposal.\(proposal.id)")
    }

    private func kindColor(_ kind: String) -> Color {
        kind == "rollback" ? Palette.alertRed : Palette.orange
    }

    private func kickoffText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    private func confirm(_ model: FIFAProposalsModel, _ proposal: FIFAProposal) {
        env.toasts.confirm(
            title: "Apply result",
            question: "Apply \(proposal.gameHomeTeam) \(proposal.homeTeamScore) – \(proposal.awayTeamScore) \(proposal.gameAwayTeam)? This distributes points."
        ) {
            do {
                try await model.confirm(proposal)
                env.adminProposals.decrement()
                env.toasts.alert(
                    title: "Applied",
                    message: "\(proposal.gameHomeTeam) v \(proposal.gameAwayTeam) evaluated.",
                    state: .success
                )
            } catch APIError.gone {
                // Already auto-applied by the poller — the stale pending row was dropped;
                // keep the badge in sync.
                env.adminProposals.decrement()
                env.toasts.alert(title: "Already evaluated", message: "This game was already evaluated.", state: .warning)
            } catch APIError.conflict {
                // 409: another apply (admin or auto) is racing this game. Tell the admin
                // rather than the generic "try again", which would invite a double-apply.
                env.toasts.alert(title: "Being evaluated", message: "Another apply is in progress for this game. Refresh to see the result.", state: .warning)
            } catch let error as APIError {
                env.toasts.alert(title: "Could not apply", message: error.serverMessage ?? "Please try again.", state: .error)
            } catch {
                env.toasts.alert(title: "Could not apply", message: "Please try again.", state: .error)
            }
        }
    }

    private func dismiss(_ model: FIFAProposalsModel, _ proposal: FIFAProposal) {
        Task {
            do {
                try await model.dismiss(proposal)
                env.adminProposals.decrement()
            } catch {
                env.toasts.alert(title: "Could not dismiss", message: "Please try again.", state: .error)
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
            .accessibilityIdentifier("admin.fifa.restricted")
        }
    }
}
