// Surface: chat.reactions — design/surfaces/chat.reactions.md
// References: references/auto/whatsapp/store/whatsapp-store-04.png (summary under a message, count dropped),
// references/auto/imessage/apple-support/messages-tapbacks-ios27.png (reaction row on long press),
// references/auto/locket/frames/locket-tt-7460656081153445163-15.000s-emoji-picker-sheet-search-popular.jpg (picker),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt ("Reactions" sheet).
@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.feature.social.reactions

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.produceState
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import app.data.repo.ReactionEntry
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.EmojiNames
import app.feature.social.common.PersonAvatar
import app.feature.social.common.SystemAppearance
import app.feature.social.common.stringRes
import app.ui.components.EmptyState
import app.ui.components.SearchField
import app.ui.components.LoadingState
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.system.DsBottomSheet
import app.ui.system.DsMenuItem
import app.ui.system.SheetHeader
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import java.time.Instant

/**
 * The distinct emoji of a photo's reactions for the chip (`chat.reactions.layout.clusterOrder`): newest first —
 * an emoji used again moves to the front. Rows arrive oldest first.
 */
fun clusterEmoji(entries: List<ReactionEntry>): List<String> = entries.asReversed().map { it.emoji }.distinct()

/** The chip's TalkBack label: the emoji's system names, never a count (`chat.reactions.a11y.cluster`). */
@Composable
fun clusterLabel(entries: List<ReactionEntry>): String =
    stringRes(R.string.chat_reactions_a11y_cluster, clusterEmoji(entries).joinToString(", ") { EmojiNames.name(it) })

/** Padding of Retro's small pills, as `chat.reactions.layout.chip` gives it ("12 horizontal / 8 vertical"). */
internal object ChipPadding {
    private val numbers = Regex("([0-9.]+) horizontal / ([0-9.]+) vertical").find(Tokens.Layouts.ChatReactionsLayoutChip.padding)
    val horizontal: Dp = numbers?.groupValues?.get(1)?.toFloatOrNull()?.dp ?: Dp.Hairline
    val vertical: Dp = numbers?.groupValues?.get(2)?.toFloatOrNull()?.dp ?: Dp.Hairline
}

/**
 * C-06 fill capsule summarising the reactions (`chat.reactions.layout.chip`): up to
 * `chat.reactions.count.clusterMaxVisible` distinct emoji, newest first, at `fontSize.global.pill`, padding
 * [ChipPadding], `radius.global.capsule`; fill `color.global.surfaceSecondary.android` on a page,
 * `color.global.controlOnDeep` on media ([onMedia]). No number, no avatars; hidden when nobody reacted.
 * Changes cross-fade (`duration.global.crossfade`). One button: opens the Reactions sheet.
 */
@Composable
fun ReactionChip(entries: List<ReactionEntry>, onClick: () -> Unit, modifier: Modifier = Modifier, onMedia: Boolean = false, whoReacted: String? = null) {
    val emoji = clusterEmoji(entries).take(Tokens.Counts.chatReactionsCountClusterMaxVisible)
    if (emoji.isEmpty()) return
    val fill = if (onMedia) Tokens.Colors.globalControlOnDeep else PageRoles.secondarySurface
    val label = clusterLabel(entries)
    Box(
        modifier
            .background(fill, CircleShape)
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                // A message's chip (`chat.reactions.layout.messageReactions`): who reacted with what, rows only.
                if (whoReacted != null) stateDescription = whoReacted
            }
            .padding(horizontal = ChipPadding.horizontal, vertical = ChipPadding.vertical),
    ) {
        AnimatedContent(emoji, transitionSpec = { fadeIn(DsMotion.crossfade()) togetherWith fadeOut(DsMotion.crossfade()) }, label = "chip") { shown ->
            Text(shown.joinToString(""), style = emojiStyle(Tokens.FontSizes.globalPill), maxLines = 1)
        }
    }
}

