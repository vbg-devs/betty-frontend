package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import social.betty.core.model.Tournament
import java.time.Instant

/**
 * Two independent caches (data-layer.md §5.3): the summary list (no pools/games) and full
 * detail payloads keyed by id. `running` = `end_date` absent OR `>= now` (inclusive). Forced
 * detail reloads are triggered by the `evaluate_game` WebSocket event.
 */
class TournamentStore(private val api: social.betty.core.net.BettyApi) {
    private val _tournaments = MutableStateFlow<List<Tournament>>(emptyList())
    val tournaments: StateFlow<List<Tournament>> = _tournaments.asStateFlow()

    private val _details = MutableStateFlow<Map<Int, Tournament>>(emptyMap())
    val details: StateFlow<Map<Int, Tournament>> = _details.asStateFlow()

    fun byId(id: Int): Tournament? = _tournaments.value.firstOrNull { it.id == id }
    fun detailsById(id: Int): Tournament? = _details.value[id]

    fun running(now: Instant = Instant.now()): List<Tournament> = _tournaments.value.filter {
        it.endDate == null || !it.endDate.isBefore(now)
    }

    suspend fun load() {
        _tournaments.value = api.getTournaments()
    }

    /** Returns the cached detail without refetching unless [force]; upserts in place. */
    suspend fun loadDetails(id: Int, force: Boolean = false): Tournament {
        if (!force) _details.value[id]?.let { return it }
        val detail = api.getTournament(id)
        _details.value = _details.value.toMutableMap().apply { put(id, detail) }
        return detail
    }
}
