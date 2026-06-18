import SwiftUI
import UIKit

/// One meme-board message: avatar, author + relative timestamp, body text OR image,
/// reaction chips with an inline picker, delete for own messages.
struct ChatMessageRow: View {
    let message: GroupMessage
    let member: Member?
    let currentUserID: String?
    let isDeleting: Bool
    let isPickerOpen: Bool
    let onTogglePicker: () -> Void
    let onToggleReaction: (String) -> Void
    let onDelete: () -> Void

    @Environment(ThemeStore.self) private var theme

    private var isMine: Bool {
        currentUserID != nil && message.userID == currentUserID
    }

    var body: some View {
        BettyInsetPanel(accent: Palette.orange, padding: Space.m) {
            HStack(alignment: .top, spacing: Space.s) {
                AvatarView(
                    name: member?.name,
                    nickname: member?.nickname,
                    imageURL: member?.imageURL,
                    size: .small
                )
                .accessibilityIdentifier("chat.board.message.\(message.id).avatar")
                VStack(alignment: .leading, spacing: Space.xxs) {
                    header
                    content
                    reactions
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contextMenu {
            if let body = message.body, !body.isEmpty {
                Button {
                    UIPasteboard.general.string = body
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            if isMine {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete message", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.board.message.\(message.id)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text(ChatDisplay.authorName(member))
                .font(.betty(13, .heavy))
                .foregroundStyle(theme.colors.textPrimary)
                .accessibilityIdentifier("chat.board.message.\(message.id).author")
            Text(ChatRelativeTime.string(from: message.createdAt))
                .font(.betty(12, .semibold))
                .foregroundStyle(theme.colors.textMuted)
                .accessibilityIdentifier("chat.board.message.\(message.id).timestamp")
            Spacer(minLength: 0)
            if isMine {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.colors.textMuted)
                        // Outset to a ~44pt hit area without inflating the header row.
                        .contentShape(Rectangle().inset(by: -16))
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
                .opacity(isDeleting ? 0.45 : 1)
                .accessibilityLabel("Delete message")
                .accessibilityIdentifier("chat.board.message.\(message.id).delete")
            }
        }
    }

    // Web parity: an image message renders ONLY the image, otherwise the body text.
    @ViewBuilder
    private var content: some View {
        if let imageURL = message.imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
            AnimatedImageView(url: url)
                .frame(maxWidth: .infinity, maxHeight: 240, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
                .accessibilityIdentifier("chat.board.message.\(message.id).image")
        } else if let body = message.body {
            Text(body)
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("chat.board.message.\(message.id).body")
        }
    }

    private var reactions: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.xxs) {
                    ForEach(ReactionLogic.grouped(message.reactions, currentUserID: currentUserID)) { group in
                        reactionChip(group)
                    }
                    addReactionButton
                }
            }
            if isPickerOpen {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xxs) {
                        ForEach(MessageBoardStore.reactionPalette, id: \.self) { emoji in
                            Button {
                                onToggleReaction(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("chat.board.message.\(message.id).picker.\(emoji)")
                        }
                    }
                }
                .padding(Space.xxs)
                .background(theme.colors.surfaceDeep, in: RoundedRectangle(cornerRadius: Radius.legacy))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.legacy)
                        .strokeBorder(theme.colors.overlay10)
                }
            }
        }
        .padding(.top, Space.xxs)
    }

    private func reactionChip(_ group: ReactionGroup) -> some View {
        Button {
            onToggleReaction(group.emojiID)
        } label: {
            HStack(spacing: 4) {
                Text(group.emojiID).font(.system(size: 14))
                Text("\(group.count)")
                    .font(.betty(12, .bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, Space.xs)
            .padding(.vertical, 3)
            .background(group.reactedByMe ? Palette.orangeTint15 : theme.colors.overlay06, in: Capsule())
            .overlay {
                Capsule().strokeBorder(group.reactedByMe ? Palette.orange.opacity(0.5) : theme.colors.overlay08)
            }
            .foregroundStyle(group.reactedByMe ? Palette.orange : theme.colors.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.board.message.\(message.id).reaction.\(group.emojiID)")
    }

    private var addReactionButton: some View {
        Button(action: onTogglePicker) {
            Image(systemName: "face.smiling")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.colors.textMuted)
                .frame(width: 30, height: 24)
                .overlay {
                    Capsule().strokeBorder(theme.colors.overlay10, style: StrokeStyle(lineWidth: 1, dash: [3]))
                }
                // Outset to a >=44pt hit area without inflating the chip row.
                .contentShape(Rectangle().inset(by: -10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add reaction")
        .accessibilityIdentifier("chat.board.message.\(message.id).addReaction")
    }
}
