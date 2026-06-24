package social.betty.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.SecondaryTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space

/**
 * Segmented underline tabs (design.md §5.7), built on M3 [SecondaryTabRow] — the standard
 * Material underline-tab control (sliding bottom indicator + hairline divider). Betty styling
 * is layered on: uppercase caption labels, `textMuted` → `textPrimary` on select, the orange
 * brand indicator, and an optional [CountPill] after each label.
 *
 * @param titles        List of tab label strings.
 * @param selectedIndex Currently selected tab index.
 * @param onSelect      Called with the tapped index.
 * @param counts        Optional per-tab count. Null entry = no pill for that tab.
 */
@OptIn(ExperimentalMaterial3Api::class)
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

    SecondaryTabRow(
        selectedTabIndex = selectedIndex,
        modifier = modifier.testTag("UnderlineTabs"),
        containerColor = Color.Transparent,
        contentColor = Palette.orange,
        divider = { HorizontalDivider(thickness = 1.dp, color = colors.overlay06) },
    ) {
        titles.forEachIndexed { index, title ->
            val isSelected = index == selectedIndex
            val count = counts.getOrNull(index)
            Tab(
                selected = isSelected,
                onClick = { onSelect(index) },
                selectedContentColor = colors.textPrimary,
                unselectedContentColor = colors.textMuted,
                modifier = Modifier.testTag("Tab_$index"),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(vertical = Space.s),
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
