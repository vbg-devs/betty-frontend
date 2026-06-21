package social.betty.app

import android.app.Application
import social.betty.core.push.ensureReminderChannel

class BettyApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        // Idempotent + independent of Firebase config, so background tray notifications
        // (rendered by the OS) have their channel even before any registration runs.
        ensureReminderChannel(this)
    }
}
