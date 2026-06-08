package social.betty.core.store

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Small persisted UI prefs. `showGrouped` mirrors the web `localStorage["betty:show-grouped"]`
 * (default list view = false), shared by Home and Browse.
 */
class Preferences(context: Context) {
    private val prefs = context.getSharedPreferences("betty-prefs", Context.MODE_PRIVATE)

    private val _showGrouped = MutableStateFlow(prefs.getBoolean(KEY_SHOW_GROUPED, false))
    val showGrouped: StateFlow<Boolean> = _showGrouped.asStateFlow()

    fun setShowGrouped(value: Boolean) {
        _showGrouped.value = value
        prefs.edit().putBoolean(KEY_SHOW_GROUPED, value).apply()
    }

    private companion object {
        const val KEY_SHOW_GROUPED = "betty:show-grouped"
    }
}
