import Foundation

/// One card on the public-groups browse screen (web `BrowseCard` union).
nonisolated enum BrowseCard: Identifiable, Hashable, Sendable {
    case single(PublicGroupItem)
    case tournament(id: Int, name: String, imageURL: String?, groups: [PublicGroupItem])

    var id: String {
        switch self {
        case .single(let group): "g-\(group.id)"
        case .tournament(let id, _, _, _): "t-\(id)"
        }
    }
}

/// Web `visibleCards` bucketing (browse.vue, identical to the dashboard rule):
/// list mode → every item is a single card; grouped mode → items with a custom
/// `header_image_url` stay single (emitted first, in item order), the rest bucket by
/// `tournament_id` (first-appearance order); a bucket of one collapses back to a single.
nonisolated enum BrowseGrouping {
    static func cards(items: [PublicGroupItem], grouped: Bool) -> [BrowseCard] {
        guard grouped else {
            return items.map { .single($0) }
        }

        var cards: [BrowseCard] = []
        var bucketOrder: [Int] = []
        var buckets: [Int: [PublicGroupItem]] = [:]

        for item in items {
            if item.headerImageURL != nil {
                cards.append(.single(item))
                continue
            }
            if buckets[item.tournamentID] == nil {
                bucketOrder.append(item.tournamentID)
            }
            buckets[item.tournamentID, default: []].append(item)
        }

        for tournamentID in bucketOrder {
            guard let bucket = buckets[tournamentID], let first = bucket.first else { continue }
            if bucket.count == 1 {
                cards.append(.single(first))
            } else {
                cards.append(.tournament(
                    id: tournamentID,
                    name: first.tournamentName,
                    imageURL: first.tournamentImageURL,
                    groups: bucket
                ))
            }
        }

        return cards
    }
}
