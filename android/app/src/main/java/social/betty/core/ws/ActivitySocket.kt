package social.betty.core.ws

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import social.betty.core.model.WebSocketEnvelope
import social.betty.core.net.BettyJson

/**
 * The activity-feed WebSocket (api-contract.md §4): an unauthenticated global broadcast.
 * Connects to the (override-aware) WS URL, emits parsed [WebSocketEnvelope]s, sends
 * `{"type":"ping"}` every 10 s, and reconnects with backoff on drop / silence. A single
 * instance is owned by the app and shared (GroupDetail listens for `evaluate_game` too).
 */
class ActivitySocket(
    private val http: OkHttpClient,
    private val urlProvider: () -> String,
    private val scope: CoroutineScope,
    private val json: Json = BettyJson,
) {
    private val _events = MutableSharedFlow<WebSocketEnvelope>(extraBufferCapacity = 128)
    val events: SharedFlow<WebSocketEnvelope> = _events.asSharedFlow()

    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected.asStateFlow()

    private var socket: WebSocket? = null
    private var pingJob: Job? = null
    private var lifecycleJob: Job? = null
    private var attempt = 0

    fun connect() {
        if (lifecycleJob?.isActive == true) return
        lifecycleJob = scope.launch {
            while (isActive) {
                openAndAwaitClose()
                if (!isActive) break
                val backoff = minOf(30_000L, 1_000L * (1L shl minOf(attempt, 4)))
                attempt++
                delay(backoff)
            }
        }
    }

    fun disconnect() {
        lifecycleJob?.cancel(); lifecycleJob = null
        pingJob?.cancel(); pingJob = null
        socket?.close(1000, "client disconnect"); socket = null
        _connected.value = false
    }

    private suspend fun openAndAwaitClose() {
        val request = Request.Builder().url(urlProvider()).build()
        var closed = false
        val listener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                attempt = 0
                _connected.value = true
                startPing(webSocket)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                runCatching { json.decodeFromString<WebSocketEnvelope>(text) }
                    .getOrNull()
                    ?.let { _events.tryEmit(it) }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                closed = true; _connected.value = false; webSocket.close(1000, null)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                closed = true; _connected.value = false
            }
        }
        socket = http.newWebSocket(request, listener)
        // Park until the socket closes/fails; the lifecycle loop then backs off + reconnects.
        while (!closed && scope.coroutineContext[Job]?.isActive != false) {
            delay(250)
        }
        pingJob?.cancel(); pingJob = null
    }

    private fun startPing(webSocket: WebSocket) {
        pingJob?.cancel()
        pingJob = scope.launch {
            while (isActive) {
                delay(10_000)
                webSocket.send("{\"type\":\"ping\"}")
            }
        }
    }
}
