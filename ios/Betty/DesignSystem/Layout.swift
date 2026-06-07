import SwiftUI

/// Spacing scale (pt) — loose 2/4-pt rhythm from the web.
nonisolated enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    /// Card body padding, row gaps.
    static let s: CGFloat = 12
    /// Game tile padding, screen edge inset.
    static let m: CGFloat = 16
    /// Leaderboard row h-padding, card body.
    static let l: CGFloat = 22
    /// Modal h-padding.
    static let xl: CGFloat = 28
    /// Hero padding, section spacing.
    static let xxl: CGFloat = 40
    static let huge: CGFloat = 56
    /// Grid gap between cards.
    static let cardGap: CGFloat = 20
}

/// Corner radii. `sharp` (2pt) is THE Betty radius — near-square corners are a core
/// identity trait; do not "iOS-ify" to 10–16.
nonisolated enum Radius {
    static let sharp: CGFloat = 2
    /// Legacy white Card only.
    static let legacy: CGFloat = 5
}

/// Shadow recipes (dark-on-dark shadows read subtly — the 1pt overlay06 ring on
/// modals/inputs matters more than the shadow itself).
extension View {
    func shadowCard() -> some View {
        shadow(color: .black.opacity(0.3), radius: 5, y: 5)
    }

    /// Pressed/featured cards.
    func shadowLift() -> some View {
        shadow(color: Color(hex: 0x141938).opacity(0.55), radius: 14, y: 12)
    }

    func shadowMenu() -> some View {
        shadow(color: Color(hex: 0x141938).opacity(0.18), radius: 12, y: 8)
    }

    func shadowModal() -> some View {
        shadow(color: .black.opacity(0.6), radius: 30, y: 24)
    }
}
