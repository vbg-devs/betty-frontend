import SwiftUI

/// Semantic, theme-adaptive colors. Dark indigo is the DEFAULT (matching web); light is
/// an explicit user toggle — never derive from the system appearance and never use
/// `Color(.systemBackground)`/`.primary` (Betty surfaces are branded, not system).
nonisolated struct ThemeColors: Sendable {
    /// Screen background + header bar.
    let background: Color
    /// Cards, modals, game tiles, leaderboard, hero card.
    let surface: Color
    /// Inset panels (countdown, banners, auth pitch).
    let surfaceDeep: Color
    /// Cream quote cards (rare).
    let surfaceSoft: Color
    /// Headings, scores, primary copy.
    let textPrimary: Color
    /// Sub-labels, ledes, secondary numerals.
    let textSecondary: Color
    /// Kickers at rest, dividers, placeholders.
    let textMuted: Color
    /// Long-form paragraph copy.
    let textBody: Color
    /// Winner score, bet-done border, success kickers.
    /// NOTE: the light theme remaps green to indigo — keep it.
    let accentPositive: Color
    /// Row hover/pressed tint.
    let overlay04: Color
    /// Input bg, hairline borders.
    let overlay06: Color
    /// Section rule lines, logo rings, count pills.
    let overlay08: Color
    /// Input borders, avatar rings, progress track.
    let overlay10: Color

    static let dark = ThemeColors(
        background: Palette.indigo,
        surface: Color(hex: 0x1F2752),
        surfaceDeep: Color(hex: 0x141938),
        surfaceSoft: Color(hex: 0xFFF5E4),
        textPrimary: Color(hex: 0xFFFAEB),
        textSecondary: Color(hex: 0xFFFAEB, alpha: 0.78),
        textMuted: Color(hex: 0xFFFAEB, alpha: 0.50),
        textBody: Color(hex: 0xCDD1E5),
        accentPositive: Color(hex: 0x9BFF3D),
        overlay04: Color.white.opacity(0.04),
        overlay06: Color.white.opacity(0.06),
        overlay08: Color.white.opacity(0.08),
        overlay10: Color.white.opacity(0.10)
    )

    static let light = ThemeColors(
        background: Color(hex: 0xFFFAEB),
        surface: .white,
        surfaceDeep: Color(hex: 0xF1EAD4),
        surfaceSoft: Color(hex: 0x1F2752),
        textPrimary: Color(hex: 0x141938),
        textSecondary: Color(hex: 0x141938, alpha: 0.82),
        textMuted: Color(hex: 0x141938, alpha: 0.55),
        textBody: Color(hex: 0x525874),
        accentPositive: Palette.indigo,
        overlay04: Color(hex: 0x141938, alpha: 0.04),
        overlay06: Color(hex: 0x141938, alpha: 0.06),
        overlay08: Color(hex: 0x141938, alpha: 0.08),
        overlay10: Color(hex: 0x141938, alpha: 0.10)
    )
}
