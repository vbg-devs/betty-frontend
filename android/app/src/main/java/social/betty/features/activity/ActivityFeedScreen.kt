package social.betty.features.activity

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import social.betty.core.model.Team
import social.betty.core.model.WebSocketEventType
import social.betty.designsystem.Palette
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.EmptyState
import social.betty.designsystem.components.KickerText
import social.betty.navigation.LocalAppContainer

/**
 * Activity feed screen (screens.md §3.8, components.md §7). Live global WebSocket ticker:
 * collects socket events, adds non-ping ones to the ring buffer, renders styled rows per
 * type, and marks all messages seen on appear.
 *
 * Tags: activity-screen (root), activity-row (each row, in ActivityRow), activity-clear,
 * activity-empty.
 */
@Composable
fun ActivityFeedScreen() {
    val container = LocalAppContainer.current

    // Collect messages and unseen count from the activity feed store.
    val messages by container.activityFeed.messages.collectAsStateWithLifecycle()
    val teams by container.teamStore.teams.collectAsStateWithLifecycle()
    val groups by container.groupStore.groups.collectAsStateWithLifecycle()
    val currentUserId = container.userStore.id

    // Build fast lookup maps from the collected state.
    val teamIndex: Map<Int, Team> = teams.associateBy { it.id }
    val groupIndex = groups.associateBy { it.id }

    // Collect WebSocket events and feed them into the activity store.
    // Skip "ping" as specified. The socket is already connected post-boot.
    LaunchedEffect(Unit) {
        container.socket.events.collect { envelope ->
            if (envelope.type == WebSocketEventType.PING) return@collect
            container.activityFeed.add(envelope.type, envelope.message)
        }
    }

    // Mark all messages seen when this screen is visible.
    LaunchedEffect(Unit) {
        container.activityFeed.markSeen()
    }

    BettyScaffold(modifier = Modifier.testTag("activity-screen")) {
        if (messages.isEmpty()) {
            EmptyState(
                title = "ALL QUIET.",
                message = "Live events from everyone on Betty appear here as they happen.",
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Space.m)
                    .testTag("activity-empty"),
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = Space.m),
                verticalArrangement = Arrangement.spacedBy(Space.s),
            ) {
                // Header: kicker + CLEAR ALL button.
                item {
                    Spacer(Modifier.height(Space.s))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        KickerText(text = "★ ACTIVITY", color = Palette.orange)
                        Spacer(Modifier.weight(1f))
                        BettyButton(
                            text = "CLEAR ALL",
                            onClick = { container.activityFeed.clearAll() },
                            variant = BettyButtonVariant.GHOST,
                            modifier = Modifier.testTag("activity-clear"),
                        )
                    }
                }

                // One row per message (newest-first — store prepends).
                items(messages, key = { it.id }) { message ->
                    ActivityRow(
                        message = message,
                        gameById = { id ->
                            // GameStore.byId is the only available lookup — lazy loading
                            // via a standalone GET /game/:id endpoint is not exposed in
                            // BettyApi or GameStore.load(); games become available here
                            // naturally when tournament details are loaded by GroupDetail.
                            container.gameStore.byId(id)
                        },
                        teamById = { id -> teamIndex[id] },
                        groupNameById = { id -> groupIndex[id]?.name },
                        memberDisplayName = { groupId, userId ->
                            // Mirrors web `GameMessageListItem.vue:59-64`: resolve via the
                            // group's member roster (nickname || name).
                            val group = groupIndex[groupId] ?: return@ActivityRow null
                            val member = group.members.firstOrNull { it.userId == userId }
                                ?: return@ActivityRow null
                            member.nickname?.takeIf { it.isNotEmpty() }
                                ?: member.name?.takeIf { it.isNotEmpty() }
                        },
                        currentUserId = currentUserId,
                        // No-op: standalone game fetch is unavailable in the current API
                        // surface (BettyApi has no getGame(id) and GameStore has no load(id)).
                        // Games are populated indirectly when GroupDetail loads tournament
                        // details. This deviation is documented in the port report.
                        onLoadGame = { /* no-op: see report */ },
                    )
                }

                item { Spacer(Modifier.height(Space.m)) }
            }
        }
    }
}
