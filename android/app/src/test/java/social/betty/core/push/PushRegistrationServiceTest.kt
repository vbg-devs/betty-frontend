package social.betty.core.push

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM unit tests for [PushRegistrationService] — the wire-contract twin of iOS
 * `PushRegistrationServiceTests`. Pure JVM (no Android or Firebase deps), driven via injected fakes.
 */
class PushRegistrationServiceTest {

    private class Fixture(scope: CoroutineScope) {
        val store = object : SentTokenStore {
            var value: String? = null
            override fun get() = value
            override fun set(token: String?) { value = token }
        }
        val sent = mutableListOf<String>()
        var configured = true
        var authResult = true
        var authCalls = 0
        var fetched: String? = null
        var sendThrows = false

        val service = PushRegistrationService(
            appScope = scope,
            sentTokenStore = store,
            sendToken = { token -> if (sendThrows) error("network"); sent += token },
            requestAuthorization = { authCalls++; authResult },
            fetchToken = { fetched },
            isFirebaseConfigured = { configured },
        )
    }

    @Test fun grantedAuthFetchesAndRegisters() = runTest {
        val f = Fixture(this).apply { fetched = "tok" }
        f.service.registerIfNeeded()
        assertEquals(1, f.authCalls)
        assertEquals(PushRegistrationService.Phase.Registered("tok"), f.service.phase.value)
        assertEquals(listOf("tok"), f.sent)
    }

    @Test fun deniedAuthIsTerminalNoSecondPrompt() = runTest {
        val f = Fixture(this).apply { authResult = false }
        f.service.registerIfNeeded()
        f.service.registerIfNeeded() // second call must NOT re-prompt
        assertEquals(1, f.authCalls)
        assertEquals(PushRegistrationService.Phase.Denied, f.service.phase.value)
        assertTrue(f.sent.isEmpty())
    }

    @Test fun tokenSentOncePerValue() = runTest {
        val f = Fixture(this)
        f.service.handleToken("A")
        f.service.handleToken("A")
        assertEquals(listOf("A"), f.sent)
        assertEquals(PushRegistrationService.Phase.Registered("A"), f.service.phase.value)
    }

    @Test fun nullOrEmptyTokenIgnored() = runTest {
        val f = Fixture(this)
        f.service.handleToken(null)
        f.service.handleToken("")
        assertTrue(f.sent.isEmpty())
        assertEquals(PushRegistrationService.Phase.Idle, f.service.phase.value)
    }

    @Test fun changedTokenSentAgain() = runTest {
        val f = Fixture(this)
        f.service.handleToken("token-1")
        f.service.handleToken("token-2")
        assertEquals(listOf("token-1", "token-2"), f.sent)
    }

    @Test fun failedSendStaysUnsentAndRetries() = runTest {
        val f = Fixture(this).apply { sendThrows = true }
        f.service.handleToken("X")
        assertTrue("failed send must not mark sent", f.sent.isEmpty())
        f.sendThrows = false
        f.service.registerIfNeeded() // phase == Registered("X") → retry
        assertEquals(listOf("X"), f.sent)
    }

    @Test fun firebaseUnconfiguredIsUnavailableWithoutPromptAndRetryable() = runTest {
        val f = Fixture(this).apply { configured = false }
        f.service.registerIfNeeded()
        assertEquals(0, f.authCalls) // no pointless permission prompt when push can't work
        assertEquals(PushRegistrationService.Phase.Unavailable, f.service.phase.value)
        assertTrue(f.sent.isEmpty())
        // Later it becomes configured → retry succeeds (the Unavailable phase is retryable).
        f.configured = true
        f.fetched = "tok"
        f.service.registerIfNeeded()
        assertEquals(PushRegistrationService.Phase.Registered("tok"), f.service.phase.value)
        assertEquals(listOf("tok"), f.sent)
    }

    @Test fun fetchFailureIsUnavailableAndRetryable() = runTest {
        val f = Fixture(this).apply { fetched = null } // granted auth, but token fetch fails
        f.service.registerIfNeeded()
        assertEquals(PushRegistrationService.Phase.Unavailable, f.service.phase.value)
        assertTrue(f.sent.isEmpty())
        f.fetched = "tok"
        f.service.registerIfNeeded() // retry from Unavailable
        assertEquals(PushRegistrationService.Phase.Registered("tok"), f.service.phase.value)
        assertEquals(listOf("tok"), f.sent)
    }

    @Test fun signOutResetResendsForNextAccount() = runTest {
        val f = Fixture(this).apply { fetched = "X" }
        f.service.registerIfNeeded()
        assertEquals(listOf("X"), f.sent)
        f.service.resetForSignOut()
        assertEquals(PushRegistrationService.Phase.Idle, f.service.phase.value)
        f.service.registerIfNeeded() // same cached token, marker cleared → re-POST
        assertEquals(listOf("X", "X"), f.sent)
    }
}
