import SwiftUI

/// Web `TopThree.vue`: top 3 by score, medium avatars, tap selects the member.
struct GroupTopThree: View {
    let members: [Member]
    var onSelect: (Member) -> Void

    private var topThree: [Member] {
        members.sorted { $0.score > $1.score }.prefix(3).map { $0 }
    }

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(Array(topThree.enumerated()), id: \.element.id) { index, member in
                Button {
                    onSelect(member)
                } label: {
                    AvatarView(member: member, size: .medium)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(member.displayName)
                .accessibilityIdentifier("groupDetail.top3.member.\(index)")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Web `Leaderboard.vue` (group mode): dense tie-ranked rows, zero-padded places,
/// top-3 place accents keyed on PLACE (tied firsts both get the first accent),
/// "YOU" highlight, tap opens the member's bet history.
struct GroupLeaderboardList: View {
    let members: [Member]
    var onSelect: (Member) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        let myID = env.userStore.id
        VStack(spacing: 2) {
            ForEach(Array(GroupStandings.ranked(members).enumerated()), id: \.element.id) { index, entry in
                row(entry, isYou: myID != nil && entry.item.userID == myID)
                    .accessibilityIdentifier("groupDetail.leaderboard.row.\(index)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp))
    }

    private func row(_ entry: DenseRanking.Ranked<Member>, isYou: Bool) -> some View {
        Button {
            onSelect(entry.item)
        } label: {
            HStack(spacing: Space.m) {
                Text(GroupStandings.placeDisplay(entry.place))
                    .font(.betty(22, .black))
                    .monospacedDigit()
                    .foregroundStyle(placeColor(entry.place))
                    .frame(width: 40, alignment: .leading)
                AvatarView(member: entry.item, size: .small)
                HStack(spacing: 10) {
                    Text(entry.item.displayName)
                        .font(.bettyBody)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isYou { YouBadge() }
                }
                Spacer(minLength: Space.xs)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.item.score)")
                        .font(.bettyScoreRow)
                        .foregroundStyle(entry.place == 1 ? theme.colors.accentPositive : theme.colors.textPrimary)
                    Text("P")
                        .font(.bettyKicker)
                        .kerning(1.2)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, Space.l)
            .background(isYou ? AnyShapeStyle(Palette.orangeTint12) : AnyShapeStyle(theme.colors.surface))
            .overlay(alignment: .leading) {
                if isYou {
                    Rectangle().fill(Palette.orange).frame(width: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func placeColor(_ place: Int) -> Color {
        switch place {
        case 1: Palette.orange
        case 2: Palette.yellow
        default: theme.colors.textSecondary
        }
    }
}

/// Web group page final podium: places 1–3, ties grouped per slot, visual order 2-1-3,
/// slot 1 on orange; tapping a person opens their bet history.
struct GroupPodiumView: View {
    let slots: [GroupPodiumSlot]
    var onSelect: (Member) -> Void

    @Environment(ThemeStore.self) private var theme

    /// Web flex order: slot 2 left, slot 1 center, slot 3 right.
    private var orderedSlots: [GroupPodiumSlot] {
        slots.sorted { visualOrder($0.place) < visualOrder($1.place) }
    }

    private func visualOrder(_ place: Int) -> Int {
        switch place {
        case 1: 2
        case 2: 1
        default: 3
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Space.s) {
            ForEach(orderedSlots) { slot in
                slotView(slot)
            }
        }
    }

    private func slotView(_ slot: GroupPodiumSlot) -> some View {
        let isFirst = slot.place == 1
        return VStack(spacing: Space.s) {
            Text("#\(slot.place)")
                .font(.betty(13, .heavy))
                .kerning(1.6)
                .foregroundStyle(placeAccent(slot.place))
            ForEach(Array(slot.members.enumerated()), id: \.element.id) { index, member in
                Button {
                    onSelect(member)
                } label: {
                    VStack(spacing: 8) {
                        AvatarView(
                            member: member,
                            size: isFirst && slot.members.count == 1 ? .large : .medium
                        )
                        Text(member.displayName)
                            .font(.betty(16, .heavy))
                            .foregroundStyle(isFirst ? .white : theme.colors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("\(member.score) PTS")
                            .font(.bettyKicker)
                            .kerning(1.4)
                            .monospacedDigit()
                            .foregroundStyle(isFirst ? .white.opacity(0.85) : theme.colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("groupDetail.podium.place.\(slot.place).member.\(index)")
            }
        }
        .padding(.top, isFirst ? Space.xl : 20)
        .padding(.bottom, isFirst ? Space.l : 18)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            isFirst ? AnyShapeStyle(Palette.orange) : AnyShapeStyle(theme.colors.overlay04),
            in: RoundedRectangle(cornerRadius: Radius.sharp)
        )
    }

    private func placeAccent(_ place: Int) -> Color {
        switch place {
        case 1: .white.opacity(0.85)
        case 2: Palette.yellow
        default: theme.colors.textSecondary
        }
    }
}
