import SwiftUI

/// Team logo (web `TeamLogo`). `Team.imageURL` is a scheme string `"<type>:<key>"`:
/// - `flag:se` → bundled asset `flag/se` (all of `public/flags/` is rasterized into the
///   asset catalog — the web host serves only SVG, which is not fetchable natively),
/// - `pl:arsenal` → bundled asset `pl/arsenal`, falling back to remote
///   `https://betty.social/pl/arsenal.png` for keys missing from the bundle,
/// - any other type, missing image, or missing team → neutral circle.
///
/// Circular with a 2pt `overlay08` ring on an `overlay06` fill. Sizes by context:
/// 56 game cards, 28 bet rows, 19 feed items.
struct TeamLogoView: View {
    var team: Team?
    var size: CGFloat = 56

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ZStack {
            Circle().fill(theme.colors.overlay06)
            content
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(theme.colors.overlay08, lineWidth: 2)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let asset = bundledAssetName, UIImage(named: asset) != nil {
            Image(asset).resizable().scaledToFill()
        } else if let url = remoteURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackInitial
                }
            }
        } else {
            fallbackInitial
        }
    }

    private var fallbackInitial: some View {
        Text(team.map { String($0.name.prefix(1)).uppercased() } ?? "")
            .font(.system(size: size * 0.4, weight: .heavy))
            .foregroundStyle(theme.colors.textMuted)
    }

    private var parsedScheme: (type: String, key: String)? {
        guard let raw = team?.imageURL, let colon = raw.firstIndex(of: ":") else { return nil }
        let type = String(raw[..<colon])
        let key = String(raw[raw.index(after: colon)...])
        guard !type.isEmpty, !key.isEmpty else { return nil }
        return (type, key)
    }

    /// Prefer bundled art (offline-safe) keyed `<type>/<key>` in the asset catalog.
    private var bundledAssetName: String? {
        parsedScheme.map { "\($0.type)/\($0.key)" }
    }

    /// Only `pl:` keys resolve to a fetchable raster on the web host.
    private var remoteURL: URL? {
        guard let scheme = parsedScheme, scheme.type == "pl" else { return nil }
        return URL(string: "https://betty.social/pl/\(scheme.key).png")
    }
}
