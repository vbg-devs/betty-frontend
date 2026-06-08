package social.betty.core.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Persists the refresh token + uid only (the Keychain analogue; data-layer.md §3.2). Backed
 * by [EncryptedSharedPreferences]; if the keystore is unavailable it degrades to plain prefs
 * so the app still functions (the refresh token is the sole secret and is short-lived in
 * effect — Firebase can revoke it).
 */
class TokenStore(context: Context) {
    private val prefs: SharedPreferences = runCatching {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "betty-session",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }.getOrElse {
        context.getSharedPreferences("betty-session", Context.MODE_PRIVATE)
    }

    fun save(refreshToken: String, uid: String) {
        prefs.edit().putString(KEY_REFRESH, refreshToken).putString(KEY_UID, uid).apply()
    }

    fun load(): Pair<String, String>? {
        val refresh = prefs.getString(KEY_REFRESH, null) ?: return null
        val uid = prefs.getString(KEY_UID, null) ?: return null
        return refresh to uid
    }

    fun clear() {
        prefs.edit().remove(KEY_REFRESH).remove(KEY_UID).apply()
    }

    private companion object {
        const val KEY_REFRESH = "refresh_token"
        const val KEY_UID = "uid"
    }
}
