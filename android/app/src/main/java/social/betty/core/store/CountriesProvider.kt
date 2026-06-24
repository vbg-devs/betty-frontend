package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import social.betty.core.model.Country
import social.betty.core.net.BettyApi

/**
 * Countries for the profile picker (data-layer.md §9). Loads `GET /countries`; falls back to
 * a bundled list when unavailable. Deduped + cached for the session.
 */
class CountriesProvider(private val api: BettyApi) {
    private val _countries = MutableStateFlow(FALLBACK)
    val countries: StateFlow<List<Country>> = _countries.asStateFlow()

    fun byCode(code: String?): Country? =
        code?.let { c -> _countries.value.firstOrNull { it.code.equals(c, ignoreCase = true) } }

    suspend fun load() {
        val remote = runCatching { api.getCountries() }.getOrNull()
        if (!remote.isNullOrEmpty()) {
            _countries.value = remote.distinctBy { it.code }
        }
    }

    private companion object {
        val FALLBACK: List<Country> = listOf(
            Country("SE", "Sweden", "🇸🇪"),
            Country("NO", "Norway", "🇳🇴"),
            Country("DK", "Denmark", "🇩🇰"),
            Country("FI", "Finland", "🇫🇮"),
            Country("GB", "United Kingdom", "🇬🇧"),
            Country("IE", "Ireland", "🇮🇪"),
            Country("DE", "Germany", "🇩🇪"),
            Country("FR", "France", "🇫🇷"),
            Country("ES", "Spain", "🇪🇸"),
            Country("PT", "Portugal", "🇵🇹"),
            Country("IT", "Italy", "🇮🇹"),
            Country("NL", "Netherlands", "🇳🇱"),
            Country("BE", "Belgium", "🇧🇪"),
            Country("PL", "Poland", "🇵🇱"),
            Country("US", "United States", "🇺🇸"),
            Country("CA", "Canada", "🇨🇦"),
            Country("BR", "Brazil", "🇧🇷"),
            Country("AR", "Argentina", "🇦🇷"),
            Country("AU", "Australia", "🇦🇺"),
            Country("JP", "Japan", "🇯🇵"),
        )
    }
}
