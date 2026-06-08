package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.JsonElement
import social.betty.core.model.ActivityMessage
import java.time.Instant
import java.util.concurrent.atomic.AtomicLong

/**
 * Activity-feed ring buffer (data-layer.md §5.7). Fed exclusively by the WebSocket. Keeps the
 * last [capacity] non-ping events (web keeps 5; Android keeps a longer scrollback). `add`
 * trims from the front; `remove` removes the first match only; `clearAll` empties it.
 */
class ActivityFeedStore(private val capacity: Int = 50) {
    private val _messages = MutableStateFlow<List<ActivityMessage>>(emptyList())
    val messages: StateFlow<List<ActivityMessage>> = _messages.asStateFlow()

    private val counter = AtomicLong(0)

    private val _unseen = MutableStateFlow(0)
    val unseen: StateFlow<Int> = _unseen.asStateFlow()

    fun add(type: String, message: JsonElement?, timestamp: Instant = Instant.now()) {
        val item = ActivityMessage(counter.incrementAndGet(), type, message, timestamp)
        _messages.value = (listOf(item) + _messages.value).take(capacity)
        _unseen.value += 1
    }

    fun remove(id: Long) {
        val list = _messages.value.toMutableList()
        val idx = list.indexOfFirst { it.id == id }
        if (idx >= 0) {
            list.removeAt(idx)
            _messages.value = list
        }
    }

    fun clearAll() {
        _messages.value = emptyList()
    }

    fun markSeen() {
        _unseen.value = 0
    }
}
