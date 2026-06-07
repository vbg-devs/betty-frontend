import Foundation
import Observation

/// `GET /countries` with the bundled fallback list (web `useCountries` semantics):
/// sorted by name; empty/failed responses fall back to the built-in list, but a request
/// FAILURE leaves `isLoaded == false` so the next `load()` retries and replaces the
/// fallback; concurrent `load()` calls share one in-flight request.
@Observable
final class CountriesProvider {
    private let api: APIClient

    private(set) var countries: [Country] = CountriesProvider.fallback
    private(set) var isLoaded = false
    private var inFlight: Task<Void, Never>?

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        if isLoaded { return }
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let fetched = try await self.api.countries()
                if fetched.isEmpty {
                    self.countries = Self.fallback
                    self.isLoaded = true // empty 200 counts as loaded (web pin)
                } else {
                    self.countries = fetched.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                    self.isLoaded = true
                }
            } catch {
                self.countries = Self.fallback // keep fallback; isLoaded stays false → retry
            }
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    /// Bundled fallback — ship verbatim (web parity).
    static let fallback: [Country] = [
        Country(code: "AR", name: "Argentina", flagEmoji: "🇦🇷"),
        Country(code: "AU", name: "Australia", flagEmoji: "🇦🇺"),
        Country(code: "BE", name: "Belgium", flagEmoji: "🇧🇪"),
        Country(code: "BR", name: "Brazil", flagEmoji: "🇧🇷"),
        Country(code: "CA", name: "Canada", flagEmoji: "🇨🇦"),
        Country(code: "DK", name: "Denmark", flagEmoji: "🇩🇰"),
        Country(code: "FI", name: "Finland", flagEmoji: "🇫🇮"),
        Country(code: "FR", name: "France", flagEmoji: "🇫🇷"),
        Country(code: "DE", name: "Germany", flagEmoji: "🇩🇪"),
        Country(code: "IS", name: "Iceland", flagEmoji: "🇮🇸"),
        Country(code: "IT", name: "Italy", flagEmoji: "🇮🇹"),
        Country(code: "JP", name: "Japan", flagEmoji: "🇯🇵"),
        Country(code: "MX", name: "Mexico", flagEmoji: "🇲🇽"),
        Country(code: "NL", name: "Netherlands", flagEmoji: "🇳🇱"),
        Country(code: "NO", name: "Norway", flagEmoji: "🇳🇴"),
        Country(code: "PL", name: "Poland", flagEmoji: "🇵🇱"),
        Country(code: "PT", name: "Portugal", flagEmoji: "🇵🇹"),
        Country(code: "ES", name: "Spain", flagEmoji: "🇪🇸"),
        Country(code: "SE", name: "Sweden", flagEmoji: "🇸🇪"),
        Country(code: "CH", name: "Switzerland", flagEmoji: "🇨🇭"),
        Country(code: "GB", name: "United Kingdom", flagEmoji: "🇬🇧"),
        Country(code: "US", name: "United States", flagEmoji: "🇺🇸"),
    ]
}
