package social.betty.features.browse

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import social.betty.core.model.PublicGroupItem
import social.betty.core.net.ApiError
import social.betty.core.net.BettyApi
import social.betty.core.store.GroupStore

/**
 * Page-local pagination state for the public-groups browse screen.
 *
 * Results are never written into GroupStore — this list is ephemeral and scoped to the
 * screen's lifetime. Mirrors BrowseGroupsModel.swift exactly: reload() clears and re-fetches
 * page one; loadMore() appends under the same generation guard; join() mutates rows
 * optimistically and maps API status codes to typed outcomes.
 */
class BrowseViewModel(
    private val api: BettyApi,
    private val groupStore: GroupStore,
) {

    sealed class JoinOutcome {
        data class Joined(val groupId: Int, val name: String) : JoinOutcome()
        data class AlreadyMember(val name: String) : JoinOutcome()
        data class Blocked(val name: String) : JoinOutcome()
        data object Unavailable : JoinOutcome()
        data object Failed : JoinOutcome()
    }

    val items = mutableStateListOf<PublicGroupItem>()

    var isLoading by mutableStateOf(false)
        private set

    // True once the first page has settled — gates "FETCHING…" vs "NO MATCHES" states.
    var hasLoaded by mutableStateOf(false)
        private set

    var nextCursor by mutableStateOf("")
        private set

    var joiningId by mutableStateOf<Int?>(null)
        private set

    var query by mutableStateOf("")
    var tournamentId by mutableStateOf<Int?>(null)

    val hasMore: Boolean get() = nextCursor.isNotEmpty()

    // Bumped on every reload() — stale in-flight fetches arriving under an older generation
    // are discarded so debounced searches never corrupt a fresher reload.
    private var loadGeneration = 0

    /** Clears the list and fetches page one. Invalidates any in-flight fetch. */
    suspend fun reload() {
        loadGeneration++
        items.clear()
        nextCursor = ""
        fetchPage(loadGeneration)
    }

    /** Appends the next page; no-op when exhausted or a fetch is already running. */
    suspend fun loadMore() {
        if (!hasMore || isLoading) return
        fetchPage(loadGeneration)
    }

    /** Joins a public group. Returns a typed outcome for the UI to act on. */
    suspend fun join(item: PublicGroupItem): JoinOutcome {
        joiningId = item.id
        return try {
            groupStore.joinPublic(item.id)
            mutate(item.id) { copy(isMember = true, memberCount = memberCount + 1) }
            JoinOutcome.Joined(item.id, item.name)
        } catch (e: ApiError.Status) {
            when (e.code) {
                409 -> {
                    mutate(item.id) { copy(isMember = true) }
                    JoinOutcome.AlreadyMember(item.name)
                }
                403 -> JoinOutcome.Blocked(item.name)
                404 -> {
                    items.removeAll { it.id == item.id }
                    JoinOutcome.Unavailable
                }
                else -> JoinOutcome.Failed
            }
        } catch (_: Exception) {
            JoinOutcome.Failed
        } finally {
            joiningId = null
        }
    }

    private suspend fun fetchPage(generation: Int) {
        isLoading = true
        try {
            val trimmed = query.trim()
            val page = api.listPublicGroups(
                cursor = nextCursor.ifEmpty { null },
                q = trimmed.ifEmpty { null },
                tournamentId = tournamentId,
                limit = 20,
            )
            // Discard result if superseded by a newer reload().
            if (generation != loadGeneration) return
            items.addAll(page.items)
            nextCursor = page.nextCursor
        } finally {
            if (generation == loadGeneration) {
                isLoading = false
                hasLoaded = true
            }
        }
    }

    private fun mutate(id: Int, transform: PublicGroupItem.() -> PublicGroupItem) {
        val index = items.indexOfFirst { it.id == id }
        if (index >= 0) items[index] = items[index].transform()
    }
}
