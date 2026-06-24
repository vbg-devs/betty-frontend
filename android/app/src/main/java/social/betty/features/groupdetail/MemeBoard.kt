package social.betty.features.groupdetail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import social.betty.core.model.GroupMember
import social.betty.core.model.GroupMessage
import social.betty.core.model.Reactions
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.components.Avatar
import social.betty.designsystem.components.AvatarSize
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant

/**
 * Web `MemeBoard`: list of text/image messages (author avatar + relative time), composer
 * with a text field, GIF mode (Giphy search + prev/next preview), emoji reactions
 * (one per user, optimistic), and own-message delete. Rendered inline in the Group tab.
 */
@Composable
fun MemeBoard(
    messages: List<GroupMessage>,
    members: List<GroupMember>,
    currentUserId: String?,
    isLoaded: Boolean,
    onSendText: suspend (String) -> Boolean,
    onSendGif: suspend (String) -> Boolean,
    onSearchGifs: suspend (String) -> List<GiphyImage>,
    onToggleReaction: suspend (GroupMessage, String) -> Unit,
    onDeleteMessage: suspend (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val scope = rememberCoroutineScope()

    var draft by remember { mutableStateOf("") }
    var giphyMode by remember { mutableStateOf(false) }
    var isPosting by remember { mutableStateOf(false) }
    var isSearching by remember { mutableStateOf(false) }
    var gifResults by remember { mutableStateOf<List<GiphyImage>>(emptyList()) }
    var gifIndex by remember { mutableStateOf(0) }
    var pickerOpenFor by remember { mutableStateOf<Int?>(null) }
    var deletingId by remember { mutableStateOf<Int?>(null) }
    var confirmDeleteFor by remember { mutableStateOf<Int?>(null) }

    val membersById = remember(members) { members.associateBy { it.userId } }

    fun resetGif() {
        gifResults = emptyList()
        gifIndex = 0
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("★ GROUP CHAT", style = type.kicker, color = Palette.orange)
            Spacer(Modifier.weight(1f))
            if (messages.isNotEmpty()) {
                Text("${messages.size} MESSAGES", style = type.kicker, color = colors.textMuted)
            }
        }

        // GIF selector (when there are search results).
        if (gifResults.isNotEmpty()) {
            val safeIndex = gifIndex.coerceIn(0, gifResults.size - 1)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(Radius.sharp)
                    .background(colors.surface)
                    .padding(Space.m),
                verticalArrangement = Arrangement.spacedBy(Space.s),
            ) {
                Text("SELECT GIF", style = type.kicker, color = colors.textMuted)
                AsyncImage(
                    model = gifResults[safeIndex].originalUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 11f)
                        .clip(Radius.sharp)
                        .background(colors.overlay06),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(Space.xs), verticalAlignment = Alignment.CenterVertically) {
                    BettyButton(
                        text = "Prev",
                        onClick = { gifIndex = (safeIndex - 1).coerceAtLeast(0) },
                        variant = BettyButtonVariant.OUTLINE,
                        enabled = safeIndex > 0,
                    )
                    BettyButton(
                        text = "Next",
                        onClick = { gifIndex = (safeIndex + 1).coerceAtMost(gifResults.size - 1) },
                        variant = BettyButtonVariant.OUTLINE,
                        enabled = safeIndex < gifResults.size - 1,
                    )
                    Spacer(Modifier.weight(1f))
                    BettyButton(
                        text = "Submit",
                        onClick = onClick@{
                            if (isPosting) return@onClick
                            val url = gifResults[safeIndex].originalUrl
                            isPosting = true
                            scope.launch {
                                val ok = onSendGif(url)
                                isPosting = false
                                if (ok) resetGif()
                            }
                        },
                        loading = isPosting,
                    )
                    BettyButton(
                        text = "Cancel",
                        onClick = { resetGif() },
                        variant = BettyButtonVariant.GHOST,
                    )
                }
            }
        }

        // Empty state.
        if (isLoaded && messages.isEmpty()) {
            Text(
                text = "No messages yet. Say something!",
                style = type.bodyRegular,
                color = colors.textMuted,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = Space.xl),
            )
        }

        // Messages (server is newest-first; reverse so newest sits at the bottom).
        messages.asReversed().forEach { message ->
            ChatMessageRow(
                message = message,
                member = membersById[message.userId],
                currentUserId = currentUserId,
                isDeleting = deletingId == message.id,
                isPickerOpen = pickerOpenFor == message.id,
                confirmingDelete = confirmDeleteFor == message.id,
                onTogglePicker = {
                    pickerOpenFor = if (pickerOpenFor == message.id) null else message.id
                },
                onToggleReaction = { emoji ->
                    pickerOpenFor = null
                    scope.launch { onToggleReaction(message, emoji) }
                },
                onRequestDelete = { confirmDeleteFor = message.id },
                onCancelDelete = { confirmDeleteFor = null },
                onConfirmDelete = onConfirmDelete@{
                    confirmDeleteFor = null
                    if (deletingId == message.id) return@onConfirmDelete
                    deletingId = message.id
                    scope.launch {
                        onDeleteMessage(message.id)
                        deletingId = null
                    }
                },
            )
        }

        // Composer.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(Radius.sharp)
                .background(colors.surfaceDeep)
                .padding(Space.s),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.xs),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(Radius.sharp)
                    .background(colors.overlay06)
                    .padding(horizontal = Space.s, vertical = Space.s),
            ) {
                if (draft.isEmpty()) {
                    Text(
                        text = if (giphyMode) "Search Giphy…" else "Send message to group",
                        style = type.bodyRegular,
                        color = colors.textMuted,
                    )
                }
                BasicTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    singleLine = true,
                    textStyle = type.bodyRegular.copy(color = colors.textPrimary),
                    cursorBrush = SolidColor(Palette.orange),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("chat-composer"),
                )
            }
            // GIF toggle.
            Text(
                text = "GIF",
                style = type.micro,
                color = if (giphyMode) Palette.orange else colors.textMuted,
                modifier = Modifier
                    .clip(Radius.sharp)
                    .border(1.dp, if (giphyMode) Palette.orange else colors.overlay10, Radius.sharp)
                    .clickable { giphyMode = !giphyMode }
                    .padding(horizontal = Space.xs, vertical = 8.dp)
                    .testTag("chat-gif-toggle"),
            )
            if (isPosting || isSearching) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Palette.orange, strokeWidth = 2.dp)
            } else {
                BettyButton(
                    text = if (giphyMode) "Search" else "Send",
                    onClick = onClick@{
                        val text = draft.trim()
                        if (text.isEmpty()) return@onClick
                        if (giphyMode) {
                            isSearching = true
                            scope.launch {
                                val results = onSearchGifs(text)
                                if (results.isNotEmpty()) {
                                    gifResults = results
                                    gifIndex = 0
                                }
                                draft = ""
                                isSearching = false
                            }
                        } else {
                            isPosting = true
                            scope.launch {
                                val ok = onSendText(text)
                                isPosting = false
                                if (ok) {
                                    draft = ""
                                    resetGif()
                                }
                            }
                        }
                    },
                    enabled = draft.isNotBlank(),
                    modifier = Modifier.testTag("chat-send"),
                )
            }
        }
    }
}

