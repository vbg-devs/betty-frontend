package social.betty.core.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import social.betty.core.model.UserProfile

/** Pure holder for the signed-in profile (data-layer.md §5.1). No fetching of its own. */
class UserStore {
    private val _user = MutableStateFlow<UserProfile?>(null)
    val user: StateFlow<UserProfile?> = _user.asStateFlow()

    val id: String? get() = _user.value?.id
    val email: String? get() = _user.value?.email
    val isAdmin: Boolean get() = _user.value?.isAdmin == true

    fun set(profile: UserProfile?) {
        _user.value = profile
    }

    /** Patches the stored image in place after a profile-image change. */
    fun patchImage(imageUrl: String?) {
        _user.value = _user.value?.copy(imageUrl = imageUrl)
    }
}
