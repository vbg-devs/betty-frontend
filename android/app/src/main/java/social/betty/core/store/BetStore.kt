package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import social.betty.core.model.Bet
import social.betty.core.net.BettyApi

/**
 * Session-placed bets (data-layer.md §5.4). Display data comes from `GET /bets/bygroup/:id`
 * (held per-screen). Critical rule: editing an existing bet **with "all groups" on**
 * re-POSTs `/bet` with `is_universal=true` so every group in the tournament is upserted;
 * a single-group edit uses [update]. That branching lives in the caller (BetSheet VM).
 */
class BetStore(private val api: BettyApi) {
    private val _bets = MutableStateFlow<List<Bet>>(emptyList())
    val bets: StateFlow<List<Bet>> = _bets.asStateFlow()

    /** POST /bet — 200 on success, 423 if the game already started. */
    suspend fun place(
        gameId: Int,
        groupId: Int,
        home: Int,
        away: Int,
        isUniversal: Boolean,
        boosted: Boolean = false,
    ): Bet =
        api.placeBet(gameId, groupId, home, away, isUniversal, boosted).also { bet ->
            _bets.value = _bets.value + bet
        }

    /** PUT /bet/:id — single-group score edit only. Unknown id leaves state untouched. */
    suspend fun update(id: Int, home: Int, away: Int, boosted: Boolean = false): Bet =
        api.updateBet(id, home, away, boosted).also { updated ->
            _bets.value = _bets.value.map { if (it.id == id) updated else it }
        }
}