/** Emoji drawn at a font size token (colour glyphs: no colour role applies). */
@Composable
internal fun emojiStyle(size: androidx.compose.ui.unit.TextUnit): TextStyle = TextRoles.pill.copy(fontSize = size)

/** The quick reactions of `chat.reactions.layout.quickReactions` ("🔥 then 💖, then the add-reaction glyph"). */
object QuickReactions {
    val emoji: List<String> by lazy { EmojiNames.inText(Tokens.Layouts.ChatReactionsLayoutQuickReactions.emoji) }
}

/**
 * The photo's native context menu (C-29 `DropdownMenu`) with the quick-reaction palette as its first row
 * (`chat.reactions.layout.quickReactions`): 🔥 💖 and `chat.reactions.icon.add`; an emoji you already used shows
 * selected (on a `color.global.control` circle) and unreacts. Then the surface's own [items] (destructive in
 * `color.global.system.error`). core:ui `DsDropdownMenu` has no header row, so the items are drawn here with
 * the same M3 item and colours (component gap, reported).
 */
@Composable
fun PhotoContextMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    mine: Set<String>,
    onReact: (String) -> Unit,
    onUnreact: (String) -> Unit,
    onAddReaction: () -> Unit,
    items: List<DsMenuItem>,
) {
    val haptics = rememberHaptics()
    SystemAppearance {
        DropdownMenu(expanded = expanded, onDismissRequest = onDismiss) {
            Row(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalAlignment = Alignment.CenterVertically) {
                QuickReactions.emoji.forEach { e ->
                    val used = e in mine
                    val name = EmojiNames.name(e)
                    val label = stringRes(R.string.chat_reactions_a11y_quick, name)
                    Box(
                        Modifier
                            .size(Tokens.Sizes.globalHeaderButton)
                            .tapClickable {
                                onDismiss()
                                if (used) onUnreact(e) else onReact(e)
                            }
                            .semantics(mergeDescendants = true) {
                                contentDescription = label
                                selected = used
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (used) Box(Modifier.size(Tokens.Sizes.globalCircleButton).background(Tokens.Colors.globalControl, CircleShape))
                        Text(e, style = emojiStyle(Tokens.FontSizes.globalSheetTitle))
                    }
                }
                val add = stringRes(R.string.chat_reactions_a11y_add)
                Box(
                    Modifier.size(Tokens.Sizes.globalHeaderButton).tapClickable {
                        onDismiss()
                        onAddReaction()
                    }.semantics { contentDescription = add },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Tokens.Icons.chatReactionsIconAdd, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface, modifier = Modifier.size(Tokens.Sizes.globalIcon))
                }
            }
            items.forEach { item ->
                val color = if (item.destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
                DropdownMenuItem(
                    text = { Text(item.text) },
                    onClick = {
                        haptics.tap()
                        onDismiss()
                        item.onClick()
                    },
                    enabled = item.enabled,
                    trailingIcon = item.icon?.let { { Icon(it, contentDescription = null) } },
                    colors = MenuDefaults.itemColors(textColor = color, trailingIconColor = color),
                )
            }
        }
    }
}

/** One picker item: a section label or an emoji cell ([entry]: its catalog entry with the skin tones, when known). */
private sealed interface PickerItem {
    data class Section(val label: String) : PickerItem
    data class Cell(val emoji: String, val section: Int, val entry: CatalogEntry?) : PickerItem
}

/**
 * The emoji picker (`chat.reactions.layout.picker`): native sheet (C-29) on the page colour; C-12 search field
 * (`chat.reactions.picker.search`, Unicode names) inside `size.global.screenMargin`; "Frequently Used" (this device),
 * then every emoji of Unicode's RGI set in its standard groups (`chat.reactions.picker.group.*`, "Smileys & Emotion" …
 * "Flags") as C-20 labels (`sectionLabel`; `size.global.sectionGap` above, `size.global.sectionHeaderToContent` below
 * the baseline); `chat.reactions.count.pickerColumns` equal columns, emoji at `fontSize.global.headerTitle`. An emoji
 * with skin tones offers them on touch and hold (the platform menu, as the system emoji picker's variant popup); TalkBack
 * lists them as custom actions. Emoji you already used ([mine]) sit on a `size.global.circleButton` circle in
 * `color.global.control` (selected trait) and unreact. Tap → react and close. Only emoji the system font draws show.
 */
@Composable
fun ReactionPickerSheet(mine: Set<String>, onPick: (String) -> Unit, onUnreact: (String) -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    var query by remember { mutableStateOf(TextFieldValue()) }
    val frequent = remember { EmojiCatalog.recent(context) }
    val catalog by produceState(EmojiCatalog.shownIfReady) {
        if (value == null) value = withContext(Dispatchers.Default) { EmojiCatalog.shown(context) }
    }
    val frequentLabel = stringRes(R.string.chat_reactions_picker_frequent)
    // Unicode's standard groups, in the catalog's order (tools/emoji-catalog.mjs).
    val groupLabels = listOf(
        stringRes(R.string.chat_reactions_picker_group_smileysemotion), stringRes(R.string.chat_reactions_picker_group_peoplebody),
        stringRes(R.string.chat_reactions_picker_group_animalsnature), stringRes(R.string.chat_reactions_picker_group_fooddrink),
        stringRes(R.string.chat_reactions_picker_group_travelplaces), stringRes(R.string.chat_reactions_picker_group_activities),
        stringRes(R.string.chat_reactions_picker_group_objects), stringRes(R.string.chat_reactions_picker_group_symbols),
        stringRes(R.string.chat_reactions_picker_group_flags),
    )
    val items: List<PickerItem> = remember(query.text, frequent, catalog, groupLabels) {
        val data = catalog ?: EmojiCatalogData(emptyList())
        val q = query.text.trim()
        if (q.isNotEmpty()) {
            data.search(q).map { PickerItem.Cell(it.base.emoji, 0, it) }
        } else buildList {
            if (frequent.isNotEmpty()) {
                add(PickerItem.Section(frequentLabel))
                frequent.forEach { add(PickerItem.Cell(it, 1, data.entryContaining(it))) }
            }
            data.groups.zip(groupLabels).forEachIndexed { index, (group, label) ->
                if (group.entries.isNotEmpty()) {
                    add(PickerItem.Section(label))
                    group.entries.forEach { add(PickerItem.Cell(it.base.emoji, index + 2, it)) }
                }
            }
        }
    }
    SystemAppearance {
        DsBottomSheet(onDismissRequest = onDismiss) {
            SearchField(
                value = query,
                onValueChange = { query = it },
                placeholder = stringRes(R.string.chat_reactions_picker_search),
                accessibilityLabel = stringRes(R.string.chat_reactions_picker_search),
                modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin),
            )
            LazyVerticalGrid(
                columns = GridCells.Fixed(Tokens.Counts.chatReactionsCountPickerColumns),
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = Tokens.Sizes.globalScreenMargin),
            ) {
                items(items, span = { if (it is PickerItem.Section) GridItemSpan(maxLineSpan) else GridItemSpan(1) }, key = { item ->
                    when (item) {
                        is PickerItem.Section -> "s:" + item.label
                        is PickerItem.Cell -> "c:${item.section}:${item.emoji}"
                    }
                }) { item ->
                    when (item) {
                        is PickerItem.Section -> SectionLabel(item.label)
                        is PickerItem.Cell -> {
                            val choose: (String) -> Unit = { emoji ->
                                if (emoji in mine) onUnreact(emoji)
                                else {
                                    EmojiCatalog.remember(context, emoji)
                                    onPick(emoji)
                                }
                            }
                            PickerCell(item.emoji, mine, item.entry?.takeIf { it.variants.isNotEmpty() }?.choices.orEmpty(), choose)
                        }
                    }
                }
            }
        }
    }
}

