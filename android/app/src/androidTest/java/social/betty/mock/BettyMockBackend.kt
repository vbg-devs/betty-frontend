package social.betty.mock

import org.json.JSONObject

/**
 * The hermetic Betty backend hosted inside the instrumentation test process: an HTTP server
 * (Betty API + Identity Toolkit + securetoken, one port) and a WebSocket broadcast server
 * (second port), both on 127.0.0.1 ephemeral ports. All routes resolve from a single
 * [MockScenario] behind a lock, so mutations through the API are visible to later GETs and
 * tests can inspect/modify state via [withScenario].
 *
 * Token scheme (stateless): ID token `mock-id-token-<uid>`, refresh token `mock-refresh-<uid>`.
 * The seeded-auth fast path hands the app a refresh token via launch overrides; the mock
 * securetoken endpoint exchanges it for the ID token.
 */
class BettyMockBackend(scenario: MockScenario = DefaultScenario.build()) {
    val http = MockHttpServer()
    val webSocket = MockWebSocketServer()

    private val lock = Any()
    private var state: MockScenario = scenario

    fun start() {
        http.start()
        webSocket.start()
        registerIdentityRoutes()
        registerApiRoutes()
    }

    fun stop() {
        http.stop()
        webSocket.stop()
    }

    // --- URLs for the app's launch overrides ----------------------------------

    val httpBase: String get() = "http://127.0.0.1:${http.port}"
    val apiBaseUrl: String get() = "$httpBase/api/v1"
    val identityBaseUrl: String get() = httpBase
    val secureTokenBaseUrl: String get() = httpBase
    val webSocketUrl: String get() = "ws://127.0.0.1:${webSocket.port}"

    /** R2-public-base equivalent — committed image URLs must start with this. */
    val publicAssetBase: String get() = "$httpBase/_public"

    // --- Tokens ---------------------------------------------------------------

    fun idToken(uid: String): String = "mock-id-token-$uid"

    fun refreshToken(uid: String): String = "mock-refresh-$uid"

    fun uidFromRefreshToken(token: String): String? =
        if (token.startsWith("mock-refresh-")) token.removePrefix("mock-refresh-") else null

    // --- Scenario access ------------------------------------------------------

    /** Runs [body] with exclusive access to the scenario (handlers use the same lock). */
    fun <T> withScenario(body: (MockScenario) -> T): T = synchronized(lock) { body(state) }

    var scenario: MockScenario
        get() = synchronized(lock) { state }
        set(value) {
            synchronized(lock) { state = value }
        }

    // --- WebSocket push -------------------------------------------------------

    /**
     * Broadcasts `{"type": <type>, "message": <message>}` to every connected client.
     * [message] must be a [JSONObject], a [org.json.JSONArray], a scalar, or null.
     */
    fun pushEvent(type: String, message: Any? = null) {
        val envelope = JSONObject()
        envelope.put("type", type)
        envelope.put("message", message ?: JSONObject.NULL)
        webSocket.push(envelope.toString())
    }

    fun waitForWebSocketClient(timeoutMillis: Long = 10_000): Boolean =
        webSocket.waitForClient(timeoutMillis)

    // --- Request assertions ---------------------------------------------------

    val recordedRequests: List<MockHttpRequest> get() = http.recordedRequests

    /** Handled requests filtered by method and/or path prefix (e.g. "/api/v1/bet"). */
    fun requests(method: String? = null, pathPrefix: String): List<MockHttpRequest> =
        recordedRequests.filter { request ->
            (method == null || request.method == method) && request.path.startsWith(pathPrefix)
        }

    // --- Route plumbing shared by MockIdentity / MockApiRoutes ----------------

    /**
     * A handler running inside the scenario lock, with the caller's UID resolved.
     * [scenario] is the live (mutable) state — writes persist for later requests.
     */
    fun interface ApiHandler {
        fun handle(
            request: MockHttpRequest,
            params: Map<String, String>,
            uid: String,
            scenario: MockScenario,
        ): MockHttpResponse
    }

    /**
     * Registers an authenticated `/api/v1` route. Mirrors the Go middleware exactly: missing
     * header → `401 {"error":"API token required"}`, unknown/invalid token →
     * `401 {"error":"Invalid API token"}`. The handler runs INSIDE the scenario lock with the
     * caller's UID resolved.
     */
    fun api(method: String, pattern: String, handler: ApiHandler) {
        http.route(method, "/api/v1$pattern") { request, params ->
            val header = request.headers["authorization"]
            if (header.isNullOrEmpty()) {
                return@route MockHttpResponse.json(JSONObject(mapOf("error" to "API token required")), status = 401)
            }
            val prefix = "Bearer mock-id-token-"
            if (!header.startsWith(prefix)) {
                return@route MockHttpResponse.json(JSONObject(mapOf("error" to "Invalid API token")), status = 401)
            }
            val uid = header.removePrefix(prefix)
            withScenario { scenario ->
                if (scenario.user(uid) == null) {
                    MockHttpResponse.json(JSONObject(mapOf("error" to "Invalid API token")), status = 401)
                } else {
                    handler.handle(request, params, uid, scenario)
                }
            }
        }
    }
}
