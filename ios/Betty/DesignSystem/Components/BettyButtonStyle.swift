import SwiftUI

/// Betty button recipes — all on `Radius.sharp` (2pt) corners.
/// Disabled: opacity 0.4. Pressed: scale 0.98 + brightness +5%.
struct BettyButtonStyle: ButtonStyle {
    enum Variant {
        /// Orange bg / white heavy uppercase label — the main CTA.
        case primary
        /// Transparent with a 1pt textPrimary@25% border.
        case outline
        /// Bare text button.
        case ghost
        /// Ink background, cream label.
        case dark
        /// Alert red — destructive actions.
        case destructive
    }

    var variant: Variant = .primary
    /// Stretch to full width (block CTA).
    var isBlock: Bool = false

    @Environment(ThemeStore.self) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let colors = theme.colors
        return configuration.label
            .font(.betty(labelSize, labelWeight))
            .kerning(kerning)
            .textCase(.uppercase)
            .foregroundStyle(foreground(colors))
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: isBlock ? .infinity : nil)
            .background(background(colors), in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay {
                if variant == .outline {
                    RoundedRectangle(cornerRadius: Radius.sharp)
                        .strokeBorder(colors.textPrimary.opacity(configuration.isPressed ? 0.5 : 0.25), lineWidth: 1)
                }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var labelSize: CGFloat {
        switch variant {
        case .primary, .destructive: 14
        case .outline, .ghost: 14
        case .dark: 17
        }
    }

    private var labelWeight: Font.Weight {
        switch variant {
        case .primary, .dark, .destructive: .heavy
        case .outline: .bold
        case .ghost: .semibold
        }
    }

    private var kerning: CGFloat {
        switch variant {
        case .primary, .destructive: 1.2
        case .outline: 0.5
        case .ghost: 0
        case .dark: 1.0
        }
    }

    private var verticalPadding: CGFloat {
        switch variant {
        case .ghost: 10
        default: 17
        }
    }

    private var horizontalPadding: CGFloat {
        switch variant {
        case .ghost: 16
        case .outline: 24
        case .dark: 32
        default: 22
        }
    }

    private func background(_ colors: ThemeColors) -> Color {
        switch variant {
        case .primary: Palette.orange
        case .outline, .ghost: .clear
        case .dark: Palette.ink
        case .destructive: Palette.alertRed
        }
    }

    private func foreground(_ colors: ThemeColors) -> Color {
        switch variant {
        case .primary, .destructive: .white
        case .outline, .ghost: colors.textPrimary
        case .dark: ThemeColors.dark.textPrimary
        }
    }
}

extension ButtonStyle where Self == BettyButtonStyle {
    static var bettyPrimary: BettyButtonStyle { BettyButtonStyle(variant: .primary) }
    static var bettyPrimaryBlock: BettyButtonStyle { BettyButtonStyle(variant: .primary, isBlock: true) }
    static var bettyOutline: BettyButtonStyle { BettyButtonStyle(variant: .outline) }
    static var bettyGhost: BettyButtonStyle { BettyButtonStyle(variant: .ghost) }
    static var bettyDark: BettyButtonStyle { BettyButtonStyle(variant: .dark) }
    static var bettyDestructive: BettyButtonStyle { BettyButtonStyle(variant: .destructive) }
}
