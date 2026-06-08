package social.betty.features.profile

/**
 * Web `UpdateProfileModal` image rules — validation order, byte caps, and the exact
 * user-facing copy are pinned by the web test suite (mirrors iOS `ProfileImagePolicy`).
 */
internal object ProfileImagePolicy {
    val allowedTypes = listOf("image/png", "image/jpeg", "image/webp", "image/gif")

    /** 1 MiB — exactly 1 MiB is OK (backend cap). */
    const val MAX_BYTES = 1_048_576

    const val TYPE_MESSAGE = "Please choose a PNG, JPG, WEBP, or GIF image."
    const val SIZE_MESSAGE = "That image is over 1 MB — please pick a smaller one."
    const val EMPTY_MESSAGE = "That file looks empty. Please choose another image."
    const val GENERIC_UPLOAD_MESSAGE = "Couldn't upload your photo. Please try again."
    const val REVERT_FAILED_MESSAGE = "Couldn't revert your photo. Please try again."

    /** Pre-upload validation: type first, then size, then emptiness (web order). */
    fun validationError(contentType: String, byteCount: Int): String? {
        if (contentType !in allowedTypes) return TYPE_MESSAGE
        if (byteCount > MAX_BYTES) return SIZE_MESSAGE
        if (byteCount == 0) return EMPTY_MESSAGE
        return null
    }

    /** Upload/commit failure mapping: 413 → size copy, 415 → type copy, anything else generic. */
    fun uploadErrorMessage(status: Int?): String = when (status) {
        413 -> SIZE_MESSAGE
        415 -> TYPE_MESSAGE
        else -> GENERIC_UPLOAD_MESSAGE
    }

    /** Revert button visibility: a non-empty image that isn't the provider (Firebase) photo. */
    fun hasCustomImage(imageUrl: String?, firebaseImageUrl: String?): Boolean {
        if (imageUrl.isNullOrEmpty()) return false
        if (firebaseImageUrl.isNullOrEmpty()) return true
        return imageUrl != firebaseImageUrl
    }

    /** Magic-byte sniffing for the picked asset (the content resolver MIME is unreliable). */
    fun sniffContentType(data: ByteArray): String? {
        fun startsWith(prefix: IntArray): Boolean =
            data.size >= prefix.size && prefix.indices.all { (data[it].toInt() and 0xFF) == prefix[it] }

        if (startsWith(intArrayOf(0x89, 0x50, 0x4E, 0x47))) return "image/png"
        if (startsWith(intArrayOf(0xFF, 0xD8, 0xFF))) return "image/jpeg"
        if (startsWith(intArrayOf(0x47, 0x49, 0x46, 0x38))) return "image/gif"
        if (data.size >= 12 &&
            startsWith(intArrayOf(0x52, 0x49, 0x46, 0x46)) &&
            (data[8].toInt() and 0xFF) == 0x57 &&
            (data[9].toInt() and 0xFF) == 0x45 &&
            (data[10].toInt() and 0xFF) == 0x42 &&
            (data[11].toInt() and 0xFF) == 0x50
        ) {
            return "image/webp"
        }
        return null
    }
}

/** Web `/support` feature-request form rules (mirrors iOS `SupportFormLogic`). */
internal object SupportFormLogic {
    const val MAX_LENGTH = 5000

    /** Counter turns orange when fewer than this many characters remain (strict <). */
    const val LOW_BUDGET_THRESHOLD = 200

    /** The web textarea enforces `maxlength` — clamp pasted overflow the same way. */
    fun clamped(text: String): String =
        if (text.length <= MAX_LENGTH) text else text.take(MAX_LENGTH)

    fun remaining(text: String): Int = MAX_LENGTH - text.length

    fun warnsLowBudget(text: String): Boolean = remaining(text) < LOW_BUDGET_THRESHOLD

    fun trimmed(text: String): String = text.trim()

    /** Submit enabled only when not in flight and the trimmed text is non-empty. */
    fun canSubmit(text: String, isSubmitting: Boolean): Boolean =
        !isSubmitting && trimmed(text).isNotEmpty()
}
