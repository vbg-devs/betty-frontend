package social.betty.designsystem.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space

/**
 * Segmented underline tabs (design.md §5.7).
 *
 * Label: caption style uppercase, `textMuted` → `textPrimary` when active.
 * A 3dp orange underline slides between tabs. The 1dp `overlay06` bottom rule spans
 * the full bar. Optional [counts] shows a [CountPill] after each tab label.
 *
 * @param titles        List of tab label strings.
 * @param selectedIndex Currently selected tab index.
 * @param onSelect      Called with the tapped index.
 * @param counts        Optional per-tab count. Null entry = no pill for that tab.
 */
@Composable
fun UnderlineTabs(
    titles: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    counts: List<Int?> = emptyList(),
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val density = LocalDensity.current

    val tabOffsetsPx = remember { mutableStateMapOf<Int, Float>() }
    val tabWidthsPx = remember { mutableStateMapOf<Int, Float>() }

    val underlineOffsetDp by animateDpAsState(
        targetValue = with(density) { (tabOffsetsPx[selectedIndex] ?: 0f).toDp() },
        animationSpec = tween(durationMillis = 200),
        label = "tabUnderlineOffset",
    )
    val underlineWidthDp by animateDpAsState(
        targetValue = with(density) { (tabWidthsPx[selectedIndex] ?: 0f).toDp() },
        animationSpec = tween(durationMillis = 200),
        label = "tabUnderlineWidth",
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .testTag("UnderlineTabs"),
    ) {
        // 1dp bottom rule spanning the full bar width.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .align(Alignment.BottomStart)
                .background(colors.overlay06),
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Bottom,
        ) {
            titles.forEachIndexed { index, title ->
                val isSelected = index == selectedIndex
                val count = counts.getOrNull(index)

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clickable { onSelect(index) }
                        .padding(horizontal = Space.s, vertical = Space.xs)
                        .onGloballyPositioned { coords ->
                            tabOffsetsPx[index] = coords.positionInParent().x
                            tabWidthsPx[index] = coords.size.width.toFloat()
                        }
                        .testTag("Tab_$index"),
                ) {
                    Text(
                        text = title.uppercase(),
                        style = type.caption,
                        color = if (isSelected) colors.textPrimary else colors.textMuted,
                    )
                    if (count != null) {
                        Spacer(Modifier.width(Space.xxs))
                        CountPill(count = count, isActive = isSelected)
                    }
                }
            }
        }

        // Animated 3dp underline that slides to the selected tab.
        if (underlineWidthDp > 0.dp) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .offset(x = underlineOffsetDp)
                    .width(underlineWidthDp)
                    .height(3.dp)
                    .clip(Radius.sharp)
                    .background(Palette.orange),
            )
        }
    }
}

/**
 * Toggle pills — grouping switch (design.md §5.7).
 *
 * Container: `overlay04` bg, radius 2, 3dp padding. Active segment: `orangeTint18` bg +
 * orange text. Inactive: transparent + `textMuted` text.
 *
 * @param options       List of option labels.
 * @param selectedIndex Currently active option index.
 * @param onSelect      Called with the tapped index.
 */
@Composable
fun TogglePills(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Row(
        modifier = modifier
            .clip(Radius.sharp)
            .background(colors.overlay04)
            .padding(3.dp)
            .testTag("TogglePills"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        options.forEachIndexed { index, label ->
            val isActive = index == selectedIndex
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .clip(Radius.sharp)
                    .background(if (isActive) Palette.orangeTint18 else Color.Transparent)
                    .clickable { onSelect(index) }
                    .padding(vertical = 6.dp, horizontal = Space.s)
                    .testTag("TogglePill_$index"),
            ) {
                Text(
                    text = label.uppercase(),
                    style = type.kicker,
                    color = if (isActive) Palette.orange else colors.textMuted,
                )
            }
        }
    }
}
