package social.betty.designsystem

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** Spacing scale (design.md §3.1). */
object Space {
    val xxs = 4.dp
    val xs = 8.dp
    val s = 12.dp
    val m = 16.dp
    val l = 22.dp
    val xl = 28.dp
    val xxl = 40.dp
    val huge = 56.dp

    /** Screen edge inset (web `.container` ≈ 90% width → 16). */
    val screenEdge = 16.dp

    /** Grid gap between cards. */
    val grid = 20.dp
}

/** Corner radii (design.md §3.2). */
object Radius {
    /** THE Betty radius. Near-square 2pt corners are a core identity trait. */
    val sharp = RoundedCornerShape(2.dp)
    val legacy = RoundedCornerShape(5.dp)
}
