package social.betty.support

import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import org.json.JSONObject
import org.junit.After
import org.junit.Before
import org.junit.Rule
import social.betty.app.LaunchOverrides
import social.betty.app.MainActivity
import social.betty.mock.BettyMockBackend
import social.betty.mock.DefaultScenario
import social.betty.mock.MockHttpRequest
import social.betty.mock.MockScenario

/**
 * JUnit4 base for every Betty Compose UI test: starts a fresh [BettyMockBackend] per test, sets
 * the DEBUG [LaunchOverrides] pointing at it, and (by default) pre-authenticates via the seeded-auth
 * fast path so tests skip sign-in.
 *
 * The overrides MUST be set before [MainActivity] launches, so the activity is NOT auto-launched by
 * a rule — call [launchApp] explicitly after any per-test scenario tweaks (a [createEmptyComposeRule]
 * still drives Compose assertions against whatever activity is up).
 *
 * Suite-writer surface:
 * - [makeScenario]       — override to customize the fixture (default: [DefaultScenario.build])
 * - [seedsAuthentication] — override to `false` in auth-flow suites
 * - [seededUserId]       — the UID the seeded session signs in as
 * - [launchApp]          — per-test override of the seeding default
 * - [backend] / [withScenario] / [pushWs] / [waitForWebSocketClient]
 * - [composeRule] for Compose node assertions; [waitForTag] / [assertTag] / [clickTag] helpers
 */
abstract class BettyUiTestCase {

    @get:Rule
    val composeRule = createEmptyComposeRule()

    lateinit var backend: BettyMockBackend
        private set

    private var scenarioInstance: ActivityScenario<MainActivity>? = null

    /** Default seeding behavior for [launchApp]. Auth suites override to `false`. */
    open val seedsAuthentication: Boolean get() = true

    /** UID the seeded session signs in as — must exist in the scenario. */
    open val seededUserId: String get() = DefaultScenario.CURRENT_USER_ID

    /**
     * Fixture state served by the mock. Override for suite-specific scenarios; mutate later (before
     * [launchApp] or mid-test) via [withScenario].
     */
    open fun makeScenario(): MockScenario = DefaultScenario.build()

    @Before
    fun setUpBackend() {
        backend = BettyMockBackend(scenario = makeScenario())
        backend.start()

        LaunchOverrides.apiBaseUrl = backend.apiBaseUrl
        LaunchOverrides.identityBaseUrl = backend.identityBaseUrl
        LaunchOverrides.secureTokenBaseUrl = backend.secureTokenBaseUrl
        LaunchOverrides.webSocketUrl = backend.webSocketUrl
        LaunchOverrides.isUiTest = true
        LaunchOverrides.disableAnimations = true
    }

    @After
    fun tearDownBackend() {
        scenarioInstance?.close()
        scenarioInstance = null
        backend.stop()
        LaunchOverrides.reset()
    }

    /**
     * Launches the app. `seedAuth = null` uses the suite default ([seedsAuthentication]). Must be
     * called after any pre-launch [withScenario] tweaks (the seeded refresh token is consumed at boot).
     */
    fun launchApp(seedAuth: Boolean? = null) {
        if (seedAuth ?: seedsAuthentication) {
            LaunchOverrides.seededRefreshToken = backend.refreshToken(seededUserId)
            LaunchOverrides.seededUid = seededUserId
        } else {
            LaunchOverrides.seededRefreshToken = null
            LaunchOverrides.seededUid = null
        }
        scenarioInstance = ActivityScenario.launch(MainActivity::class.java)
    }

    // --- Scenario / WebSocket access ------------------------------------------

    /** Exclusive read/write access to the live mock state (visible to the next request). */
    fun <T> withScenario(body: (MockScenario) -> T): T = backend.withScenario(body)

    /**
     * Broadcasts a WebSocket event (`{"type": ..., "message": ...}`) to the app. Call
     * [waitForWebSocketClient] first — pushes before the app connects are lost.
     */
    fun pushWs(type: String, message: Any? = null) = backend.pushEvent(type, message)

    /** Asserts (and waits for) the app's WebSocket client to connect; fails the test if it doesn't. */
    fun waitForWebSocketClient(timeoutMillis: Long = 15_000): Boolean {
        val connected = backend.waitForWebSocketClient(timeoutMillis)
        check(connected) { "App never connected to the mock WebSocket server" }
        return connected
    }

    // --- Request assertions ---------------------------------------------------

    val recordedRequests: List<MockHttpRequest> get() = backend.recordedRequests

    fun requests(method: String? = null, pathPrefix: String): List<MockHttpRequest> =
        backend.requests(method, pathPrefix)

    // --- Compose helpers ------------------------------------------------------

    /** Waits until a node with [testTag] exists, then returns it. */
    fun waitForTag(testTag: String, timeoutMillis: Long = 10_000) =
        composeRule.waitForTag(testTag, timeoutMillis)

    /** Asserts a node with [testTag] is displayed (waiting for it first). */
    fun assertTag(testTag: String, timeoutMillis: Long = 10_000) =
        composeRule.assertTag(testTag, timeoutMillis)

    /** Clicks the node with [testTag] (waiting for it first). */
    fun clickTag(testTag: String, timeoutMillis: Long = 10_000) =
        composeRule.clickTag(testTag, timeoutMillis)
}
