import SwiftUI

/// Concealed pre-kickoff bet score: eye-off, dash, eye-off.
struct HiddenScoreView: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.slash")
            Text("-")
            Image(systemName: "eye.slash")
        }
        .font(.bettySubhead)
        .foregroundStyle(theme.colors.textMuted)
    }
}
