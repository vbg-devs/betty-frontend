package social.betty.mock

import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import kotlin.concurrent.thread

/** One parsed HTTP request as the mock routes see it. */
class MockHttpRequest(
    val method: String,
    /** Path only (query stripped), e.g. `/api/v1/groupbyid/5`. */
    val path: String,
    val query: Map<String, String>,
    /** Header names lowercased. */
    val headers: Map<String, String>,
    val body: ByteArray,
) {
    /** JSON object body, or null if the body is empty/not an object. */
    val bodyJson: JSONObject?
        get() = runCatching {
            val text = String(body, StandardCharsets.UTF_8)
            if (text.isBlank()) null else JSONObject(text)
        }.getOrNull()

    /** `application/x-www-form-urlencoded` body (securetoken refresh). */
    val bodyForm: Map<String, String>
        get() = parseForm(String(body, StandardCharsets.UTF_8))

    companion object {
        fun parseForm(raw: String): Map<String, String> {
            val result = LinkedHashMap<String, String>()
            for (pair in raw.split("&")) {
                if (pair.isEmpty()) continue
                val idx = pair.indexOf('=')
                val key = if (idx >= 0) pair.substring(0, idx) else pair
                val value = if (idx >= 0) pair.substring(idx + 1) else ""
                result[decode(key)] = decode(value.replace("+", " "))
            }
            return result
        }

        private fun decode(s: String): String =
            runCatching { URLDecoder.decode(s, "UTF-8") }.getOrDefault(s)
    }
}

/** Response value built by route handlers. */
class MockHttpResponse(
    val status: Int,
    val headers: Map<String, String> = emptyMap(),
    val body: ByteArray = ByteArray(0),
) {
    companion object {
        /** JSON-serialized body. Accepts [JSONObject]/[JSONArray] or any org.json-wrappable value. */
        fun json(value: Any, status: Int = 200): MockHttpResponse {
            val text = when (value) {
                is JSONObject -> value.toString()
                is JSONArray -> value.toString()
                is Map<*, *> -> JSONObject(value).toString()
                is List<*> -> JSONArray(value).toString()
                else -> JSONObject.wrap(value).toString()
            }
            return MockHttpResponse(
                status = status,
                headers = mapOf("Content-Type" to "application/json"),
                body = text.toByteArray(StandardCharsets.UTF_8),
            )
        }

        /** Status-only response (the Betty API's errors usually have empty bodies). */
        fun empty(status: Int): MockHttpResponse = MockHttpResponse(status)

        /** Go's `c.JSON(200, nil)` — the literal 4 bytes `null`. */
        fun nullBody(status: Int = 200): MockHttpResponse = MockHttpResponse(
            status = status,
            headers = mapOf("Content-Type" to "application/json"),
            body = "null".toByteArray(StandardCharsets.UTF_8),
        )

        fun reason(status: Int): String = when (status) {
            200 -> "OK"
            201 -> "Created"
            204 -> "No Content"
            400 -> "Bad Request"
            401 -> "Unauthorized"
            403 -> "Forbidden"
            404 -> "Not Found"
            409 -> "Conflict"
            410 -> "Gone"
            413 -> "Payload Too Large"
            415 -> "Unsupported Media Type"
            423 -> "Locked"
            500 -> "Internal Server Error"
            503 -> "Service Unavailable"
            else -> "Status"
        }
    }
}

/** Thrown when a loopback server cannot bind/accept. */
class MockServerException(message: String) : Exception(message)

/**
 * Minimal HTTP/1.1 server on a loopback ephemeral port (java.net.ServerSocket,
 * thread-per-connection, no deps). One request per connection (`Connection: close`) — OkHttp
 * transparently opens a fresh connection per call. Handlers run on the accepting thread;
 * shared state they touch must bring its own synchronization (BettyMockBackend's scenario lock).
 */
class MockHttpServer {
    fun interface Handler {
        fun handle(request: MockHttpRequest, params: Map<String, String>): MockHttpResponse
    }

    private class Route(
        val method: String,
        val segments: List<String>,
        val handler: Handler,
    )

    private val lock = Any()
    private val routes = ArrayList<Route>()
    private val recorded = ArrayList<MockHttpRequest>()

    @Volatile
    private var serverSocket: ServerSocket? = null

    @Volatile
    var port: Int = 0
        private set

    /**
     * Registers a route. Patterns use `:name` for path parameters and a trailing star
     * to match any remainder (used by the presigned-PUT upload catch-all route).
     */
    fun route(method: String, pattern: String, handler: Handler) {
        val segments = pattern.split("/").filter { it.isNotEmpty() }
        synchronized(lock) { routes.add(Route(method, segments, handler)) }
    }

    /** Every request the server handled, in arrival order (for request assertions). */
    val recordedRequests: List<MockHttpRequest>
        get() = synchronized(lock) { ArrayList(recorded) }

