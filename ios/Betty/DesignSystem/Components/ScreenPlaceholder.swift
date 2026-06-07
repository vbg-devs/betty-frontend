import SwiftUI

/// Themed placeholder body for the feature-screen stubs — replace per screen spec.
struct ScreenPlaceholder: View {
    var kickerText: String
    var title: String
    var note: String?

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Space.m) {
                Text(kickerText)
                    .kicker(Palette.orange)
                Text(title)
                    .font(.bettyDisplayL)
                    .displayKerning(40)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.colors.textPrimary)
                if let note {
                    Text(note)
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textBody)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.m)
        }
    }
}
