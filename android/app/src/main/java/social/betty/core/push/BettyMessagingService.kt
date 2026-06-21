package social.betty.core.push

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import social.betty.app.BettyApplication

/**
 * FCM entry point — the Android analogue of the iOS `MessagingDelegate`. FCM only ever
 * instantiates this when Firebase is configured (json present at build), so no availability
 * guard is needed inside.
 */
class BettyMessagingService : FirebaseMessagingService() {

    /** FCM issues / rotates the registration token (iOS `didReceiveRegistrationToken`). */
    override fun onNewToken(token: String) {
        (application as? BettyApplication)?.container?.push?.onNewToken(token)
    }

    /**
     * Foreground and data-only messages land here (backgrounded "notification" messages are
     * auto-rendered by the OS). Wire payload (api-contract §3.2):
     * `{ notification:{title,body}, data:{ url:"https://betty.social/groups/<gid>/games/<gid>" } }`.
     */
    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.notification?.title ?: message.data["title"] ?: "Betty"
        val body = message.notification?.body ?: message.data["body"].orEmpty()
        showReminderNotification(this, title, body, message.data["url"])
    }
}
