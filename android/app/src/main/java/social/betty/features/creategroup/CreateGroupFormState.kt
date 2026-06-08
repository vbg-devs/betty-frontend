package social.betty.features.creategroup

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import social.betty.core.model.Tournament

/** Max chars for the description field (components.md §4.2, pinned). */
const val MAX_DESCRIPTION_LENGTH = 1000

/**
 * Holds mutable form state for [CreateGroupSheet].
 *
 * `canSave` is evaluated against the *current* running list on every recomposition:
 * if the selected tournament stops being running the Create button disables again
 * (pinned web behavior — components.md §4.2).
 */
class CreateGroupFormState {
    var tournamentId: Int? by mutableStateOf(null)
    var name: String by mutableStateOf("")
    var welcomeMessage: String by mutableStateOf("")
    var description: String by mutableStateOf("")
    var winPoints: String by mutableStateOf("")
    var exactPoints: String by mutableStateOf("")

    /** Default ON — components.md §4.2. */
    var allowSneakPeek: Boolean by mutableStateOf(true)

    /** Default OFF — components.md §4.2. */
    var isPublic: Boolean by mutableStateOf(false)

    fun selectedTournament(running: List<Tournament>): Tournament? =
        tournamentId?.let { id -> running.firstOrNull { it.id == id } }

    /**
     * Web `canSave`: tournament still in the running list AND name non-empty AND both
     * point strings non-empty (components.md §4.2).
     */
    fun canSave(running: List<Tournament>): Boolean =
        selectedTournament(running) != null &&
            name.isNotEmpty() &&
            winPoints.isNotEmpty() &&
            exactPoints.isNotEmpty()
}
