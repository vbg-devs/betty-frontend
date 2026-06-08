package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.concurrent.atomic.AtomicLong

enum class NoticeKind { SUCCESS, INFO, ERROR, CRITICAL }

data class Notice(val id: Long, val message: String, val kind: NoticeKind)

/**
 * Transient toast + critical-alert center (data-layer.md §12 / `useNotify`). The UI's
 * `ToastHost` maps [Notice] → the design-system `ToastData`. Success/info auto-dismiss;
 * critical alerts are surfaced as a blocking dialog by the host.
 */
class NotifyCenter {
    private val _notices = MutableStateFlow<List<Notice>>(emptyList())
    val notices: StateFlow<List<Notice>> = _notices.asStateFlow()

    private val counter = AtomicLong(0)

    fun success(message: String) = show(message, NoticeKind.SUCCESS)
    fun info(message: String) = show(message, NoticeKind.INFO)
    fun error(message: String) = show(message, NoticeKind.ERROR)
    fun critical(message: String) = show(message, NoticeKind.CRITICAL)

    fun show(message: String, kind: NoticeKind): Long {
        val id = counter.incrementAndGet()
        _notices.value = _notices.value + Notice(id, message, kind)
        return id
    }

    fun dismiss(id: Long) {
        _notices.value = _notices.value.filterNot { it.id == id }
    }
}
