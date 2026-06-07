import SwiftUI

/// Single group card (web `.group-card`): 16:9 image header (custom header image with a
/// circular tournament icon overlay, else the tournament image), badges, tournament
/// kicker, group name, member count + state, your placement, CTA. Pushes GroupDetail.
struct HomeGroupCardView: View {
    let item: HomeGroupItem

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        NavigationLink(value: Destination.groupDetail(groupID: item.id)) {
            VStack(alignment: .leading, spacing: 0) {
                imageHeader
                cardBody
            }
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.groups.card.\(item.id)")
    }

    private var imageURLString: String? {
        if let header = item.headerImageURL { return header }
        if let joined = item.tournament?.imageURL, !joined.isEmpty { return joined }
        if let fromPlacement = item.placement.tournamentImageURL, !fromPlacement.isEmpty {
            return fromPlacement
        }
        return nil
    }

    private var imageHeader: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .background {
                ZStack {
                    theme.colors.surfaceDeep
                    if let urlString = imageURLString, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            }
                        }
                    }
                }
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                HStack(spacing: Space.xs) {
                    if item.headerImageURL != nil {
                        tournamentIconOverlay
                    }
                    if item.recentlyEnded {
                        EndedBadge(text: "● JUST ENDED")
                    }
                }
                .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                if item.isPublic {
                    PublicBadge()
                        .padding(10)
                }
            }
    }

    @ViewBuilder
    private var tournamentIconOverlay: some View {
        let icon = item.tournament?.imageURL ?? item.placement.tournamentImageURL
        if let icon, !icon.isEmpty, let url = URL(string: icon) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                }
            }
            .frame(width: 44, height: 44)
            .background(.white)
            .clipShape(Circle())
            .shadowCard()
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("★ \(kickerText)")
                .kicker(Palette.orange)
            Text(item.placement.name)
                .font(.bettyTitle2)
                .displayKerning(28)
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.leading)
            HStack(spacing: Space.xs) {
                Text("\(item.placement.memberCount) MEMBERS")
                    .kicker(theme.colors.textMuted)
                Text("·")
                    .foregroundStyle(theme.colors.textMuted)
                Text(item.ended ? "○ ENDED" : "● ACTIVE")
                    .kicker(item.ended ? theme.colors.textMuted : theme.colors.accentPositive)
            }
            placementRow
            Text(item.ended ? "SEE RESULTS →" : "OPEN GROUP →")
                .kicker(Palette.orange)
                .padding(.top, Space.xs)
        }
        .padding(Space.l)
    }

    private var kickerText: String {
        if let joined = item.tournament { return joined.name }
        let name = item.placement.tournamentName
        return name.isEmpty ? "TOURNAMENT" : name
    }

    private var placementRow: some View {
        HStack(spacing: Space.xs) {
            Text("YOUR PLACE")
                .kicker(theme.colors.textMuted)
            Text("#\(item.placement.placement)")
                .font(.bettyTitle3)
                .displayKerning(22)
                .foregroundStyle(placeColor)
            Text("· \(item.placement.score) PTS")
                .kicker(theme.colors.textSecondary)
        }
    }

    /// Leaderboard place colors: 1st orange, 2nd yellow, rest plain.
    private var placeColor: Color {
        switch item.placement.placement {
        case 1: Palette.orange
        case 2: Palette.yellow
        default: theme.colors.textPrimary
        }
    }
}

/// Grouped-mode stacked card (web `.group-card--stack`): one tournament image header
/// with the group count, then a row per group with hairline separators.
struct HomeStackedGroupCard: View {
    let tournament: Tournament
    let items: [HomeGroupItem]
    let recentlyEnded: Bool

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        VStack(spacing: 0) {
            imageHeader
            rows
        }
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private var imageHeader: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .background {
                ZStack {
                    theme.colors.surfaceDeep
                    if let urlString = tournament.imageURL, !urlString.isEmpty,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            }
                        }
                    }
                }
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                if recentlyEnded {
                    EndedBadge(text: "● JUST ENDED")
                        .padding(10)
                }
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    Text("★ \(tournament.name)")
                        .kicker(Palette.orange)
                    Spacer()
                    Text("\(items.count) GROUPS")
                        .font(.bettyKicker)
                        .kerning(1.4)
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, Space.xs)
                        .background(Palette.pillDark, in: RoundedRectangle(cornerRadius: Radius.sharp))
                        .accessibilityIdentifier("home.groups.stack.count.\(tournament.id)")
                }
                .padding(.horizontal, Space.m)
                .padding(.bottom, Space.s)
            }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                NavigationLink(value: Destination.groupDetail(groupID: item.id)) {
                    rowContent(item)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.groups.stackRow.\(item.id)")
                if item.id != items.last?.id {
                    Rectangle()
                        .fill(theme.colors.overlay04)
                        .frame(height: 1)
                        .padding(.horizontal, Space.l)
                }
            }
        }
        .padding(.vertical, Space.xs)
    }

    private func rowContent(_ item: HomeGroupItem) -> some View {
        HStack(spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(item.placement.name)
                    .font(.bettyHeadline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(item.placement.memberCount) MEMBERS")
                        .kicker(theme.colors.textMuted)
                    Text("·")
                        .foregroundStyle(theme.colors.textMuted)
                    Text(item.ended ? "○ ENDED" : "● ACTIVE")
                        .kicker(item.ended ? theme.colors.textMuted : theme.colors.accentPositive)
                    if item.isPublic {
                        Text("·")
                            .foregroundStyle(theme.colors.textMuted)
                        Text("● PUBLIC")
                            .kicker(theme.colors.accentPositive)
                    }
                }
            }
            Spacer(minLength: Space.xs)
            Text("#\(item.placement.placement)")
                .font(.bettyTitle3)
                .displayKerning(22)
                .foregroundStyle(theme.colors.textSecondary)
            Image(systemName: "arrow.right")
                .font(.bettySubhead)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .padding(.vertical, Space.s)
        .padding(.horizontal, Space.l)
        .contentShape(Rectangle())
    }
}
