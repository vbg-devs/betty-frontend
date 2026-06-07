import Foundation
import Observation
import SwiftUI

enum ThemeMode: String {
    case dark
    case light
}

/// App-controlled theme (NOT system-controlled): dark indigo is the default for
/// everyone; light is an explicit toggle in Profile, persisted under the web's
/// `"betty-theme"` key. Inject once at the root via `.environment(themeStore)` and read
/// with `@Environment(ThemeStore.self)`. Also set
/// `.preferredColorScheme(theme.colorScheme)` at the root so system chrome matches.
@Observable
final class ThemeStore {
    static let storageKey = "betty-theme"

    private let defaults: UserDefaults

    var mode: ThemeMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.storageKey) }
    }

    var colors: ThemeColors {
        mode == .light ? .light : .dark
    }

    var colorScheme: ColorScheme {
        mode == .light ? .light : .dark
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.mode = ThemeMode(rawValue: defaults.string(forKey: Self.storageKey) ?? "") ?? .dark
    }
}
