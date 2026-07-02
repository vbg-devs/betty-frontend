import SwiftUI

/// Orange bg / white text micro badge for the current user's rows.
struct YouBadge: View {
    var body: some View {
        Text("YOU")
            .font(.bettyMicro)
            .kerning(1.4)
            .foregroundStyle(.white)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(Palette.orange, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }
}

/// Pulsing orange blob + "LIVE" — the 150-minute kickoff window indicator.
struct LiveBadge: View {
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Palette.orange)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .stroke(Palette.orange.opacity(pulsing ? 0 : 0.7), lineWidth: 2)
                        .scaleEffect(pulsing ? 2.2 : 1)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                        pulsing = true
                    }
                }
            Text("LIVE")
                .font(.bettyKicker)
                .kerning(1.4)
                .foregroundStyle(Palette.orange)
        }
    }
}

/// Neutral full-time tag — match over per the feed, before Betty settles.
struct FTBadge: View {
    @Environment(ThemeStore.self) private var theme
    var body: some View {
        Text("FT")
            .font(.bettyKicker)
            .kerning(1.4)
            .foregroundStyle(theme.colors.textMuted)
    }
}

/// Yellow bg / ink text — finished groups ("ENDED" / "JUST ENDED").
struct EndedBadge: View {
    var text: String = "ENDED"

    var body: some View {
        Text(text)
            .font(.bettyKicker)
            .kerning(1.4)
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Palette.yellow, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }
}

/// Dark translucent pill over images — "PUBLIC" with a green dot.
struct PublicBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: 0x9BFF3D))
                .frame(width: 6, height: 6)
            Text("PUBLIC")
                .font(.bettyKicker)
                .kerning(1.4)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Palette.pillDark, in: RoundedRectangle(cornerRadius: Radius.sharp))
    }
}

/// Capsule count pill (tab counts) — `active` flips to the orange tint.
struct CountPill: View {
    var count: Int
    var isActive: Bool = false

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Text("\(count)")
            .font(.bettyMicro)
            .kerning(1.2)
            .foregroundStyle(isActive ? Palette.orange : theme.colors.textSecondary)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(isActive ? Palette.orangeTint18 : theme.colors.overlay08, in: Capsule())
    }
}