/** A C-20 label without "•••": cap top `size.global.sectionGap` below the content above, content `sectionHeaderToContent` below its baseline. */
@Composable
private fun SectionLabel(text: String) {
    val style = TextRoles.sectionLabel
    Text(
        text,
        style = style,
        color = Tokens.Colors.globalTextPrimary,
        modifier = Modifier
            .fillMaxWidth()
            .capTopAt(Tokens.Sizes.globalSectionGap, CapTop.height(style))
            .paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent)
            .semantics { heading() },
    )
}

/**
 * One picker cell; a reaction of yours sits on the `color.global.control` circle with the selected trait. With skin tones
 * ([choices]: the base and its variants), touch and hold opens them in the platform menu (`chat.reactions.count.pickerColumns`
 * to a row), and TalkBack offers each as a custom action.
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
private fun PickerCell(emoji: String, mine: Set<String>, choices: List<CatalogEmoji>, onChoose: (String) -> Unit) {
    val name = EmojiNames.name(emoji)
    val haptics = rememberHaptics()
    var tones by remember { mutableStateOf(false) }
    Box(
        Modifier
            .aspectRatio(1f)
            .combinedClickable(
                onClick = { haptics.tap(); onChoose(emoji) },
                onLongClick = if (choices.isEmpty()) null else ({ haptics.longPress(); tones = true }),
            )
            .semantics(mergeDescendants = true) {
                contentDescription = name
                selected = emoji in mine
                if (choices.isNotEmpty()) {
                    customActions = choices.filter { it.emoji != emoji }.map { c -> CustomAccessibilityAction(c.name) { onChoose(c.emoji); true } }
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        EmojiFace(emoji, emoji in mine)
        if (choices.isNotEmpty()) {
            DropdownMenu(expanded = tones, onDismissRequest = { tones = false }) {
                FlowRow(maxItemsInEachRow = Tokens.Counts.chatReactionsCountPickerColumns) {
                    choices.forEach { c ->
                        Box(
                            Modifier
                                .size(Tokens.Sizes.globalMinTouchTargetAndroid)
                                .tapClickable { tones = false; onChoose(c.emoji) }
                                .semantics(mergeDescendants = true) {
                                    contentDescription = c.name
                                    selected = c.emoji in mine
                                },
                            contentAlignment = Alignment.Center,
                        ) { EmojiFace(c.emoji, c.emoji in mine) }
                    }
                }
            }
        }
    }
}

/** The emoji at `fontSize.global.headerTitle`; yours on the `size.global.circleButton` circle in `color.global.control`. */
@Composable
private fun EmojiFace(emoji: String, mine: Boolean) {
    Box(contentAlignment = Alignment.Center) {
        if (mine) Box(Modifier.size(Tokens.Sizes.globalCircleButton).background(Tokens.Colors.globalControl, CircleShape))
        Text(emoji, style = emojiStyle(Tokens.FontSizes.globalHeaderTitle), maxLines = 1)
    }
}

