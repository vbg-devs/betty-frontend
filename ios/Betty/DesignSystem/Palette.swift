import SwiftUI

nonisolated extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Theme-independent brand constants — these never change between light and dark.
nonisolated enum Palette {
    /// Primary CTA, active tab underline, live badge, "YOU" badge, urgent borders.
    static let orange = Color(hex: 0xFF5A3A)
    /// 2nd-place accent, semi-correct points, "ended" badge background.
    static let yellow = Color(hex: 0xFFD84A)
    /// Near-black; text on yellow/green badges, dark button bg.
    static let ink = Color(hex: 0x0D0E15)
    /// Brand indigo; light-theme logo tint + light-theme positive accent.
    static let indigo = Color(hex: 0x434F8E)
    /// Legacy action buttons only — avoid in new UI.
    static let legacyGreen = Color(hex: 0x78CC14)
    /// Destructive buttons, unread dot.
    static let alertRed = Color(hex: 0xF44336)
    /// Destructive menu items on white surfaces.
    static let dropdownDanger = Color(hex: 0xD8412F)

    // Fixed-alpha tints (identical in both themes)
    static let orangeTint12 = Color(hex: 0xFF5A3A, alpha: 0.12) // "you" row bg
    static let orangeTint15 = Color(hex: 0xFF5A3A, alpha: 0.15) // score chip / checked checkbox bg
    static let orangeTint18 = Color(hex: 0xFF5A3A, alpha: 0.18) // "you" row pressed / active toggle bg
    static let modalBackdrop = Color(.sRGB, red: 10 / 255, green: 14 / 255, blue: 35 / 255, opacity: 0.82)
    static let pillDark = Color(.sRGB, red: 20 / 255, green: 25 / 255, blue: 56 / 255, opacity: 0.78)
    static let surfaceWhite = Color.white

    /// White-surface menu constants — identical in both themes (web hardcodes them).
    enum Menu {
        static let title = Color(hex: 0x1F2752)
        static let secondary = Color(hex: 0x6B7090)
        static let hairline = Color(hex: 0xEEF0F5)
        static let hover = Color(hex: 0xF4F5FA)
        static let danger = Color(hex: 0xD8412F)
        static let dangerHover = Color(hex: 0xFDF0EE)
    }
}