    fun start() {
        val socket = try {
            ServerSocket(0, 64, java.net.InetAddress.getByName("127.0.0.1"))
        } catch (e: Exception) {
            throw MockServerException("HTTP listener did not become ready: ${e.message}")
        }
        serverSocket = socket
        port = socket.localPort
        thread(isDaemon = true, name = "betty.mock.http.accept") {
            while (true) {
                val connection = try {
                    socket.accept()
                } catch (e: Exception) {
                    return@thread // socket closed → stop accepting
                }
                thread(isDaemon = true, name = "betty.mock.http.conn") { serve(connection) }
            }
        }
    }

    fun stop() {
        runCatching { serverSocket?.close() }
        serverSocket = null
    }

    // --- Connection handling --------------------------------------------------

    private fun serve(connection: Socket) {
        connection.use { socket ->
            runCatching {
                val input = socket.getInputStream()
                val request = parse(input) ?: return
                val response = dispatch(request)
                send(response, socket.getOutputStream())
            }
        }
    }

    /** Reads one complete request (head + body) from the stream, or null on a malformed head. */
    private fun parse(input: InputStream): MockHttpRequest? {
        val buffer = ByteArrayOutputStream()
        val one = ByteArray(1)
        var headEnd = -1
        // Read until the CRLFCRLF head terminator.
        while (true) {
            val read = input.read(one)
            if (read <= 0) return null
            buffer.write(one)
            val bytes = buffer.toByteArray()
            if (bytes.size >= 4 &&
                bytes[bytes.size - 4] == '\r'.code.toByte() &&
                bytes[bytes.size - 3] == '\n'.code.toByte() &&
                bytes[bytes.size - 2] == '\r'.code.toByte() &&
                bytes[bytes.size - 1] == '\n'.code.toByte()
            ) {
                headEnd = bytes.size - 4
                break
            }
        }
        val headBytes = buffer.toByteArray().copyOfRange(0, headEnd)
        val head = String(headBytes, StandardCharsets.UTF_8)
        val lines = head.split("\r\n")
        if (lines.isEmpty()) return null
        val requestLine = lines[0].split(" ")
        if (requestLine.size < 2) return null
        val method = requestLine[0]
        val target = requestLine[1]

        val headers = LinkedHashMap<String, String>()
        for (i in 1 until lines.size) {
            val line = lines[i]
            val colon = line.indexOf(':')
            if (colon < 0) continue
            val name = line.substring(0, colon).lowercase()
            val value = line.substring(colon + 1).trim()
            headers[name] = value
        }

        val contentLength = headers["content-length"]?.toIntOrNull() ?: 0
        val body = ByteArray(contentLength)
        var got = 0
        while (got < contentLength) {
            val read = input.read(body, got, contentLength - got)
            if (read <= 0) break
            got += read
        }

        val qIndex = target.indexOf('?')
        val rawPath = if (qIndex >= 0) target.substring(0, qIndex) else target
        val path = runCatching { URLDecoder.decode(rawPath, "UTF-8") }.getOrDefault(rawPath)
        val query = if (qIndex >= 0) {
            MockHttpRequest.parseForm(target.substring(qIndex + 1))
        } else {
            emptyMap()
        }

        return MockHttpRequest(method, path, query, headers, body)
    }

    private fun dispatch(request: MockHttpRequest): MockHttpResponse {
        val snapshot = synchronized(lock) {
            recorded.add(request)
            ArrayList(routes)
        }
        // LAST registration wins so tests can override any built-in route after
        // `backend.start()` (e.g. force a 500 or a hand-rolled payload).
        val pathSegments = request.path.split("/").filter { it.isNotEmpty() }
        for (i in snapshot.indices.reversed()) {
            val route = snapshot[i]
            if (route.method != request.method) continue
            val params = match(route.segments, pathSegments) ?: continue
            return route.handler.handle(request, params)
        }
        return MockHttpResponse.empty(404)
    }

    private fun match(pattern: List<String>, path: List<String>): Map<String, String>? {
        if (pattern.lastOrNull() == "*") {
            if (path.size < pattern.size - 1) return null
        } else {
            if (pattern.size != path.size) return null
        }
        val params = LinkedHashMap<String, String>()
        for ((index, segment) in pattern.withIndex()) {
            if (segment == "*") break
            if (segment.startsWith(":")) {
                params[segment.substring(1)] = path[index]
            } else if (segment != path[index]) {
                return null
            }
        }
        return params
    }

    private fun send(response: MockHttpResponse, out: java.io.OutputStream) {
        val sb = StringBuilder()
        sb.append("HTTP/1.1 ${response.status} ${MockHttpResponse.reason(response.status)}\r\n")
        val headers = LinkedHashMap(response.headers)
        headers["Content-Length"] = response.body.size.toString()
        headers["Connection"] = "close"
        for ((name, value) in headers) {
            sb.append("$name: $value\r\n")
        }
        sb.append("\r\n")
        out.write(sb.toString().toByteArray(StandardCharsets.UTF_8))
        if (response.status != 204) {
            out.write(response.body)
        }
        out.flush()
    }
}
