import SwiftUI

/// Kicker-labelled form field wrapper (web `.field` / `.field__label`).
struct GroupFormField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label)
                .kicker(theme.colors.textSecondary)
            content
        }
    }
}

/// Betty text input — overlay06 background, sharp corners (web `.field__input`).
struct GroupFormTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineRange: ClosedRange<Int> = 1...1
    var keyboard: UIKeyboardType = .default

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .lineLimit(lineRange.lowerBound...lineRange.upperBound)
            .keyboardType(keyboard)
            .font(.betty(15, .semibold))
            .padding(Space.s)
            .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sharp)
                    .strokeBorder(theme.colors.overlay10, lineWidth: 1)
            }
            .foregroundStyle(theme.colors.textPrimary)
    }
}

/// Keyboard accessory with a trailing DONE — the points fields use a number pad,
/// which has no return key, so without this the only way to drop the keyboard is an
/// interactive scroll drag.
struct KeyboardDoneBar: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                )
            }
            .accessibilityIdentifier("keyboard.done")
        }
    }
}

/// `N / 1000` live counter under the description field; highlights at the limit.
struct GroupDescriptionCounter: View {
    let count: Int
    var limit: Int = CreateGroupForm.maxDescriptionLength

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Text("\(count) / \(limit)")
            .font(.bettyMicro)
            .kerning(1.4)
            .monospacedDigit()
            .foregroundStyle(count >= limit ? Palette.orange : theme.colors.textMuted)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Checkbox card with title + sub copy (web `.check`); rendered as a native Toggle.
struct GroupFormCheckRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.betty(13, .bold))
                    .foregroundStyle(theme.colors.textPrimary)
                Text(subtitle)
                    .font(.betty(12, .regular))
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .tint(Palette.orange)
        .padding(Space.s)
        .background(theme.colors.overlay04, in: RoundedRectangle(cornerRadius: Radius.sharp))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sharp)
                .strokeBorder(theme.colors.overlay08, lineWidth: 1)
        }
    }
}

/// Invite-link row — truncated link text, COPY button that flips to `COPIED ✓`
/// for 1.5 s, and a native share button (web copies to clipboard only).
struct InviteLinkRow: View {
    let link: URL

    @Environment(ThemeStore.self) private var theme
    @State private var copied = false

    var body: some View {
        HStack(spacing: 0) {
            Text(link.absoluteString)
                .font(.betty(12, .semibold))
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("groupMgmt.inviteLink.text")

            Button {
                UIPasteboard.general.url = link
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                Text(copied ? "COPIED ✓" : "COPY →")
                    .font(.bettyKicker)
                    .kerning(1.4)
                    .foregroundStyle(.white)
                    .padding(.vertical, Space.s)
                    .padding(.horizontal, Space.m)
                    .background(Palette.orange)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("groupMgmt.inviteLink.copyButton")

            ShareLink(item: link) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, Space.s)
                    .padding(.horizontal, Space.s)
                    .background(Palette.ink)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("groupMgmt.inviteLink.shareButton")
        }
        .frame(minHeight: 44)
        .background(theme.colors.overlay06)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
    }
}
