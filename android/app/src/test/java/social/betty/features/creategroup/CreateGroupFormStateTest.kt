package social.betty.features.creategroup

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import social.betty.core.model.Tournament
import java.time.Instant

/**
 * Validation rules for [CreateGroupFormState] including the new booster fields
 * (Boosters spec §3.2). Defaults must keep boosters OFF on new groups (Decision #6).
 */
class CreateGroupFormStateTest {

    private val running = listOf(
        Tournament(
            id = 1,
            name = "Euro Cup",
            startDate = Instant.parse("2026-06-01T00:00:00Z"),
            endDate = Instant.parse("2026-07-01T00:00:00Z"),
        ),
    )

    private fun validForm(): CreateGroupFormState {
        val form = CreateGroupFormState()
        form.tournamentId = 1
        form.name = "Sunday Roast"
        form.winPoints = "2"
        form.exactPoints = "4"
        return form
    }

    @Test
    fun `defaults boost_count to 0 (boosters OFF) and multiplier to 2`() {
        val form = CreateGroupFormState()
        assertEquals("0", form.boostCount)
        assertEquals("2", form.boostMultiplier)
    }

    @Test
    fun `canSave true with defaults plus the required fields`() {
        assertTrue(validForm().canSave(running))
    }

    @Test
    fun `canSave false when boost_count is negative or non-numeric`() {
        val form = validForm()
        form.boostCount = ""
        assertFalse(form.canSave(running))
        form.boostCount = "x"
        assertFalse(form.canSave(running))
    }

    @Test
    fun `canSave false when boost_multiplier is less than one`() {
        val form = validForm()
        form.boostMultiplier = "0"
        assertFalse(form.canSave(running))
        form.boostMultiplier = ""
        assertFalse(form.canSave(running))
    }

    @Test
    fun `canSave true with boosters enabled (count gt 0, multiplier gte 1)`() {
        val form = validForm()
        form.boostCount = "3"
        form.boostMultiplier = "5"
        assertTrue(form.canSave(running))
    }
}
