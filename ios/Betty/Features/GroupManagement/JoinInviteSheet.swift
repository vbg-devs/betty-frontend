import SwiftUI

/// Outcome of `POST /join/:code` (web `JoinGroupModal.join`), mapped from the API error.
/// 409 = already a member (offer navigation), 404 = invalid/expired invite,
/// 403 = blocked; anything else is the generic failure.
nonisolated enum JoinInviteOutcome: Equatable, Sendable {
    case joined(groupID: Int)
    case alreadyMember
    case invalidInvite
    case blocked
    case failed

    static func map(_ error: any Error) -> JoinInviteOutcome {
        guard let apiError = error as? APIError else { return .failed }
        switch apiError.status {
        case 409: return .alreadyMember
        case 404: return .invalidInvite
        case 403: return .blocked
        default: return .failed
        }
    }
}

/// Web `/dashboard/groups/join/[code]` + `JoinGroupModal` — the invite deep-link entry.
///
/// Loads the preview via `GET /group/:code`, then joins via `POST /join/:code`.
/// Presented as a sheet by the deep-link router (`betty://join/<code>` and the
/// universal link `https://betty.social/dashboard/groups/join/<code>`).
struct JoinInviteSheet: View {
    let code: String

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case loading
        case loaded(GroupPeek)
        case failed
    }

    @State private var phase: Phase = .loading
    @State private var isJoining = false

    var body: some View {
        ZStack {
            theme.colors.surface.ignoresSafeArea()
            switch phase {
            case .loading:
                ProgressView()
                    .tint(theme.colors.textPrimary)
            case .loaded(let peek):
                invite(peek)
            case .failed:
                loadError
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            do {
                phase = .loaded(try await env.groupStore.peek(code: code))
            } catch {
                phase = .failed
            }
        }
    }

    // MARK: invite preview (web JoinGroupModal)

    private func invite(_ peek: GroupPeek) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let headerImageURL = peek.headerImageURL, let url = URL(string: headerImageURL) {
                        heroImage(url: url, tournamentImageURL: peek.tournamentImageURL)
                    }
                    VStack(alignment: .leading, spacing: Space.xs) {
                        if peek.headerImageURL == nil,
                           let tournamentImageURL = peek.tournamentImageURL,
                           let url = URL(string: tournamentImageURL) {
                            roundLogo(url: url, size: 96)
                                .padding(.bottom, Space.s)
                        }
                        Text("★ INVITED TO BET")
                            .kicker(Palette.orange)
                        Text(peek.name.uppercased())
                            .font(.bettyDisplayL)
                            .displayKerning(40)
                            .foregroundStyle(theme.colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("joinInvite.invite.groupName")
                        if !peek.tournamentName.isEmpty {
                            Text(peek.tournamentName.uppercased())
                                .font(.bettySubhead)
                                .kerning(1.2)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                        // Web JoinGroupModal renders the group description behind an
                        // orange left border.
                        if let description = peek.description, !description.isEmpty {
                            BettyInsetPanel(accent: Palette.orange) {
                                Text(description)
                                    .font(.betty(14, .regular))
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .lineSpacing(3)
                            }
                            .padding(.top, Space.xs)
                        }
                        Text("Lock in your bets every matchday, climb the standings, settle the banter.")
                            .font(.betty(14, .regular))
                            .foregroundStyle(theme.colors.textSecondary)
                            .lineSpacing(3)
                            .padding(.top, Space.xs)
                    }
                    .padding(Space.l)
                    .padding(.top, peek.headerImageURL == nil ? Space.s : Space.m)
                }
            }

            Divider()
                .overlay(theme.colors.overlay06)

            HStack(spacing: 0) {
                Button("NO THANKS") {
                    dismiss()
                }
                .buttonStyle(.bettyGhost)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("joinInvite.invite.declineButton")

                Button(isJoining ? "PLACING…" : "I'M IN →") {
                    join(peek)
                }
                .buttonStyle(.bettyPrimaryBlock)
                .disabled(isJoining)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("joinInvite.invite.acceptButton")
            }
            .padding(Space.m)
        }
    }

    private func heroImage(url: URL, tournamentImageURL: String?) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                theme.colors.overlay04
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            if let tournamentImageURL, let iconURL = URL(string: tournamentImageURL) {
                roundLogo(url: iconURL, size: 56)
                    .padding(.leading, Space.l)
                    .offset(y: 22)
            }
        }
    }

    private func roundLogo(url: URL, size: CGFloat) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                theme.colors.overlay06
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(theme.colors.overlay10, lineWidth: 2)
        }
        .background {
            Circle().fill(theme.colors.surface)
        }
    }

    // MARK: load failure (web join/[code].vue error state)

    private var loadError: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("★ INVITED TO BET")
                .kicker(Palette.orange)
            Text("COULD NOT LOAD THIS INVITE")
                .font(.bettyTitle2)
                .foregroundStyle(theme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("joinInvite.error.title")
            Text("The invite link may be invalid or expired. Please check the link and try again.")
                .font(.betty(14, .regular))
                .foregroundStyle(theme.colors.textSecondary)
                .lineSpacing(3)
            Button("GO TO DASHBOARD") {
                dismiss()
                env.router.selectedTab = .home
            }
            .buttonStyle(.bettyOutline)
            .accessibilityIdentifier("joinInvite.error.dashboardButton")
            Spacer()
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: join

    private func join(_ peek: GroupPeek) {
        isJoining = true
        Task {
            defer { isJoining = false }
            let outcome: JoinInviteOutcome
            do {
                outcome = .joined(groupID: try await env.groupStore.join(code: code))
            } catch {
                outcome = JoinInviteOutcome.map(error)
            }
            handle(outcome, peek: peek)
        }
    }

    private func handle(_ outcome: JoinInviteOutcome, peek: GroupPeek) {
        switch outcome {
        case .joined(let groupID):
            dismiss()
            env.toasts.confirm(question: "You are now a proud member of \(peek.name). Go there now?") {
                navigate(to: groupID)
            }
        case .alreadyMember:
            dismiss()
            env.toasts.confirm(question: "It looks like you're already member of \(peek.name). Go there now?") {
                navigate(to: peek.id)
            }
        case .invalidInvite:
            env.toasts.alert(
                title: "Could not join group",
                message: "This invite link is invalid or has expired.",
                state: .critical
            )
        case .blocked:
            env.toasts.alert(
                title: "Cannot bet here",
                message: "You have been blocked from \(peek.name).",
                state: .warning
            )
        case .failed:
            env.toasts.alert(
                title: "Could not join group",
                message: "Something went wrong while joining the group. Please try again.",
                state: .critical
            )
        }
    }

    private func navigate(to groupID: Int) {
        env.router.selectedTab = .home
        env.router.homePath = [.groupDetail(groupID: groupID)]
    }
}
