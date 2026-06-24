import SwiftUI

/// Full group-settings experience (web `GroupSettingsModal` + the GroupDetail sidebar
/// management cards): author-only house-rules form, invite share/rotate, public/private
/// toggle, member management (block), and leave group.
///
/// Rendered by `GroupSettingsSheet` (Features/GroupDetail), the `.groupSettings`
/// sheet body.
struct GroupSettingsScreen: View {
    let groupID: Int

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var form: GroupSettingsForm?
    @State private var isSaving = false
    @State private var publicToggle = false
    @State private var isWorking = false

    private var group: Group? { env.groupStore.byID(groupID) }

    private var isAuthor: Bool {
        group?.member(withUserID: env.userStore.id)?.isAuthor ?? false
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.colors.background.ignoresSafeArea()
            if let group {
                content(group)
            } else {
                missingGroup
            }
            closeButton
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let group {
                if form == nil {
                    form = GroupSettingsForm(group: group)
                }
                publicToggle = group.isPublic
            }
        }
        .onChange(of: group?.isPublic) { _, newValue in
            publicToggle = newValue ?? false
        }
    }

    private func content(_ group: Group) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.cardGap) {
                header(group)
                if isAuthor {
                    houseRulesForm(group)
                    visibilityCard
                } else {
                    houseRulesSummary(group)
                }
                inviteCard(group)
                membersCard(group)
                leaveCard(group)
            }
            .padding(Space.m)
            .padding(.top, Space.s)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { KeyboardDoneBar() }
    }

    // MARK: header

    private func header(_ group: Group) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("★ GROUP SETTINGS")
                .kicker(Palette.orange)
            Text(isAuthor ? "EDIT GROUP." : group.name.uppercased())
                .font(.bettyTitle1)
                .displayKerning(32)
                .foregroundStyle(theme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(isAuthor
                ? "Tune the welcome and the house rules. Only you, as the group author, can see this."
                : "House rules, invite link, and the roster — all in one place.")
                .font(.betty(14, .regular))
                .foregroundStyle(theme.colors.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: house rules (author form / member summary)

    @ViewBuilder
    private func houseRulesForm(_ group: Group) -> some View {
        if form != nil {
            let formBinding = Binding(
                get: { form ?? GroupSettingsForm(group: group) },
                set: { form = $0 }
            )
            BettyCard {
                VStack(alignment: .leading, spacing: Space.m) {
                    Text("HOUSE RULES")
                        .kicker(theme.colors.textSecondary)

                    GroupFormField(label: "Welcome message") {
                        GroupFormTextField(
                            placeholder: "The smack-talk starts here…",
                            text: formBinding.welcomeMessage,
                            axis: .vertical,
                            lineRange: 2...4
                        )
                        .accessibilityIdentifier("groupSettings.form.welcomeField")
                    }

                    GroupFormField(label: "Description") {
                        GroupFormTextField(
                            placeholder: "Shown on the public board. Pitch your group in a sentence or two…",
                            text: formBinding.description,
                            axis: .vertical,
                            lineRange: 2...5
                        )
                        .accessibilityIdentifier("groupSettings.form.descriptionField")
                        GroupDescriptionCounter(
                            count: formBinding.wrappedValue.description.count,
                            limit: GroupSettingsForm.maxDescriptionLength
                        )
                    }
                    .onChange(of: form?.description) {
                        if var current = form, current.description.count > GroupSettingsForm.maxDescriptionLength {
                            current.description = String(current.description.prefix(GroupSettingsForm.maxDescriptionLength))
                            form = current
                        }
                    }

                    HStack(alignment: .top, spacing: Space.s) {
                        GroupFormField(label: "Winning team pts") {
                            GroupFormTextField(placeholder: "2", text: formBinding.winPoints, keyboard: .numberPad)
                                .accessibilityIdentifier("groupSettings.form.winPointsField")
                        }
                        GroupFormField(label: "Exact score pts") {
                            GroupFormTextField(placeholder: "4", text: formBinding.exactPoints, keyboard: .numberPad)
                                .accessibilityIdentifier("groupSettings.form.exactPointsField")
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.xs) {
                        HStack(alignment: .top, spacing: Space.s) {
                            GroupFormField(label: "Boosters per user") {
                                GroupFormTextField(placeholder: "0", text: formBinding.boostCount, keyboard: .numberPad)
                                    .accessibilityIdentifier("groupSettings.form.boostCountField")
                            }
                            GroupFormField(label: "Booster multiplier") {
                                GroupFormTextField(placeholder: "2", text: formBinding.boostMultiplier, keyboard: .numberPad)
                                    .accessibilityIdentifier("groupSettings.form.boostMultiplierField")
                                    .disabled(formBinding.wrappedValue.isMultiplierDisabled)
                                    .opacity(formBinding.wrappedValue.isMultiplierDisabled ? 0.55 : 1)
                            }
                        }
                        Text("Members can apply a booster to multiply a single bet's points. Set count to 0 to disable.")
                            .font(.betty(12, .regular))
                            .foregroundStyle(theme.colors.textSecondary)
                            .lineSpacing(2)
                            .accessibilityIdentifier("groupSettings.form.boostHelp")
                    }

                    GroupFormCheckRow(
                        title: "Allow sneak peek",
                        subtitle: "Members can see each other's bets before the game starts.",
                        isOn: formBinding.allowSneakPeek
                    )
                    .accessibilityIdentifier("groupSettings.form.sneakPeekToggle")

                    Button(isSaving ? "SAVING…" : "SAVE CHANGES") {
                        save()
                    }
                    .buttonStyle(.bettyPrimaryBlock)
                    .disabled(isSaving || !(form?.canSave ?? false) || !(form?.isDirty ?? false))
                    .accessibilityIdentifier("groupSettings.form.saveButton")
                }
            }
        }
    }

    private func houseRulesSummary(_ group: Group) -> some View {
        BettyInsetPanel {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("HOUSE RULES")
                    .kicker(theme.colors.textSecondary)
                summaryRow(label: "Winning team", value: "\(group.correctTeamPoints) PTS")
                summaryRow(label: "Exact score", value: "\(group.exactResultPoints) PTS")
                summaryRow(label: "Sneak peek", value: group.allowSneakPeek ? "ALLOWED" : "CLOSED")
            }
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .kicker(theme.colors.textMuted)
            Spacer()
            Text(value)
                .font(.bettySubhead)
                .foregroundStyle(theme.colors.textPrimary)
        }
    }

    // MARK: visibility (author only)

    private var visibilityCard: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("VISIBILITY")
                    .kicker(theme.colors.textSecondary)
                Toggle(isOn: $publicToggle) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Public group")
                            .font(.betty(13, .bold))
                            .foregroundStyle(theme.colors.textPrimary)
                        Text("Anyone can discover and bet in this group — no invite link needed.")
                            .font(.betty(12, .regular))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
                .tint(Palette.orange)
                .disabled(isWorking)
                .accessibilityIdentifier("groupSettings.visibility.toggle")
                .onChange(of: publicToggle) { _, newValue in
                    guard newValue != (group?.isPublic ?? false) else { return }
                    Task { await setVisibility(newValue) }
                }
            }
        }
    }

    // MARK: invite

    private func inviteCard(_ group: Group) -> some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("INVITE LINK")
                    .kicker(theme.colors.textSecondary)
                if let inviteLink = group.inviteLink {
                    InviteLinkRow(link: inviteLink)
                }
                if isAuthor {
                    Button("ROTATE CODE") {
                        confirmRotateCode()
                    }
                    .buttonStyle(.bettyOutline)
                    .disabled(isWorking)
                    .accessibilityIdentifier("groupSettings.invite.rotateButton")
                }
            }
        }
    }

    // MARK: members

    private func membersCard(_ group: Group) -> some View {
        let members = group.members.sorted { $0.score > $1.score }
        return BettyCard {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("\(members.count) \(members.count == 1 ? "MEMBER" : "MEMBERS")")
                    .kicker(theme.colors.textSecondary)
                ForEach(members) { member in
                    memberRow(member, group: group)
                    if member.id != members.last?.id {
                        Divider().overlay(theme.colors.overlay04)
                    }
                }
            }
        }
    }

    private func memberRow(_ member: Member, group: Group) -> some View {
        HStack(spacing: Space.s) {
            AvatarView(member: member, size: .small)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.xs) {
                    Text(member.displayName)
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                    if member.userID == env.userStore.id {
                        YouBadge()
                    }
                }
                if member.isAuthor {
                    Text("AUTHOR")
                        .kicker(theme.colors.textMuted)
                }
            }
            Spacer()
            Text("\(member.score) P")
                .font(.bettySubhead)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
            if isAuthor, !member.isAuthor, member.userID != env.userStore.id {
                Menu {
                    Button("Block member", role: .destructive) {
                        confirmBlock(member, group: group)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary)
                        .padding(Space.xs)
                }
                .accessibilityIdentifier("groupSettings.members.menu.\(member.userID)")
            }
        }
    }

    // MARK: leave

    private func leaveCard(_ group: Group) -> some View {
        Button("LEAVE GROUP") {
            env.toasts.confirm(question: "Are you sure you want to leave \(group.name)?") {
                await leave()
            }
        }
        .buttonStyle(BettyButtonStyle(variant: .destructive, isBlock: true))
        .disabled(isWorking)
        .accessibilityIdentifier("groupSettings.leaveButton")
    }

    private var missingGroup: some View {
        VStack(spacing: Space.m) {
            Text("★ GROUP SETTINGS")
                .kicker(Palette.orange)
            Text("This group is no longer available.")
                .font(.betty(15, .regular))
                .foregroundStyle(theme.colors.textSecondary)
            Button("CLOSE") {
                dismiss()
            }
            .buttonStyle(.bettyOutline)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// Save = web `GroupSettingsModal.save`: 401/403 → "Only the group author can edit
    /// these settings." (sheet stays open); other failures → error alert, sheet stays
    /// open; success closes.
    private func save() {
        guard let update = form?.update else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                _ = try await env.groupStore.updateSettings(id: groupID, update)
                dismiss()
            } catch let error as APIError where error.status == 401 || error.status == 403 {
                env.toasts.alert(
                    title: "Not allowed",
                    message: "Only the group author can edit these settings.",
                    state: .warning
                )
            } catch {
                env.toasts.alert(
                    title: "Could not save settings",
                    message: "Something went wrong while saving. Please try again.",
                    state: .error
                )
            }
        }
    }

    private func setVisibility(_ isPublic: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await env.groupStore.setVisibility(id: groupID, isPublic: isPublic)
        } catch let error as APIError where error.status == 401 || error.status == 403 {
            publicToggle = group?.isPublic ?? false
            env.toasts.alert(
                title: "Not allowed",
                message: "Only the group author can change visibility.",
                state: .warning
            )
        } catch {
            publicToggle = group?.isPublic ?? false
            env.toasts.alert(
                title: "Could not update visibility",
                message: "Something went wrong. Please try again.",
                state: .error
            )
        }
    }

    private func confirmRotateCode() {
        env.toasts.confirm(question: "Rotate the invite code? The old link will stop working.") {
            await rotateCode()
        }
    }

    private func rotateCode() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await env.groupStore.rotateInviteCode(id: groupID)
            env.toasts.alert(message: "New invite code is live.", state: .success)
        } catch let error as APIError where error.status == 401 || error.status == 403 {
            env.toasts.alert(
                title: "Not allowed",
                message: "Only the group author can change the invite code.",
                state: .warning
            )
        } catch {
            env.toasts.alert(
                title: "Could not rotate code",
                message: "Something went wrong. Please try again.",
                state: .error
            )
        }
    }

    private func confirmBlock(_ member: Member, group: Group) {
        let name = member.displayName.isEmpty ? "this member" : member.displayName
        env.toasts.confirm(question: "Block \(name) from \(group.name)? They will be removed and can't rejoin.") {
            await block(member, name: name)
        }
    }

    private func block(_ member: Member, name: String) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await env.groupStore.blockMember(groupID: groupID, userID: member.userID)
            env.toasts.alert(message: "\(name) has been blocked.", state: .success)
        } catch let error as APIError where error.status == 401 || error.status == 403 {
            env.toasts.alert(
                title: "Not allowed",
                message: "Only the group author can block members.",
                state: .warning
            )
        } catch {
            env.toasts.alert(
                title: "Could not block member",
                message: "Something went wrong. Please try again.",
                state: .error
            )
        }
    }

    private func leave() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await env.groupStore.leave(id: groupID)
            dismiss()
            env.router.homePath = []
        } catch {
            env.toasts.alert(
                title: "Could not leave group",
                message: "Something went wrong. Please try again.",
                state: .error
            )
        }
    }
}
