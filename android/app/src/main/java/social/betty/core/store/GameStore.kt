package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import social.betty.core.model.Game
import social.betty.core.net.BettyApi

/**
 * Tiny fetch-through game cache (data-layer.md §5.5). Marginal — the tournament detail
 * payload already carries every game; kept for the rare standalone `GET /game/:id` lookup.
 */
class GameStore(private val api: BettyApi) {
    private val _games = MutableStateFlow<List<Game>>(emptyList())
    val games: StateFlow<List<Game>> = _games.asStateFlow()

    fun byId(id: Int): Game? = _games.value.firstOrNull { it.id == id }

    fun upsert(game: Game) {
        _games.value = _games.value.filterNot { it.id == game.id } + game
    }
}
