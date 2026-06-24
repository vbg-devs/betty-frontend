import SwiftUI

/// Single green fill bar (completion %). 6pt track on `overlay10`.
struct ProgressBarView: View {
    /// Percent 0–100.
    var progress: Double = 0

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.colors.overlay10)
                Capsule()
                    .fill(theme.colors.accentPositive)
                    .frame(width: max(0, min(progress, 100)) / 100 * proxy.size.width)
            }
        }
        .frame(height: 6)
    }
}

/// Home/tie/away bet-distribution bar. Inputs are percents that the caller guarantees
/// sum to 100 (see `LargestRemainder.percentages`). Each segment keeps a 1pt minimum
/// width so 0% still shows a sliver. Left (home) green, center (tie) white@35%,
/// right (away) yellow.
struct SplitProgressBarView: View {
    var leftProgress: Double = 0
    var tieProgress: Double = 0
    var rightProgress: Double = 0

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                segment(theme.colors.accentPositive, percent: leftProgress, totalWidth: proxy.size.width)
                segment(Color.white.opacity(0.35), percent: tieProgress, totalWidth: proxy.size.width)
                segment(Palette.yellow, percent: rightProgress, totalWidth: proxy.size.width)
            }
        }
        .frame(height: 6)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private func segment(_ color: Color, percent: Double, totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(1, max(0, min(percent, 100)) / 100 * totalWidth))
    }
}
