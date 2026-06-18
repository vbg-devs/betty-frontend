package social.betty.core.push

import android.content.Context
import com.google.firebase.FirebaseApp

/**
 * The Android analogue of iOS `FirebaseApp.app() != nil`. True only when the google-services
 * plugin generated config (i.e. `google-services.json` was present at build) AND
 * `FirebaseInitProvider` initialized the default app at startup.
 *
 * Every FCM call site checks this first: `FirebaseMessaging.getInstance()` throws
 * `IllegalStateException` when no default app exists (the no-json build), so guarding here keeps
 * the push-disabled path a clean no-op instead of a crash.
 */
object FirebaseAvailability {
    fun isConfigured(context: Context): Boolean =
        runCatching { FirebaseApp.getApps(context).isNotEmpty() }.getOrDefault(false)
}
