import Foundation
import Observation

/// Observable wrapper over UserDefaults for the web's persisted preferences.
/// Keys match the web localStorage keys for conceptual parity.
@Observable
final class Preferences {
    static let showGroupedKey = "betty:show-grouped"

    private let defaults: UserDefaults

    /// Dashboard/browse "Grouped" toggle — default false (list mode), shared between
    /// Home and Browse (web parity).
    var showGrouped: Bool {
        didSet { defaults.set(showGrouped, forKey: Self.showGroupedKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showGrouped = defaults.bool(forKey: Self.showGroupedKey)
    }
}
