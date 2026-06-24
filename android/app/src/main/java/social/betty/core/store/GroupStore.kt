package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import social.betty.core.model.Group
import social.betty.core.model.PresignedUpload
import social.betty.core.net.ApiError
import social.betty.core.net.BettyApi
import java.time.Instant

/**
 * The signed-in user's groups (data-layer.md §5.2). Every mutation re-fetches the whole list
 * — there is no optimistic group state. Error handling lives in callers (per-status meaning).
 */
class GroupStore(private val api: BettyApi) {
    private val _groups = MutableStateFlow<List<Group>>(emptyList())
    val groups: StateFlow<List<Group>> = _groups.asStateFlow()

    fun byId(id: Int): Group? = _groups.value.firstOrNull { it.id == id }

    suspend fun load() {
        _groups.value = api.getGroups()
    }

    suspend fun create(
        name: String,
        tournamentId: Int,
        correctTeamPoints: Int,
        exactResultPoints: Int,
        allowSneakPeek: Boolean,
        groupPlayDeadline: Instant?,
        welcomeMessage: String?,
        description: String?,
        isPublic: Boolean,
        boostCount: Int = 0,
        boostMultiplier: Int = 2,
    ): Int = api.createGroup(
        name, tournamentId, correctTeamPoints, exactResultPoints, allowSneakPeek,
        groupPlayDeadline, welcomeMessage, description?.takeIf { it.isNotBlank() }, isPublic,
        boostCount = boostCount, boostMultiplier = boostMultiplier,
    )

    suspend fun joinByCode(code: String): Int = api.joinByCode(code).also { load() }

    suspend fun joinPublic(id: Int): Int = api.joinPublicGroup(id).also { load() }

    suspend fun leave(id: Int) {
        api.leaveGroup(id); load()
    }

    suspend fun setVisibility(id: Int, isPublic: Boolean): Instant? =
        api.setVisibility(id, isPublic).also { load() }

    suspend fun updateSettings(
        id: Int,
        welcomeMessage: String?,
        description: String?,
        correctTeamPoints: Int,
        exactResultPoints: Int,
        allowSneakPeek: Boolean,
        boostCount: Int? = null,
        boostMultiplier: Int? = null,
    ): Group = api.updateGroupSettings(
        id, welcomeMessage, description, correctTeamPoints, exactResultPoints, allowSneakPeek,
        boostCount = boostCount, boostMultiplier = boostMultiplier,
    ).also { load() }

    suspend fun setNickname(id: Int, nickname: String?): String? =
        api.setNickname(id, nickname).also { load() }

    suspend fun setHeaderImage(id: Int, url: String) {
        api.commitHeaderImage(id, url); load()
    }

    /** Presign → raw R2 PUT → commit. Throws before committing if the upload is non-2xx. */
    suspend fun uploadHeaderImage(id: Int, contentType: String, bytes: ByteArray) {
        val presign: PresignedUpload = api.headerImageUploadUrl(id, contentType, bytes.size.toLong())
        val status = api.client.rawUpload(presign.uploadUrl, presign.method, presign.headers, contentType, bytes)
        if (status !in 200..299) throw ApiError.Status(status, serverMessage = "R2 upload failed")
        setHeaderImage(id, presign.publicUrl)
    }
}
