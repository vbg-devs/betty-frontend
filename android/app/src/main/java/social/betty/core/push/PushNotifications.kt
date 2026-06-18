package social.betty.core.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import social.betty.R
import social.betty.app.MainActivity

/** Notification channel for game reminders. minSdk 26 always requires a channel. */
const val REMINDERS_CHANNEL_ID = "betty.reminders"

/** Idempotent — safe to call on every app start and before each notify(). */
fun ensureReminderChannel(context: Context) {
    val manager = context.getSystemService(NotificationManager::class.java) ?: return
    if (manager.getNotificationChannel(REMINDERS_CHANNEL_ID) == null) {
        manager.createNotificationChannel(
            NotificationChannel(
                REMINDERS_CHANNEL_ID,
                "Game reminders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Reminders to place your picks before a game starts" },
        )
    }
}

/**
 * Builds + posts a reminder notification. FCM auto-displays "notification" messages only when
 * the app is backgrounded; foreground messages arrive in [BettyMessagingService.onMessageReceived]
 * with no tray UI, so we post here. [url] (the wire `data.url`) is carried as an intent extra and
 * routed through `DeepLink.parse` on tap — never opened raw (mirrors iOS `safeReturnUrl` strictness).
 */
fun showReminderNotification(context: Context, title: String, body: String, url: String?) {
    ensureReminderChannel(context)
    // Respect the real permission state — posting without it is silently dropped by the OS.
    if (!PushPermission.isGranted(context)) return

    val tapIntent = Intent(context, MainActivity::class.java).apply {
        action = Intent.ACTION_VIEW
        url?.let { putExtra(MainActivity.EXTRA_PUSH_URL, it) }
        // MainActivity is singleTask → a tap routes through onNewIntent.
        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
    }
    val pending = PendingIntent.getActivity(
        context,
        url.hashCode(),
        tapIntent,
        // FLAG_IMMUTABLE is required on API 31+.
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val notification = NotificationCompat.Builder(context, REMINDERS_CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_stat_betty)
        .setContentTitle(title)
        .setContentText(body)
        .setStyle(NotificationCompat.BigTextStyle().bigText(body))
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setAutoCancel(true)
        .setContentIntent(pending)
        .build()
    // Collapse repeated reminders for the same game (same url → same id).
    NotificationManagerCompat.from(context).notify(url.hashCode(), notification)
}
