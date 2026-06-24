package social.betty.app

/**
 * Root navigation phases (screens.md §1). Mirrors the iOS `AppState.phase`:
 * launching → signedOut → needsProfile → ready, with a terminal bootFailed.
 */
sealed interface AppPhase {
    data object Launching : AppPhase
    data object SignedOut : AppPhase
    data object NeedsProfile : AppPhase
    data object Ready : AppPhase
    data class BootFailed(val message: String) : AppPhase
}
