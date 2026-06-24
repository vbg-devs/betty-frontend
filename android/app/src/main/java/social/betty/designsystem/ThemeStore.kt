package social.betty.designsystem

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

enum class ThemeMode { DARK, LIGHT, SYSTEM }

/**
 * App-controlled theme (design.md §4). Default is DARK indigo; LIGHT is an explicit
 * toggle. Persisted to SharedPreferences key `betty-theme` to mirror the web's
 * `localStorage["betty-theme"]`. SYSTEM is an Android-native addition (the web has none).
 */
class ThemeStore(context: Context) {
    private val prefs = context.getSharedPreferences("betty-prefs", Context.MODE_PRIVATE)

    var mode by mutableStateOf(read())
        private set

    fun set(newMode: ThemeMode) {
        mode = newMode
        prefs.edit().putString(KEY, newMode.name.lowercase()).apply()
    }

    private fun read(): ThemeMode = when (prefs.getString(KEY, "dark")) {
        "light" -> ThemeMode.LIGHT
        "system" -> ThemeMode.SYSTEM
        else -> ThemeMode.DARK
    }

    private companion object {
        const val KEY = "betty-theme"
    }
}
