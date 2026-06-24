package social.betty.features.home

/** Running/Ended tab selection. */
enum class HomeTab { RUNNING, ENDED }

/** Hero headline variants mirroring HomeDashboardLogic/HomeHeadline. */
sealed interface HomeHeadline {
    data class Groups(val count: Int) : HomeHeadline
    data object NoneRunning : HomeHeadline
    data object NoneEnded : HomeHeadline
    data object Empty : HomeHeadline
}

fun homeHeadline(
    visibleCount: Int,
    totalCount: Int,
    tab: HomeTab,
): HomeHeadline = when {
    visibleCount > 0 -> HomeHeadline.Groups(visibleCount)
    totalCount > 0 -> if (tab == HomeTab.RUNNING) HomeHeadline.NoneRunning else HomeHeadline.NoneEnded
    else -> HomeHeadline.Empty
}

/** DD:HH:MM:SS countdown parts, floored and clamped to zero. */
data class CountdownParts(val days: Int, val hours: Int, val minutes: Int, val seconds: Int) {
    companion object {
        fun until(target: java.time.Instant, now: java.time.Instant): CountdownParts {
            val total = maxOf(0L, target.epochSecond - now.epochSecond)
            return CountdownParts(
                days = (total / 86_400).toInt(),
                hours = ((total % 86_400) / 3_600).toInt(),
                minutes = ((total % 3_600) / 60).toInt(),
                seconds = (total % 60).toInt(),
            )
        }

        fun pad(value: Int): String = if (value < 10) "0$value" else value.toString()
    }
}
