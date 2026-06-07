import SwiftUI

enum AvatarSize: CGFloat {
    case small = 32
    case regular = 42
    case medium = 64
    case large = 124

    var initialsFontSize: CGFloat {
        switch self {
        case .small: 14
        case .regular: 17
        case .medium: 26
        case .large: 54
        }
    }
}

/// User avatar (web `UserBadge`): remote image when `imageURL` is non-empty, otherwise
/// initials from `nickname ?? name`:
/// - nil/empty name → blank circle,
/// - single word → first character only, no case transform,
/// - two+ words → first char of first + first char of SECOND word, uppercased.
struct AvatarView: View {
    var name: String?
    var nickname: String?
    var imageURL: String?
    var size: AvatarSize = .regular

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ZStack {
            if let imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsCircle
                    }
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: size.rawValue, height: size.rawValue)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(theme.colors.overlay10, lineWidth: 5 * (size.rawValue / 124).clamped(to: 0.4...1))
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Palette.surfaceWhite)
            Text(Self.initials(from: nickname ?? name))
                .font(.system(size: size.initialsFontSize, weight: .semibold))
                .foregroundStyle(Color(hex: 0x333333))
        }
    }

    static func initials(from name: String?) -> String {
        guard let name, !name.isEmpty else { return "" }
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        if words.isEmpty { return "" }
        if words.count == 1 {
            return String(words[0].prefix(1)) // no case transform
        }
        return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
    }
}

extension AvatarView {
    init(member: Member, size: AvatarSize = .regular) {
        self.init(name: member.name, nickname: member.nickname, imageURL: member.imageURL, size: size)
    }

    init(profile: UserProfile, size: AvatarSize = .regular) {
        self.init(name: profile.name, nickname: nil, imageURL: profile.imageURL, size: size)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