@Composable
private fun ChatMessageRow(
    message: GroupMessage,
    member: GroupMember?,
    currentUserId: String?,
    isDeleting: Boolean,
    isPickerOpen: Boolean,
    confirmingDelete: Boolean,
    onTogglePicker: () -> Unit,
    onToggleReaction: (String) -> Unit,
    onRequestDelete: () -> Unit,
    onCancelDelete: () -> Unit,
    onConfirmDelete: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    val isMine = currentUserId != null && message.userId == currentUserId
    val groups = ReactionLogic.grouped(message.reactions, currentUserId)

    // Inset panel (orange accent bar).
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(Radius.sharp)
            .background(colors.surfaceDeep)
            .testTag("chat-message"),
    ) {
        Box(
            modifier = Modifier
                .width(3.dp)
                .fillMaxHeight()
                .background(Palette.orange),
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Space.m),
            horizontalArrangement = Arrangement.spacedBy(Space.s),
        ) {
            Avatar(url = member?.imageUrl, name = chatAuthorName(member), size = AvatarSize.small)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Space.xxs),
            ) {
                // Header: author + relative time + delete.
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(text = chatAuthorName(member), style = type.subhead, color = colors.textPrimary)
                    Spacer(Modifier.width(Space.xs))
                    Text(text = relativeTime(message.createdAt), style = type.bodyRegular.copy(fontSize = type.caption.fontSize), color = colors.textMuted)
                    Spacer(Modifier.weight(1f))
                    if (isMine) {
                        Text(
                            text = "🗑",
                            style = type.subhead,
                            color = colors.textMuted,
                            modifier = Modifier
                                .alpha(if (isDeleting) 0.45f else 1f)
                                .clickable(enabled = !isDeleting) { onRequestDelete() }
                                .padding(start = Space.xs)
                                .testTag("chat-message-delete"),
                        )
                    }
                }

                // Content: image-only OR body text.
                val imageUrl = message.imageUrl
                if (!imageUrl.isNullOrEmpty()) {
                    AsyncImage(
                        model = imageUrl,
                        contentDescription = null,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(Radius.sharp)
                            .background(colors.overlay06),
                    )
                } else if (message.body != null) {
                    Text(text = message.body!!, style = type.body, color = colors.textPrimary)
                }

                // Reactions row + add button.
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(top = Space.xxs),
                    horizontalArrangement = Arrangement.spacedBy(Space.xxs),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    groups.forEach { group ->
                        Row(
                            modifier = Modifier
                                .clip(Radius.legacy)
                                .background(if (group.reactedByMe) Palette.orangeTint15 else colors.overlay06)
                                .border(1.dp, if (group.reactedByMe) Palette.orange.copy(alpha = 0.5f) else colors.overlay08, Radius.legacy)
                                .clickable { onToggleReaction(group.emojiId) }
                                .padding(horizontal = Space.xs, vertical = 3.dp)
                                .testTag("chat-reaction"),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Text(text = group.emojiId, style = type.bodyRegular)
                            Text(
                                text = group.count.toString(),
                                style = type.caption,
                                color = if (group.reactedByMe) Palette.orange else colors.textPrimary,
                            )
                        }
                    }
                    Text(
                        text = "☺",
                        style = type.subhead,
                        color = colors.textMuted,
                        modifier = Modifier
                            .clip(Radius.legacy)
                            .border(1.dp, colors.overlay10, Radius.legacy)
                            .clickable { onTogglePicker() }
                            .padding(horizontal = Space.xs, vertical = 2.dp)
                            .testTag("chat-add-reaction"),
                    )
                }

                // Emoji picker.
                if (isPickerOpen) {
                    Row(
                        modifier = Modifier
                            .clip(Radius.legacy)
                            .background(colors.surface)
                            .border(1.dp, colors.overlay10, Radius.legacy)
                            .horizontalScroll(rememberScrollState())
                            .padding(Space.xxs),
                        horizontalArrangement = Arrangement.spacedBy(Space.xxs),
                    ) {
                        Reactions.palette.forEach { emoji ->
                            Text(
                                text = emoji,
                                style = type.title3,
                                modifier = Modifier
                                    .clickable { onToggleReaction(emoji) }
                                    .padding(Space.xs),
                            )
                        }
                    }
                }

                // Delete confirmation dialog.
                if (confirmingDelete) {
                    AlertDialog(
                        onDismissRequest = onCancelDelete,
                        containerColor = colors.surface,
                        titleContentColor = colors.textPrimary,
                        textContentColor = colors.textSecondary,
                        title = { Text("Delete message?", style = type.title3) },
                        text = { Text("This message will be permanently removed.", style = type.bodyRegular) },
                        confirmButton = {
                            TextButton(onClick = onConfirmDelete) {
                                Text("DELETE", style = type.kicker, color = Palette.alertRed)
                            }
                        },
                        dismissButton = {
                            TextButton(onClick = onCancelDelete) {
                                Text("CANCEL", style = type.kicker, color = colors.textSecondary)
                            }
                        },
                    )
                }
            }
        }
    }
}
