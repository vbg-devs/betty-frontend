package social.betty.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Wire-contract twin of iOS `PushPayloadDecodingTests`: the reminder-push deep links must parse
 * to [DeepLink.Bet]. `DeepLink.parse` uses `android.net.Uri`, so this needs Robolectric.
 * Robolectric 4.14.1 maxes at SDK 35 but compileSdk is 36 → pin to SDK 34 (matches the e2e emulator).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DeepLinkBetTest {

    @Test fun universalReminderUrlRoutesToBet() {
        assertEquals(
            DeepLink.Bet(gameId = 1234, groupId = 42),
            DeepLink.parse("https://betty.social/groups/42/games/1234"),
        )
    }

    @Test fun customSchemeBetUrlRoutes() {
        assertEquals(
            DeepLink.Bet(gameId = 1234, groupId = 42),
            DeepLink.parse("betty://bet/42/1234"),
        )
    }

    @Test fun joinInviteStillParses() {
        assertEquals(
            DeepLink.JoinInvite("abc-123"),
            DeepLink.parse("https://betty.social/dashboard/groups/join/abc-123"),
        )
    }

    @Test fun nonGameUniversalUrlIgnored() {
        assertNull(DeepLink.parse("https://betty.social/groups/42/foo/1234"))
    }

    @Test fun nonNumericIdsIgnored() {
        assertNull(DeepLink.parse("https://betty.social/groups/x/games/y"))
    }

    @Test fun customSchemeBetWithExtraSegmentsIgnored() {
        assertNull(DeepLink.parse("betty://bet/42/1234/extra"))
    }
}
