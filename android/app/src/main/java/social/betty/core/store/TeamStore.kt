package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import social.betty.core.model.Team
import social.betty.core.net.BettyApi

/** Static-ish reference data: team names + logos for game rows (data-layer.md §5.6). */
class TeamStore(private val api: BettyApi) {
    private val _teams = MutableStateFlow<List<Team>>(emptyList())
    val teams: StateFlow<List<Team>> = _teams.asStateFlow()

    private val index: Map<Int, Team> get() = _teams.value.associateBy { it.id }

    fun byId(id: Int): Team? = index[id]

    suspend fun load() {
        _teams.value = api.getTeams()
    }
}