/** A person of the Reactions sheet. */
data class Reactor(val userId: String, val name: String, val avatarPath: String?)

/**
 * A row of another reaction kind placed among the emoji rows by time (the selfie rows of `viewer.selfiereaction` §4);
 * [at] null = being sent (the newest).
 */
@Immutable
class ReactionsSheetRow(val key: String, val at: Instant?, val content: @Composable () -> Unit)

/** One line of the sheet: an emoji reaction or a [ReactionsSheetRow]. */
private sealed interface SheetLine {
    val key: String
    val at: Instant?

    data class Emoji(val entry: ReactionEntry) : SheetLine {
        override val key get() = entry.userId + ":" + entry.emoji
        override val at get() = entry.createdAt
    }

    class Other(val row: ReactionsSheetRow) : SheetLine {
        override val key get() = row.key
        override val at get() = row.at
    }
}

/**
 * The Reactions sheet (`chat.reactions.layout.list`): native sheet titled `chat.reactions.activity.title`, a plain
 * list on the page colour, one C-16 row per person and emoji — avatar `size.global.avatarPicker` at the margin,
 * name (`listTitle`) `chat.thread.dimension.rowAvatarToText` after it, the emoji at the trailing margin in the
 * `size.global.icon` box; your rows add `chat.reactions.list.removeHint` and unreact on tap. Rows
 * `size.global.listGap` apart, newest first (`chat.reactions.layout.listOrder`: [entries] arrive oldest first by
 * `reactions.created_at`, optimistic ones appended — the list reverses them). [others] (selfie reactions) sit among them by
 * time. Empty: `chat.reactions.empty` (C-27 title only).
 */
