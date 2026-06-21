package social.betty.core.push

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Reports the **real** POST_NOTIFICATIONS grant state — never a blind `true`. Below API 33 the
 * permission is implicitly granted (no runtime prompt exists). Used to gate registration so the
 * push phase never lies about being authorized (which would silently drop `notify()` calls).
 */
object PushPermission {
    fun isGranted(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
}
