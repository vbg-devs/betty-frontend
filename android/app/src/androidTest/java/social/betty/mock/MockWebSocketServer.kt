package social.betty.mock

import android.util.Base64
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Collections
import java.util.Timer
import java.util.TimerTask
import kotlin.concurrent.thread

/**
 * Loopback WebSocket server (raw ServerSocket + RFC 6455 framing) mirroring
 * `wss://api.betty.social/ws`: a global broadcast fan-out. On client connect it immediately
 * sends `{"type":"ping","message":null}` (the app reports `connected` only after the first
 * frame) and keeps pinging every 5 s so the client's watchdog never trips. [push] broadcasts
 * an event frame to every connected client; client frames (masked) are read and ignored.
 */
class MockWebSocketServer {
    private val lock = Object()
    private val clients = Collections.synchronizedList(ArrayList<OutputStream>())

    @Volatile
    private var serverSocket: ServerSocket? = null

    @Volatile
    private var pingTimer: Timer? = null

    @Volatile
    var port: Int = 0
        private set

    fun start() {
        val socket = try {
            ServerSocket(0, 64, InetAddress.getByName("127.0.0.1"))
        } catch (e: Exception) {
            throw MockServerException("WebSocket listener did not become ready: ${e.message}")
        }
        serverSocket = socket
        port = socket.localPort
        thread(isDaemon = true, name = "betty.mock.ws.accept") {
            while (true) {
                val connection = try {
                    socket.accept()
                } catch (e: Exception) {
                    return@thread
                }
                thread(isDaemon = true, name = "betty.mock.ws.conn") { serve(connection) }
            }
        }

        val timer = Timer("betty.mock.ws.ping", true)
        timer.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                push("""{"type":"ping","message":null}""")
            }
        }, 5_000, 5_000)
        pingTimer = timer
    }

    fun stop() {
        pingTimer?.cancel()
        pingTimer = null
        runCatching { serverSocket?.close() }
        serverSocket = null
        val snapshot = synchronized(clients) { ArrayList(clients) }
        clients.clear()
        for (out in snapshot) {
            runCatching { out.close() }
        }
    }

    /** Broadcasts a text frame to every connected client. */
    fun push(text: String) {
        val frame = encodeTextFrame(text)
        val snapshot = synchronized(clients) { ArrayList(clients) }
        for (out in snapshot) {
            try {
                synchronized(out) {
                    out.write(frame)
                    out.flush()
                }
            } catch (e: Exception) {
                clients.remove(out)
            }
        }
    }

    /**
     * Blocks until at least one client completed the handshake (the app connects only
     * after a successful sign-in bootstrap).
     */
    fun waitForClient(timeoutMillis: Long = 10_000): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMillis
        synchronized(lock) {
            while (clients.isEmpty()) {
                val remaining = deadline - System.currentTimeMillis()
                if (remaining <= 0) return clients.isNotEmpty()
                runCatching { lock.wait(remaining) }
            }
        }
        return true
    }

    val clientCount: Int
        get() = clients.size

    // --- Private --------------------------------------------------------------

    private fun serve(connection: Socket) {
        connection.use { socket ->
            var registered: OutputStream? = null
            runCatching {
                val input = socket.getInputStream()
                val output = socket.getOutputStream()
                if (!handshake(input, output)) return
                registered = output
                addClient(output)
                drainIncoming(input)
            }
            registered?.let { removeClient(it) }
        }
    }

    /** Performs the RFC 6455 opening handshake; returns false if the request is malformed. */
    private fun handshake(input: InputStream, output: OutputStream): Boolean {
        val head = readHead(input) ?: return false
        val key = head.lineSequence()
            .mapNotNull { line ->
                val colon = line.indexOf(':')
                if (colon < 0) {
                    null
                } else {
                    line.substring(0, colon).trim().lowercase() to line.substring(colon + 1).trim()
                }
            }
            .firstOrNull { it.first == "sec-websocket-key" }
            ?.second ?: return false

        val accept = computeAccept(key)
        val response = buildString {
            append("HTTP/1.1 101 Switching Protocols\r\n")
            append("Upgrade: websocket\r\n")
            append("Connection: Upgrade\r\n")
            append("Sec-WebSocket-Accept: $accept\r\n")
            append("\r\n")
        }
        output.write(response.toByteArray(StandardCharsets.UTF_8))
        output.flush()
        return true
    }

    private fun readHead(input: InputStream): String? {
        val buffer = StringBuilder()
        val one = ByteArray(1)
        while (true) {
            val read = input.read(one)
            if (read <= 0) return null
            buffer.append(one[0].toInt().toChar())
            val len = buffer.length
            if (len >= 4 &&
                buffer[len - 4] == '\r' && buffer[len - 3] == '\n' &&
                buffer[len - 2] == '\r' && buffer[len - 1] == '\n'
            ) {
                return buffer.toString()
            }
        }
    }

    private fun computeAccept(key: String): String {
        val magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        val sha1 = MessageDigest.getInstance("SHA-1")
            .digest((key + magic).toByteArray(StandardCharsets.UTF_8))
        return Base64.encodeToString(sha1, Base64.NO_WRAP)
    }

    /** Encodes a server→client text frame (FIN + opcode 0x1, no mask). */
    private fun encodeTextFrame(text: String): ByteArray {
        val payload = text.toByteArray(StandardCharsets.UTF_8)
        val out = java.io.ByteArrayOutputStream()
        out.write(0x81) // FIN + text opcode
        val len = payload.size
        when {
            len <= 125 -> out.write(len)
            len <= 0xFFFF -> {
                out.write(126)
                out.write((len ushr 8) and 0xFF)
                out.write(len and 0xFF)
            }
            else -> {
                out.write(127)
                for (shift in 56 downTo 0 step 8) {
                    out.write(((len.toLong() ushr shift) and 0xFF).toInt())
                }
            }
        }
        out.write(payload)
        return out.toByteArray()
    }

    /** The real server logs and ignores client messages — drain (and unmask) the app's frames. */
    private fun drainIncoming(input: InputStream) {
        while (true) {
            val frame = readFrame(input) ?: return
            // Opcode 0x8 = close → stop draining.
            if (frame == CLOSE) return
        }
    }

    /** Reads/unmasks one client frame; returns [CLOSE] on a close frame, [DATA] otherwise, null at EOF. */
    private fun readFrame(input: InputStream): Int? {
        val b0 = input.read()
        if (b0 < 0) return null
        val opcode = b0 and 0x0F
        val b1 = input.read()
        if (b1 < 0) return null
        val masked = (b1 and 0x80) != 0
        var length = (b1 and 0x7F).toLong()
        if (length == 126L) {
            val hi = input.read(); val lo = input.read()
            if (hi < 0 || lo < 0) return null
            length = ((hi shl 8) or lo).toLong()
        } else if (length == 127L) {
            length = 0
            for (i in 0 until 8) {
                val byte = input.read()
                if (byte < 0) return null
                length = (length shl 8) or byte.toLong()
            }
        }
        val mask = ByteArray(4)
        if (masked) {
            var got = 0
            while (got < 4) {
                val read = input.read(mask, got, 4 - got)
                if (read <= 0) return null
                got += read
            }
        }
        var remaining = length
        var read = 0L
        val skip = ByteArray(4096)
        while (remaining > 0) {
            val chunk = input.read(skip, 0, minOf(skip.size.toLong(), remaining).toInt())
            if (chunk <= 0) return null
            read += chunk
            remaining -= chunk
        }
        return if (opcode == 0x8) CLOSE else DATA
    }

    private fun addClient(output: OutputStream) {
        synchronized(lock) {
            clients.add(output)
            lock.notifyAll()
        }
        // First frame — flips the app's connection state to connected.
        runCatching {
            val frame = encodeTextFrame("""{"type":"ping","message":null}""")
            synchronized(output) {
                output.write(frame)
                output.flush()
            }
        }
    }

    private fun removeClient(output: OutputStream) {
        clients.remove(output)
    }

    private companion object {
        const val CLOSE = 1
        const val DATA = 0
    }
}