@Composable
fun ReactionsSheet(
    entries: List<ReactionEntry>,
    me: String?,
    person: (String) -> Reactor,
    onUnreact: (String) -> Unit,
    onDismiss: () -> Unit,
    loading: Boolean = false,
    others: List<ReactionsSheetRow> = emptyList(),
) {
    val emoji: List<SheetLine> = entries.asReversed().map { SheetLine.Emoji(it) }
    val rows = if (others.isEmpty()) emoji else (emoji + others.asReversed().map { SheetLine.Other(it) }).sortedWith(
        // Newest first; a row still being sent (no time yet) is the newest.
        Comparator { a, b ->
            val x = a.at
            val y = b.at
            when {
                x == null && y == null -> 0
                x == null -> -1
                y == null -> 1
                else -> y.compareTo(x)
            }
        },
    )
    SystemAppearance {
        DsBottomSheet(onDismissRequest = onDismiss) {
            SheetHeader(stringRes(R.string.chat_reactions_activity_title))
            Spacer(Modifier.height(Tokens.Sizes.globalSectionHeaderToContent))
            when {
                loading -> LoadingState(stringRes(R.string.week_history_a11y_loading), Modifier.height(Tokens.Sizes.globalFriendCardHeight))
                rows.isEmpty() -> Box(Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardHeight), contentAlignment = Alignment.Center) {
                    EmptyState(stringRes(R.string.chat_reactions_empty), null)
                }
                else -> LazyColumn(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap), contentPadding = PaddingValues(bottom = Tokens.Sizes.globalSectionGap)) {
                    itemsIndexed(rows, key = { _, line -> line.key }) { _, line ->
                        if (line is SheetLine.Other) {
                            line.row.content()
                            return@itemsIndexed
                        }
                        val entry = (line as SheetLine.Emoji).entry
                        val p = person(entry.userId)
                        val mine = entry.userId == me
                        val label = if (mine) stringRes(R.string.chat_reactions_activity_rowmine, entry.emoji)
                        else stringRes(R.string.chat_reactions_activity_row, p.name, entry.emoji)
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .then(if (mine) Modifier.tapClickable { onUnreact(entry.emoji) } else Modifier)
                                .clearAndSetSemantics {
                                    contentDescription = label
                                    if (mine) role = Role.Button
                                }
                                .padding(horizontal = Tokens.Sizes.globalScreenMargin),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            PersonAvatar(p.avatarPath, Tokens.Sizes.globalAvatarPicker)
                            Spacer(Modifier.width(Tokens.Sizes.chatThreadDimensionRowAvatarToText))
                            Column(Modifier.weight(1f)) {
                                Text(p.name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1)
                                if (mine) Text(stringRes(R.string.chat_reactions_list_removehint), style = TextRoles.listSubtitle, color = PageRoles.secondaryText())
                            }
                            Box(Modifier.size(Tokens.Sizes.globalIcon), contentAlignment = Alignment.Center) {
                                Text(entry.emoji, style = emojiStyle(Tokens.FontSizes.globalListTitle), maxLines = 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Optimistic reaction rows: [entries] plus `(me, emoji)` (the newest) unless already there. */
fun withReaction(entries: List<ReactionEntry>, me: String, emoji: String): List<ReactionEntry> =
    if (entries.any { it.userId == me && it.emoji == emoji }) entries else entries + ReactionEntry(me, emoji)

/** Removes `(me, emoji)` (the optimistic row after a failed `react`, or `unreact`). */
fun withoutReaction(entries: List<ReactionEntry>, me: String, emoji: String): List<ReactionEntry> =
    entries.filterNot { it.userId == me && it.emoji == emoji }
