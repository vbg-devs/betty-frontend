import SwiftUI

/// Web `CreateGroupModal` — two steps: form, then a success step with the invite link.
///
/// Pinned web behavior: tournament picker lists only running tournaments; CREATE is
/// enabled when the selected tournament is still running AND name + both point fields
/// are non-empty; the payload sends `group_play_deadline = tournament.start_date`,
/// the welcome message verbatim, and a trimmed-or-null description; on failure the
/// form stays open with input preserved.
struct CreateGroupSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var form = CreateGroupForm()
    @State private var isCreating = false
    @State private var createdGroup: Group?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.colors.background.ignoresSafeArea()
            if let createdGroup {
                successStep(createdGroup)
            } else {
                formStep
            }
            closeButton
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: form step

    private var formStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("★ NEW GROUP")
                    .kicker(Palette.orange)
                Text("START A GROUP")
                    .font(.bettyTitle1)
                    .displayKerning(32)
                    .foregroundStyle(theme.colors.textPrimary)

                GroupFormField(label: "Tournament") {
                    tournamentPicker
                }

                GroupFormField(label: "Group name") {
                    GroupFormTextField(placeholder: "Sunday Roast XI", text: $form.name)
                        .accessibilityIdentifier("createGroup.form.nameField")
                }

                GroupFormField(label: "Welcome message") {
                    GroupFormTextField(
                        placeholder: "The smack-talk starts here…",
                        text: $form.welcomeMessage,
                        axis: .vertical,
                        lineRange: 2...4
                    )
                    .accessibilityIdentifier("createGroup.form.welcomeField")
                }

                GroupFormField(label: "Description") {
                    GroupFormTextField(
                        placeholder: "Shown on the public board. Pitch your group in a sentence or two…",
                        text: $form.description,
                        axis: .vertical,
                        lineRange: 2...5
                    )
                    .accessibilityIdentifier("createGroup.form.descriptionField")
                    GroupDescriptionCounter(count: form.description.count)
                }
                .onChange(of: form.description) {
                    if form.description.count > CreateGroupForm.maxDescriptionLength {
                        form.description = String(form.description.prefix(CreateGroupForm.maxDescriptionLength))
                    }
                }

                HStack(alignment: .top, spacing: Space.s) {
                    GroupFormField(label: "Winning team pts") {
                        GroupFormTextField(placeholder: "2", text: $form.winPoints, keyboard: .numberPad)
                            .accessibilityIdentifier("createGroup.form.winPointsField")
                    }
                    GroupFormField(label: "Exact score pts") {
                        GroupFormTextField(placeholder: "4", text: $form.exactPoints, keyboard: .numberPad)
                            .accessibilityIdentifier("createGroup.form.exactPointsField")
                    }
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(alignment: .top, spacing: Space.s) {
                        GroupFormField(label: "Boosters per user") {
                            GroupFormTextField(placeholder: "0", text: $form.boostCount, keyboard: .numberPad)
                                .accessibilityIdentifier("createGroup.form.boostCountField")
                        }
                        GroupFormField(label: "Booster multiplier") {
                            GroupFormTextField(placeholder: "2", text: $form.boostMultiplier, keyboard: .numberPad)
                                .accessibilityIdentifier("createGroup.form.boostMultiplierField")
                                .disabled(form.isMultiplierDisabled)
                                .opacity(form.isMultiplierDisabled ? 0.55 : 1)
                        }
                    }
                    Text("Members can apply a booster to multiply a single bet's points. Set count to 0 to disable.")
                        .font(.betty(12, .regular))
                        .foregroundStyle(theme.colors.textSecondary)
                        .lineSpacing(2)
                        .accessibilityIdentifier("createGroup.form.boostHelp")
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    GroupFormCheckRow(
                        title: "Lone Ranger bonus",
                        subtitle: "If exactly one member predicts the winning side of a game, they earn these bonus points. Draws don't count.",
                        isOn: $form.loneRangerEnabled
                    )
                    .accessibilityIdentifier("createGroup.form.loneRangerToggle")
                    GroupFormField(label: "Bonus points") {
                        GroupFormTextField(placeholder: "0", text: $form.loneRangerPoints, keyboard: .numberPad)
                            .accessibilityIdentifier("createGroup.form.loneRangerPointsField")
                            .disabled(form.isLoneRangerPointsDisabled)
                            .opacity(form.isLoneRangerPointsDisabled ? 0.55 : 1)
                    }
                }

                GroupFormCheckRow(
                    title: "Allow sneak peek",
                    subtitle: "Members can see each other's bets before the game starts.",
                    isOn: $form.allowSneakPeek
                )
                .accessibilityIdentifier("createGroup.form.sneakPeekToggle")

                GroupFormCheckRow(
                    title: "Make this group public",
                    subtitle: "Anyone can discover and bet in this group — no invite link needed.",
                    isOn: $form.isPublic
                )
                .accessibilityIdentifier("createGroup.form.publicToggle")

                Button(isCreating ? "CREATING…" : "CREATE GROUP") {
                    create()
                }
                .buttonStyle(.bettyPrimaryBlock)
                .disabled(isCreating || !form.canSave(running: env.tournamentStore.running))
                .accessibilityIdentifier("createGroup.form.submitButton")
            }
            .padding(Space.m)
            .padding(.top, Space.s)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { KeyboardDoneBar() }
    }

    private var tournamentPicker: some View {
        Menu {
            ForEach(env.tournamentStore.running) { tournament in
                Button(tournament.name) {
                    form.tournamentID = tournament.id
                }
            }
        } label: {
            HStack {
                Text(selectedTournamentName ?? "Select tournament")
                    .font(.betty(15, .semibold))
                    .foregroundStyle(selectedTournamentName == nil ? theme.colors.textMuted : theme.colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .padding(Space.s)
            .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sharp)
                    .strokeBorder(theme.colors.overlay10, lineWidth: 1)
            }
        }
        .accessibilityIdentifier("createGroup.form.tournamentPicker")
    }

    private var selectedTournamentName: String? {
        form.selectedTournament(in: env.tournamentStore.running)?.name
    }

    // MARK: success step

    private func successStep(_ group: Group) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("★ YOU NAILED IT")
                    .kicker(Palette.orange)
                Text("GROUP CREATED.")
                    .font(.bettyTitle1)
                    .displayKerning(32)
                    .foregroundStyle(theme.colors.textPrimary)
                (Text(group.name).font(.betty(14, .heavy)).foregroundStyle(theme.colors.textPrimary)
                    + Text(" is live. Share the link below to drag your friends in.")
                        .font(.betty(14, .regular)).foregroundStyle(theme.colors.textSecondary))
                    .lineSpacing(3)

                if let inviteLink = group.inviteLink {
                    Text("★ INVITE LINK")
                        .kicker(theme.colors.textSecondary)
                        .padding(.top, Space.xs)
                    InviteLinkRow(link: inviteLink)
                }

                Button("GO TO GROUP →") {
                    dismiss()
                    env.router.selectedTab = .home
                    env.router.homePath = [.groupDetail(groupID: group.id)]
                }
                .buttonStyle(.bettyPrimaryBlock)
                .padding(.top, Space.s)
                .accessibilityIdentifier("createGroup.success.goToGroupButton")
            }
            .padding(Space.m)
            .padding(.top, Space.s)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.textSecondary)
                .padding(Space.s)
        }
        .padding(.top, Space.s)
        .padding(.trailing, Space.xs)
        .accessibilityLabel("Close")
    }

    // MARK: actions

    private func create() {
        guard let payload = form.payload(running: env.tournamentStore.running) else { return }
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                let groupID = try await env.groupStore.create(payload)
                if let group = env.groupStore.byID(groupID) {
                    createdGroup = group
                } else {
                    // Reload missed the new group — stay in form mode with input
                    // preserved (web parity), surfaced as a toast on iOS.
                    env.toasts.alert(
                        title: "Could not create group",
                        message: "Something went wrong. Please try again.",
                        state: .error
                    )
                }
            } catch {
                env.toasts.alert(
                    title: "Could not create group",
                    message: "Something went wrong. Please try again.",
                    state: .error
                )
            }
        }
    }
}
