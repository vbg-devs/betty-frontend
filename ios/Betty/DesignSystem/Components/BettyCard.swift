import SwiftUI

/// Surface card — `surface` background, 2pt corners, 22pt body padding.
struct BettyCard<Content: View>: View {
    var padding: CGFloat = Space.l
    @ViewBuilder var content: Content

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }
}

/// Inset panel — `surfaceDeep` background with the signature 3pt left accent bar.
struct BettyInsetPanel<Content: View>: View {
    var accent: Color?
    var padding: CGFloat = Space.m
    @ViewBuilder var content: Content

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surfaceDeep, in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent ?? theme.colors.accentPositive)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
            }
    }
}
