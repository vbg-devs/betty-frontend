import PhotosUI
import SwiftUI

/// Web `MemeBoard` + `ActivityFeed` — group chat (text / GIF / photo messages with
/// emoji reactions, 10 s polling) plus the live activity ticker as a second segment.
struct GroupChatView: View {
    let groupID: Int

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    private enum ChatSection: String, CaseIterable, Identifiable {
        case chat = "CHAT"
        case activity = "ACTIVITY"

        var id: String { rawValue }
    }

    @State private var store: MessageBoardStore?
    @State private var section: ChatSection = .chat
    @State private var draft = ""
    @State private var useGiphy = false
    @State private var isPosting = false
    @State private var isSearching = false
    @State private var isUploadingPhoto = false
    @State private var gifResults: [GiphyImage] = []
    @State private var gifIndex = 0
    @State private var pickerOpenFor: Int?
    @State private var deletingID: Int?
    @State private var photoItem: PhotosPickerItem?

    private let giphy = GiphyClient()

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                sectionPicker
                switch section {
                case .chat: chatSection
                case .activity: activitySection
                }
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: groupID) { await startChat() }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            photoItem = nil
            sendPhoto(newItem)
        }
    }

    // MARK: - Lifecycle

    private func startChat() async {
        let board: MessageBoardStore
        if let store, store.groupID == groupID {
            board = store
        } else {
            board = MessageBoardStore(api: env.api, groupID: groupID)
            store = board
        }
        // Members back author names/avatars; load lazily for deep links.
        if env.groupStore.byID(groupID) == nil {
            try? await env.groupStore.load()
        }
        try? await board.load()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            try? await board.load() // a failed poll keeps the last good list
        }
    }

    // MARK: - Sections

    private var sectionPicker: some View {
        Picker("Section", selection: $section) {
            ForEach(ChatSection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.xs)
        .accessibilityIdentifier("chat.screen.sectionPicker")
    }

    private var chatSection: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s) {
                    chatHeader
                    gifSelector
                    if let store, store.isLoaded, store.messages.isEmpty {
                        Text("No messages yet. Say something!")
                            .font(.bettyBody)
                            .foregroundStyle(theme.colors.textMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Space.xl)
                            .accessibilityIdentifier("chat.board.empty")
                    }
                    // Store is newest-first; reverse so the newest sits at the bottom.
                    ForEach(displayMessages) { message in
                        ChatMessageRow(
                            message: message,
                            member: members?.first { $0.userID == message.userID },
                            currentUserID: env.userStore.id,
                            isDeleting: deletingID == message.id,
                            isPickerOpen: pickerOpenFor == message.id,
                            onTogglePicker: { togglePicker(for: message.id) },
                            onToggleReaction: { emoji in toggleReaction(message: message, emoji: emoji) },
                            onDelete: { confirmDelete(message) }
                        )
                    }
                }
                .padding(Space.m)
                .contentShape(Rectangle())
                .onTapGesture { pickerOpenFor = nil }
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            composer
        }
    }

    private var displayMessages: [GroupMessage] {
        Array((store?.messages ?? []).reversed())
    }

    private var members: [Member]? {
        env.groupStore.byID(groupID)?.members
    }

    private var chatHeader: some View {
        HStack {
            Text("★ GROUP CHAT")
                .kicker(Palette.orange)
            Spacer()
            if let count = store?.messages.count, count > 0 {
                Text("\(count) MESSAGES")
                    .kicker(theme.colors.textMuted)
                    .accessibilityIdentifier("chat.board.count")
            }
        }
    }

    private var activitySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xs) {
                if env.activityFeed.entries.isEmpty {
                    ScreenPlaceholder(
                        kickerText: "ACTIVITY",
                        title: "ALL QUIET.",
                        note: "Live events from everyone on Betty appear here as they happen."
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                } else {
                    HStack {
                        Text("★ ACTIVITY")
                            .kicker(Palette.orange)
                        Spacer()
                        Button("CLEAR ALL") {
                            env.activityFeed.clearAll()
                        }
                        .buttonStyle(.bettyGhost)
                        .accessibilityIdentifier("chat.activity.clearAll")
                    }
                    ForEach(env.activityFeed.entries) { entry in
                        ActivityEventRow(event: entry.event)
                    }
                }
            }
            .padding(Space.m)
        }
    }

    // MARK: - GIF selector

    @ViewBuilder
    private var gifSelector: some View {
        if !gifResults.isEmpty {
            let safeIndex = min(gifIndex, gifResults.count - 1)
            BettyCard(padding: Space.m) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("SELECT GIF")
                        .kicker(theme.colors.textMuted)
                        .accessibilityIdentifier("chat.gifSelector.title")
                    AsyncImage(url: URL(string: gifResults[safeIndex].originalURL)) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        } else {
                            theme.colors.overlay06
                        }
                    }
                    .id(gifResults[safeIndex].id)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
                    .accessibilityElement(children: .ignore)
                    // The selected GIF's id, exposed so UI tests can pin prev/next/clamp.
                    .accessibilityValue(gifResults[safeIndex].id)
                    .accessibilityIdentifier("chat.gifSelector.preview")
                    HStack(spacing: Space.xs) {
                        Button("PREV") { gifIndex = max(0, safeIndex - 1) }
                            .buttonStyle(.bettyOutline)
                            .disabled(safeIndex == 0)
                            .accessibilityIdentifier("chat.gifSelector.prev")
                        Button("NEXT") { gifIndex = min(gifResults.count - 1, safeIndex + 1) }
                            .buttonStyle(.bettyOutline)
                            .disabled(safeIndex == gifResults.count - 1)
                            .accessibilityIdentifier("chat.gifSelector.next")
                        Spacer()
                        Button("SUBMIT") { sendSelectedGif() }
                            .buttonStyle(.bettyPrimary)
                            .disabled(isPosting)
                            .accessibilityIdentifier("chat.gifSelector.submit")
                        Button("CANCEL") { resetGifSelector() }
                            .buttonStyle(.bettyGhost)
                            .accessibilityIdentifier("chat.gifSelector.cancel")
                    }
                }
            }
        }
    }

    private func resetGifSelector() {
        gifResults = []
        gifIndex = 0
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Divider().overlay(theme.colors.overlay06)
            HStack(spacing: Space.s) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    SwiftUI.Group {
                        if isUploadingPhoto {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(theme.colors.textMuted)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .disabled(isUploadingPhoto)
                .accessibilityLabel("Send a photo")
                .accessibilityIdentifier("chat.composer.photo")

                TextField(useGiphy ? "Search Giphy…" : "Send message to group", text: $draft)
                    .textFieldStyle(.plain)
                    .padding(Space.s)
                    .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
                    .foregroundStyle(theme.colors.textPrimary)
                    .submitLabel(useGiphy ? .search : .send)
                    .onSubmit(submit)
                    .accessibilityIdentifier("chat.composer.field")

                Button {
                    useGiphy.toggle()
                } label: {
                    Text("GIF")
                        .font(.bettyMicro)
                        .foregroundStyle(useGiphy ? Palette.orange : theme.colors.textMuted)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 6)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.sharp)
                                .strokeBorder(useGiphy ? Palette.orange : theme.colors.overlay10)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle GIF mode")
                .accessibilityIdentifier("chat.composer.gifToggle")

                if isSearching || isPosting {
                    ProgressView()
                } else {
                    Button(useGiphy ? "SEARCH" : "SEND", action: submit)
                        .buttonStyle(.bettyPrimary)
                        .disabled(draft.isEmpty)
                        .accessibilityIdentifier("chat.composer.submit")
                }
            }
            .padding(Space.m)
        }
        .background(theme.colors.surfaceDeep)
    }

    private func submit() {
        guard !draft.isEmpty else { return }
        if useGiphy {
            searchGifs()
        } else {
            sendText()
        }
    }

    private func sendText() {
        guard let store, !isPosting else { return }
        isPosting = true
        let text = draft
        Task {
            defer { isPosting = false }
            do {
                try await store.post(body: text)
                draft = ""
                resetGifSelector()
            } catch {
                // Keep the typed text so the user can retry (web parity: log only).
            }
        }
    }

    private func searchGifs() {
        guard !isSearching else { return }
        isSearching = true
        let query = draft
        Task {
            defer { isSearching = false }
            do {
                let results = try await giphy.search(query, limit: 10)
                if !results.isEmpty {
                    gifResults = results
                    gifIndex = 0
                }
                draft = "" // cleared on success even with zero hits (web parity)
            } catch {
                // Keep the query so retry works (web parity).
            }
        }
    }

    private func sendSelectedGif() {
        guard let store, !gifResults.isEmpty, !isPosting else { return }
        let url = gifResults[min(gifIndex, gifResults.count - 1)].originalURL
        isPosting = true
        Task {
            defer { isPosting = false }
            do {
                try await store.post(body: nil, imageURL: url)
                resetGifSelector()
            } catch {
                // Selector stays open so the user can retry (web parity).
            }
        }
    }

    // No message-image presign exists; the profile-image presign is reused WITHOUT the
    // profile commit step — the public URL only ever lands in this chat message.
    private func sendPhoto(_ item: PhotosPickerItem) {
        guard let store, !isUploadingPhoto else { return }
        isUploadingPhoto = true
        Task {
            defer { isUploadingPhoto = false }
            let raw: Data?
            do {
                raw = try await item.loadTransferable(type: Data.self)
            } catch {
                raw = nil
            }
            guard let raw, let prepared = await ChatPhotoPreparer.prepare(raw) else {
                env.toasts.alert(
                    title: "Could not send image",
                    message: "Use a JPEG, PNG, WebP or GIF under 1 MB.",
                    state: .warning
                )
                return
            }
            do {
                let presign = try await env.api.profileImageUploadURL(
                    contentType: prepared.contentType,
                    contentLength: prepared.data.count
                )
                try await env.api.upload(prepared.data, with: presign, contentType: prepared.contentType)
                try await store.post(body: nil, imageURL: presign.publicURL)
            } catch let error as APIError {
                env.toasts.alert(title: "Could not send image", message: uploadErrorMessage(error), state: .error)
            } catch {
                env.toasts.alert(title: "Could not send image", message: "Please try again.", state: .error)
            }
        }
    }

    private func uploadErrorMessage(_ error: APIError) -> String {
        switch error {
        case .payloadTooLarge: "Image is too large (max 1 MB)."
        case .unsupportedMediaType: "That image type isn't supported."
        case .serviceUnavailable: "Uploads are temporarily unavailable. Try again soon."
        default: "Please try again."
        }
    }

    // MARK: - Reactions

    private func togglePicker(for messageID: Int) {
        pickerOpenFor = pickerOpenFor == messageID ? nil : messageID
    }

    private func toggleReaction(message: GroupMessage, emoji: String) {
        pickerOpenFor = nil
        guard let store, let userID = env.userStore.id else { return } // logged out = no-op
        guard let action = ReactionLogic.toggleAction(for: emoji, in: message.reactions, currentUserID: userID) else {
            return
        }
        Task {
            do {
                switch action {
                case .remove:
                    try await store.removeReaction(messageID: message.id, userID: userID)
                case .set(let emojiID):
                    try await store.setReaction(messageID: message.id, emojiID: emojiID, userID: userID)
                }
            } catch {
                // The store already rolled the optimistic change back (web parity: log only).
            }
        }
    }

    // MARK: - Delete

    private func confirmDelete(_ message: GroupMessage) {
        guard message.userID == env.userStore.id, deletingID != message.id else { return }
        env.toasts.confirm(
            title: "Delete message",
            question: "Delete this message? This cannot be undone."
        ) {
            await performDelete(message.id)
        }
    }

    private func performDelete(_ messageID: Int) async {
        guard deletingID != messageID, let store else { return }
        deletingID = messageID
        defer { deletingID = nil }
        do {
            // 404 = already gone: the store drops it locally with no error.
            try await store.delete(messageID: messageID)
        } catch {
            env.toasts.alert(
                title: "Could not delete message",
                message: String(describing: error),
                state: .error
            )
        }
    }
}
